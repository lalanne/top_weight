import SwiftUI

extension View {
    /// Applies a frosted glass-style background. Uses ultraThinMaterial for broad compatibility.
    /// On iOS 26+, you could switch to .glassEffect() for Liquid Glass.
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
