import SwiftUI
import HeronMedia
import HeronModels
import HeronSync
import HeronSwiftUIComponents

public struct CaptureView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Capture")
                .font(.largeTitle)
            HeronPlaceholderCard()
        }
        .padding()
    }
}
