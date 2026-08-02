import SwiftUI

/// Colors that adapt to dark/light mode for the popover's agent list.
struct PopoverColors {
    let colorScheme: ColorScheme

    var idle: Color { colorScheme == .dark ? Color(white: 0.7) : .gray }
    var idleOpacity: Double { colorScheme == .dark ? 0.85 : 0.6 }
    var added: Color { colorScheme == .dark ? .green : Color(red: 0.1, green: 0.55, blue: 0.1) }
    var removed: Color { colorScheme == .dark ? Color(red: 1.0, green: 0.4, blue: 0.4) : .red }
}
