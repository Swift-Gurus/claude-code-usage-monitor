#!/bin/sh
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
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
echo "$COST $LINES_ADDED $LINES_REMOVED" > "$USAGE_DIR/$TODAY/$PPID.dat"

# Write live agent metadata for menu bar app
cat > "$USAGE_DIR/$TODAY/$PPID.agent.json.tmp" <<AGENTEOF
{"pid":$PPID,"model":"$MODEL","agent_name":"$AGENT_NAME","context_pct":$PCT,"cost":$COST,"lines_added":$LINES_ADDED,"lines_removed":$LINES_REMOVED,"working_dir":"$DIR","session_id":"$SESSION_ID","updated_at":$(date +%s)}
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

# Sum all tracked sessions in one pass (find + awk reads each .dat file)
TOTALS=$(find "$USAGE_DIR" -name "*.dat" -type f 2>/dev/null | \
  awk -v today="$TODAY" -v week="$WEEK_START" -v month="$MONTH_START" '{
    n = split($0, p, "/"); date = p[n-1]
    if ((getline line < $0) > 0) {
      close($0)
      split(line, vals, " ")
      cost = vals[1] + 0; la = vals[2] + 0; lr = vals[3] + 0
      if (date >= month) { m += cost; m_la += la; m_lr += lr }
      if (date >= week)  { w += cost; w_la += la; w_lr += lr }
      if (date == today)  { d += cost; d_la += la; d_lr += lr }
    }
  } END { printf "%.2f %.2f %.2f %d %d %d %d %d %d", d+0, w+0, m+0, d_la+0, d_lr+0, w_la+0, w_lr+0, m_la+0, m_lr+0 }')

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
