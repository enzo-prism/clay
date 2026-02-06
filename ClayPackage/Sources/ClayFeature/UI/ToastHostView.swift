import SwiftUI

struct ToastHostView: View {
    @EnvironmentObject private var toastCenter: ToastCenter
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(toastCenter.toasts) { toast in
                ToastView(item: toast)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(16)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.2), value: toastCenter.toasts)
    }
}

struct ToastView: View {
    let item: ToastItem
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.style.color)
                .frame(width: 8, height: 8)
            Text(item.message)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.text)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: ClayTheme.shadow, radius: 8, x: 0, y: 4)
    }
}
