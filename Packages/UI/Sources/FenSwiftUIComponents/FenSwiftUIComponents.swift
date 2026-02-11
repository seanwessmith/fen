import SwiftUI
import FenDesignSystem

public struct FenPlaceholderCard: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(FenDesignTokens.spacingSmall)) {
            Text("Fen")
                .font(.headline)
            Text("Field journal placeholder.")
                .font(.subheadline)
        }
        .padding(CGFloat(FenDesignTokens.spacingLarge))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(FenDesignTokens.cornerRadius)))
    }
}
