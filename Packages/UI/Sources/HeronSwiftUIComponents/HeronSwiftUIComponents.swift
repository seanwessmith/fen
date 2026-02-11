import SwiftUI
import HeronDesignSystem

public struct HeronPlaceholderCard: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(HeronDesignTokens.spacingSmall)) {
            Text("Heron")
                .font(.headline)
            Text("Field journal placeholder.")
                .font(.subheadline)
        }
        .padding(CGFloat(HeronDesignTokens.spacingLarge))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(HeronDesignTokens.cornerRadius)))
    }
}
