#!/bin/sh
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTXWIN=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
AGENT_NAME=$(echo "$input" | jq -r '.agent.name // ""')
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'; MAGENTA='\033[35m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

# --- ClaudeUsageBar tracking ---
# Stores one file per session per day: ~/.claude/usage/YYYY-MM-DD/{pid}.dat
USAGE_DIR="$HOME/.claude/usage"
TODAY=$(date +%Y-%m-%d)
mkdir -p "$USAGE_DIR/$TODAY"
echo "$COST $LINES_ADDED $LINES_REMOVED $MODEL" > "$USAGE_DIR/$TODAY/$PPID.dat"

# Track model transitions for per-model cost breakdown
MF="$USAGE_DIR/$TODAY/$PPID.models"
PREV_MODEL=""; [ -f "$MF" ] && PREV_MODEL=$(tail -1 "$MF" | cut -f4-)
[ "$PREV_MODEL" != "$MODEL" ] && printf '%s\t%s\t%s\t%s\n' "$COST" "$LINES_ADDED" "$LINES_REMOVED" "$MODEL" >> "$MF"

# Write live agent metadata for menu bar app
cat > "$USAGE_DIR/$TODAY/$PPID.agent.json.tmp" <<AGENTEOF
{"pid":$PPID,"model":"$MODEL","agent_name":"$AGENT_NAME","context_pct":$PCT,"context_window":$CTXWIN,"cost":$COST,"lines_added":$LINES_ADDED,"lines_removed":$LINES_REMOVED,"working_dir":"$DIR","session_id":"$SESSION_ID","duration_ms":$DURATION_MS,"api_duration_ms":$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0'),"updated_at":$(date +%s)}
AGENTEOF
mv "$USAGE_DIR/$TODAY/$PPID.agent.json.tmp" "$USAGE_DIR/$TODAY/$PPID.agent.json"

# Cleanup data older than 3 months (runs once per day via marker file)
CLEANUP_MARKER="$USAGE_DIR/.last_cleanup"
if [ ! -f "$CLEANUP_MARKER" ] || [ "$(cat "$CLEANUP_MARKER")" != "$TODAY" ]; then
  echo "$TODAY" > "$CLEANUP_MARKER"
  CUTOFF=$(date -v-3m +%Y-%m-%d)
  for dir in "$USAGE_DIR"/????-??-??; do
    [ -d "$dir" ] || continue
    [ "$(basename "$dir")" \< "$CUTOFF" ] && rm -rf "$dir"
  done
fi

# Compute period boundaries
DOW=$(date +%u)
WEEK_START=$(date -v-$(( DOW - 1 ))d +%Y-%m-%d)
MONTH_START=$(date +%Y-%m-01)

# Build PID → session_id map from .agent.json files for session-aware deduplication.
# Claude Code may restart (new PID) while keeping the same session, creating duplicate
# .dat files that inflate totals. We pass this map to awk for merging.
_CUB_SIDMAP=$(for _agf in "$USAGE_DIR"/????-??-??/*.agent.json; do
  [ -f "$_agf" ] || continue
  _p="${_agf##*/}"; _p="${_p%.agent.json}"
  _s=$(sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p' "$_agf" 2>/dev/null)
  [ -n "$_s" ] && printf '%s %s|' "$_p" "$_s"
done)

# Sum all tracked sessions with deduplication (same logic as the menu bar app):
# A session spanning multiple days has .dat files in each day's folder with cumulative costs.
# Keep only the latest day per PID and subtract the previous day's value for today's increment.
# Session-aware dedup merges PIDs sharing a session_id; exact-content dedup catches orphans.
TOTALS=$(find "$USAGE_DIR" -name "*.dat" -type f 2>/dev/null | sort | \
  awk -v today="$TODAY" -v week="$WEEK_START" -v month="$MONTH_START" -v sidmap="$_CUB_SIDMAP" '
  BEGIN {
    n = split(sidmap, slines, "|")
    for (i = 1; i <= n; i++) {
      if (split(slines[i], sp, " ") >= 2) pid2sid[sp[1]] = sp[2]
    }
  }
  {
    n = split($0, p, "/"); date = p[n-1]; pid = p[n]
    sub(/\.dat$/, "", pid)
    key = pid
    if ((getline line < $0) > 0) {
      close($0)
      split(line, vals, " ")
      cost = vals[1] + 0; la = vals[2] + 0; lr = vals[3] + 0
      # Track latest and previous entry per PID (sorted by date, so later overwrites earlier)
      if (key in latest_cost) {
        prev_cost[key]  = latest_cost[key]
        prev_la[key]    = latest_la[key]
        prev_lr[key]    = latest_lr[key]
        prev_date[key]  = latest_date[key]
      }
      latest_cost[key] = cost
      latest_la[key]   = la
      latest_lr[key]   = lr
      latest_date[key] = date
    }
  } END {
    # Exact-content dedup: remove PIDs with identical values on the same day.
    # Prefer keeping the one with a prior-day entry or known session_id.
    for (k in latest_cost) {
      if (k in skip) continue
      for (o in latest_cost) {
        if (o <= k || o in skip) continue
        if (latest_date[k] == latest_date[o] && latest_cost[k] == latest_cost[o] && \
            latest_la[k] == latest_la[o] && latest_lr[k] == latest_lr[o]) {
          kp = (k in prev_cost) + (k in pid2sid)
          op = (o in prev_cost) + (o in pid2sid)
          if (op > kp) skip[k] = 1; else skip[o] = 1
        }
      }
    }

    # Session-aware merge: group PIDs by session_id, keep highest-cost as latest,
    # carry earliest previous entry across all PIDs in the session.
    for (k in latest_cost) {
      if (k in skip || !(k in pid2sid)) continue
      sid = pid2sid[k]
      if (sid in ses_best) {
        b = ses_best[sid]
        if (latest_cost[k] >= latest_cost[b]) { w = k; lo = b }
        else { w = b; lo = k }
        # Carry earliest previous to winner from loser
        if (lo in prev_date && (!(w in prev_date) || prev_date[lo] < prev_date[w])) {
          prev_cost[w] = prev_cost[lo]; prev_la[w] = prev_la[lo]
          prev_lr[w] = prev_lr[lo]; prev_date[w] = prev_date[lo]
        }
        # Loser latest may be an even earlier previous
        if (latest_date[lo] < latest_date[w] && \
            (!(w in prev_date) || latest_date[lo] < prev_date[w])) {
          prev_cost[w] = latest_cost[lo]; prev_la[w] = latest_la[lo]
          prev_lr[w] = latest_lr[lo]; prev_date[w] = latest_date[lo]
        }
        skip[lo] = 1
        ses_best[sid] = w
      } else {
        ses_best[sid] = k
      }
    }

    # Compute period totals (skipping merged duplicates)
    for (key in latest_cost) {
      if (key in skip) continue
      date = latest_date[key]
      cost = latest_cost[key]; la = latest_la[key]; lr = latest_lr[key]
      # Month: latest cumulative value
      if (date >= month) { m += cost; m_la += la; m_lr += lr }
      # Week: latest if in week, else skip
      if (date >= week) {
        if (key in prev_cost && prev_date[key] >= week) {
          w += cost - prev_cost[key]; w_la += la - prev_la[key]; w_lr += lr - prev_lr[key]
        } else {
          w += cost; w_la += la; w_lr += lr
        }
      }
      # Today: incremental (subtract previous day if session spans midnight)
      if (date == today) {
        if (key in prev_cost && prev_date[key] < today) {
          d += cost - prev_cost[key]; d_la += la - prev_la[key]; d_lr += lr - prev_lr[key]
        } else {
          d += cost; d_la += la; d_lr += lr
        }
      }
    }
    printf "%.2f %.2f %.2f %d %d %d %d %d %d", d+0, w+0, m+0, d_la+0, d_lr+0, w_la+0, w_lr+0, m_la+0, m_lr+0
  }')

DAY_TOTAL=$(echo "$TOTALS" | awk '{print $1}')
WEEK_TOTAL=$(echo "$TOTALS" | awk '{print $2}')
MONTH_TOTAL=$(echo "$TOTALS" | awk '{print $3}')
DAY_LA=$(echo "$TOTALS" | awk '{print $4}')
DAY_LR=$(echo "$TOTALS" | awk '{print $5}')
WEEK_LA=$(echo "$TOTALS" | awk '{print $6}')
WEEK_LR=$(echo "$TOTALS" | awk '{print $7}')
MONTH_LA=$(echo "$TOTALS" | awk '{print $8}')
MONTH_LR=$(echo "$TOTALS" | awk '{print $9}')

# Output
COST_FMT=$(printf '$%.2f' "$COST")
echo "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"
echo "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"
echo "${MAGENTA}📊 ${RESET} Day: ${YELLOW}\$${DAY_TOTAL}${RESET} | Wk: ${YELLOW}\$${WEEK_TOTAL}${RESET} | Mo: ${YELLOW}\$${MONTH_TOTAL}${RESET}"
echo "✏️  Day: ${GREEN}+${DAY_LA}${RESET}/${RED}-${DAY_LR}${RESET} | Wk: ${GREEN}+${WEEK_LA}${RESET}/${RED}-${WEEK_LR}${RESET} | Mo: ${GREEN}+${MONTH_LA}${RESET}/${RED}-${MONTH_LR}${RESET}"
