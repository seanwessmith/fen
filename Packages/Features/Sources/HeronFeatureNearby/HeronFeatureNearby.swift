import SwiftUI
import HeronModels
import HeronSwiftUIComponents

public struct NearbyView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Nearby")
                .font(.largeTitle)
            HeronPlaceholderCard()
        }
        .padding()
    }
}
