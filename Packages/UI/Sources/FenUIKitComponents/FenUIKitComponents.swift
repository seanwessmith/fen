#if canImport(UIKit)
import UIKit
import FenDesignSystem

public final class FenPlaceholderView: UIView {
    private let titleLabel = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Fen"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
#else
import Foundation
import FenDesignSystem

public final class FenPlaceholderView {}
#endif
