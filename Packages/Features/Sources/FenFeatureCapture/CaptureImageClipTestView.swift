import SwiftUI

public struct CaptureImageClipTestView: View {
    private let demoURL = URL(string: "https://picsum.photos/900/600")

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Image Clip Test")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Compare current and strict clipping behavior in isolation.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 14) {
                    VStack(spacing: 8) {
                        Text("Current")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        ClipTestCurrentTile(url: demoURL)
                    }

                    VStack(spacing: 8) {
                        Text("Strict")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        ClipTestStrictTile(url: demoURL)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Local Stress Test (no network)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    ClipTestLocalStressTile()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Clip Test")
    }
}

private struct ClipTestCurrentTile: View {
    let url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.10))

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.65))
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(width: 160, height: 160)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct ClipTestStrictTile: View {
    let url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.10))

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.65))
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(width: 160, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct ClipTestLocalStressTile: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.10))

            ZStack {
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(-6...6, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 14, height: 360)
                        .rotationEffect(.degrees(Double(index) * 10))
                }

                Text("CLIP")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .offset(x: 64, y: -52)
            }
            .frame(width: 320, height: 240)
        }
        .frame(width: 334, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}

