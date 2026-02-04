import SwiftUI

enum ToastStyle {
    case info
    case warning
    case error
    
    var color: Color {
        switch self {
        case .info:
            return ClayTheme.accent
        case .warning:
            return ClayTheme.accentWarm
        case .error:
            return ClayTheme.bad
        }
    }
}

struct ToastPayload {
    let message: String
    let style: ToastStyle
}

struct ToastItem: Identifiable, Equatable {
    let id: UUID
    let message: String
    let style: ToastStyle
}

@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var toasts: [ToastItem] = []
    
    func push(message: String, style: ToastStyle = .warning, duration: TimeInterval = 2.6) {
        let item = ToastItem(id: UUID(), message: message, style: style)
        toasts.append(item)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            dismiss(item)
        }
    }
    
    func dismiss(_ item: ToastItem) {
        toasts.removeAll { $0.id == item.id }
    }
}
