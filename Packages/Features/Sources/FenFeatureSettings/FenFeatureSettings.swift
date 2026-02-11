import SwiftUI
import FenDesignSystem
import FenModels
import FenPermissions
import FenSwiftUIComponents

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: CGFloat(FenDesignTokens.spacingSmall)) {
            Text("Settings")
                .font(.largeTitle)
            FenPlaceholderCard()
        }
        .padding(CGFloat(FenDesignTokens.spacingLarge))
    }
}
