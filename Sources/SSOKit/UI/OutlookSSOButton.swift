//
//  OutlookSSOButton.swift
//  SSOKit
//
//  Ready-made "SSO Login" button: a dark, rounded pill with the four-square
//  Microsoft logo (drawn programmatically — no asset dependency) and a white
//  title. Drop it anywhere; it sizes itself. Every design token has a sensible
//  default and can be overridden per host app.
//

import UIKit

public final class OutlookSSOButton: UIButton {

    // MARK: - Design tokens (override before the button first lays out)

    public var cornerRadius: CGFloat = 18.0 {
        didSet { layer.cornerRadius = cornerRadius }
    }

    public var preferredHeight: CGFloat = 64.0 {
        didSet { invalidateIntrinsicContentSize() }
    }

    public var logoSize: CGFloat = 22.0

    public var backgroundFill = UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0) { // ~#2E2E30
        didSet { backgroundColor = backgroundFill }
    }

    public var titleText = "SSO Login" {
        didSet { setTitle(titleText, for: .normal) }
    }

    private let logoView = MicrosoftLogoView()

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = backgroundFill
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        setTitle(titleText, for: .normal)
        setTitleColor(.white, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 19, weight: .semibold)
        // Scale the title down gracefully when the button shares a row with
        // another button (narrower width).
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.7
        titleLabel?.lineBreakMode = .byClipping

        // Microsoft logo to the left of the title.
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.isUserInteractionEnabled = false
        addSubview(logoView)

        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: logoSize),
            logoView.heightAnchor.constraint(equalToConstant: logoSize),
            logoView.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoView.trailingAnchor.constraint(equalTo: titleLabel!.leadingAnchor, constant: -14)
        ])

        // Keep the title visually centred while leaving room for the logo.
        contentHorizontalAlignment = .center
        titleEdgeInsets = UIEdgeInsets(top: 0, left: logoSize / 2 + 7, bottom: 0, right: 0)

        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    // MARK: - Sizing

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight)
    }

    // MARK: - Press feedback

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.08) {
            self.alpha = 0.85
            self.transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
        }
    }

    @objc private func touchUp() {
        UIView.animate(withDuration: 0.12) {
            self.alpha = 1.0
            self.transform = .identity
        }
    }
}

/// The four-square Microsoft logo, drawn with Core Graphics.
private final class MicrosoftLogoView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        let gap = rect.width * 0.08
        let tile = (rect.width - gap) / 2.0

        let red    = UIColor(red: 0.95, green: 0.27, blue: 0.13, alpha: 1.0) // F25022
        let green  = UIColor(red: 0.50, green: 0.73, blue: 0.02, alpha: 1.0) // 7FBA00
        let blue   = UIColor(red: 0.00, green: 0.66, blue: 0.94, alpha: 1.0) // 00A4EF
        let yellow = UIColor(red: 1.00, green: 0.73, blue: 0.00, alpha: 1.0) // FFB900

        func fill(_ color: UIColor, _ x: CGFloat, _ y: CGFloat) {
            color.setFill()
            UIBezierPath(rect: CGRect(x: x, y: y, width: tile, height: tile)).fill()
        }

        let right = tile + gap
        fill(red,    rect.minX,         rect.minY)
        fill(green,  rect.minX + right, rect.minY)
        fill(blue,   rect.minX,         rect.minY + right)
        fill(yellow, rect.minX + right, rect.minY + right)
    }
}
