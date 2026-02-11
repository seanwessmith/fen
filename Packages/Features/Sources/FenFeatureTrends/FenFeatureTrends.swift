import SwiftUI
import FenModels
import FenSwiftUIComponents

public struct TrendsView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Trends")
                .font(.largeTitle)
            FenPlaceholderCard()
        }
        .padding()
    }
}
