import SwiftUI
import HeronDesignSystem
import HeronModels
import HeronPermissions
import HeronSwiftUIComponents

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: CGFloat(HeronDesignTokens.spacingSmall)) {
            Text("Settings")
                .font(.largeTitle)
            HeronPlaceholderCard()
        }
        .padding(CGFloat(HeronDesignTokens.spacingLarge))
    }
}
