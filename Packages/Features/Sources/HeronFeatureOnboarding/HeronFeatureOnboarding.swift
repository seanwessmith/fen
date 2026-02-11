import SwiftUI
import HeronDesignSystem
import HeronModels
import HeronSwiftUIComponents

public struct OnboardingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: CGFloat(HeronDesignTokens.spacingSmall)) {
            Text("Onboarding")
                .font(.largeTitle)
            HeronPlaceholderCard()
        }
        .padding(CGFloat(HeronDesignTokens.spacingLarge))
    }
}
