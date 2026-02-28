import SwiftUI

extension View {
    /// Applies Liquid Glass (iOS 26+) or ultraThinMaterial fallback.
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
}
