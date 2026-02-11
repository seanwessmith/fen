import SwiftUI
import FenModels
import FenSwiftUIComponents

public struct NearbyView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Nearby")
                .font(.largeTitle)
            FenPlaceholderCard()
        }
        .padding()
    }
}
