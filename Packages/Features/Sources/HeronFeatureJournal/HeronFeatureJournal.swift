import SwiftUI
import HeronDataStore
import HeronDesignSystem
import HeronModels
import HeronSwiftUIComponents

public struct JournalView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: CGFloat(HeronDesignTokens.spacingSmall)) {
            Text("Journal")
                .font(.largeTitle)
            HeronPlaceholderCard()
        }
        .padding(CGFloat(HeronDesignTokens.spacingLarge))
    }
}
