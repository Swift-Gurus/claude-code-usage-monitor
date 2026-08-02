import SwiftUI

/// Segmented Today/Week/Month picker.
struct StatusBarPeriodPicker: View {
    @Binding var period: StatusBarPeriod

    var body: some View {
        Picker("Period", selection: $period) {
            periodOptions
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var periodOptions: some View {
        ForEach(StatusBarPeriod.allCases, id: \.self) { p in
            Text(p.label).tag(p)
        }
    }
}

#Preview {
    StatusBarPeriodPicker(period: .constant(.day))
}
