import SwiftUI
import FenDesignSystem
import FenModels
import FenSwiftUIComponents

public struct OnboardingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: CGFloat(FenDesignTokens.spacingSmall)) {
            Text("Onboarding")
                .font(.largeTitle)
            FenPlaceholderCard()
        }
        .padding(CGFloat(FenDesignTokens.spacingLarge))
    }
}
