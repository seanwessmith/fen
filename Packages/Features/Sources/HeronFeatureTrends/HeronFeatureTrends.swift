import SwiftUI
import HeronModels
import HeronSwiftUIComponents

public struct TrendsView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Trends")
                .font(.largeTitle)
            HeronPlaceholderCard()
        }
        .padding()
    }
}
