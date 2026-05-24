import SpriteKit

// MARK: - Step definitions

enum TutorialStep: Int, CaseIterable {
    case move        // drag joystick
    case bite        // walk into a civilian
    case evoPoint    // first conversion happened — show EP earned
    case openPanel   // tap the DNA button
    case buyUpgrade  // purchase any upgrade
    case complete    // done — launch real game
}

// MARK: - TutorialNode

/// Full-screen overlay that manages the tutorial card + directional arrow.
/// All coordinates are in the camera's local space.
class TutorialNode: SKNode {

    // Geometry
    private let sceneSize: CGSize

    // UI pieces
    private let dimmer:     SKShapeNode  // subtle dark tint behind card
    private let card:       SKShapeNode
    private let titleLabel: SKLabelNode
    private let bodyLabel:  SKLabelNode
    private let arrow:      SKShapeNode  // filled downward triangle

    // Step indicator dots
    private var dots: [SKShapeNode] = []
    private let stepCount = TutorialStep.allCases.count

    // Card sits just above the bottom controls
    private var cardY: CGFloat { -sceneSize.height / 2 + 190 }

    init(sceneSize: CGSize) {
        self.sceneSize = sceneSize
        let cardW: CGFloat = min(sceneSize.width - 48, 360)

        // Background dimmer behind card area
        dimmer = SKShapeNode(rectOf: CGSize(width: cardW + 24, height: 110), cornerRadius: 16)
        dimmer.fillColor   = SKColor(white: 0, alpha: 0.50)
        dimmer.strokeColor = .clear

        // Card
        card = SKShapeNode(rectOf: CGSize(width: cardW, height: 86), cornerRadius: 13)
        card.fillColor   = SKColor(red: 0.04, green: 0.10, blue: 0.04, alpha: 0.94)
        card.strokeColor = SKColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 0.75)
        card.lineWidth   = 2

        // Title
        titleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        titleLabel.fontSize               = 15
        titleLabel.fontColor              = SKColor(red: 0.40, green: 1.00, blue: 0.45, alpha: 1)
        titleLabel.verticalAlignmentMode  = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 18)
        titleLabel.numberOfLines = 1

        // Body
        bodyLabel = SKLabelNode(fontNamed: "Menlo")
        bodyLabel.fontSize               = 12
        bodyLabel.fontColor              = SKColor(white: 0.85, alpha: 1)
        bodyLabel.verticalAlignmentMode  = .center
        bodyLabel.horizontalAlignmentMode = .center
        bodyLabel.position = CGPoint(x: 0, y: -6)
        bodyLabel.numberOfLines = 2

        // Arrow (downward triangle, bounces above target)
        let path = CGMutablePath()
        path.move(to:    CGPoint(x:   0, y: 14))
        path.addLine(to: CGPoint(x: -11, y: -7))
        path.addLine(to: CGPoint(x:  11, y: -7))
        path.closeSubpath()
        arrow = SKShapeNode(path: path)
        arrow.fillColor   = SKColor(red: 0.35, green: 1.00, blue: 0.40, alpha: 0.92)
        arrow.strokeColor = .clear
        arrow.isHidden    = true

        super.init()

        // Build hierarchy
        addChild(dimmer)
        card.addChild(titleLabel)
        card.addChild(bodyLabel)
        addChild(card)
        addChild(arrow)

        // Progress dots
        buildDots(count: stepCount)

        // Initial placement
        let y = cardY
        dimmer.position = CGPoint(x: 0, y: y)
        card.position   = CGPoint(x: 0, y: y)
        updateDotPositions(y: y - 52)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func showStep(_ step: TutorialStep, title: String, body: String, arrowAt: CGPoint? = nil) {
        isHidden = false
        alpha    = 1

        titleLabel.text    = title
        bodyLabel.text     = body
        bodyLabel.isHidden = body.isEmpty

        updateDots(current: step.rawValue)

        // Arrow
        arrow.removeAllActions()
        if let pt = arrowAt {
            arrow.isHidden = false
            arrow.position = CGPoint(x: pt.x, y: pt.y + 46)
            arrow.run(.repeatForever(.sequence([
                .moveBy(x: 0, y:  10, duration: 0.36),
                .moveBy(x: 0, y: -10, duration: 0.36)
            ])), withKey: "bounce")
        } else {
            arrow.isHidden = true
        }

        // Pop-in animation
        card.setScale(0.88)
        card.run(.sequence([
            .scale(to: 1.04, duration: 0.12),
            .scale(to: 1.00, duration: 0.08)
        ]))
        dimmer.alpha = 0
        dimmer.run(.fadeAlpha(to: 1, duration: 0.18))
    }

    func dismiss(completion: (() -> Void)? = nil) {
        let fade = SKAction.group([
            .scale(to: 0.88, duration: 0.14),
            .fadeOut(withDuration: 0.14)
        ])
        run(.sequence([fade, .run { completion?() }]))
    }

    func flash(label text: String) {
        let flash = SKLabelNode(fontNamed: "Menlo-Bold")
        flash.text      = text
        flash.fontSize  = 24
        flash.fontColor = SKColor(red: 0.30, green: 1.00, blue: 0.40, alpha: 1)
        flash.horizontalAlignmentMode = .center
        flash.verticalAlignmentMode   = .center
        flash.position  = CGPoint(x: 0, y: cardY + 60)
        flash.zPosition = 5
        addChild(flash)
        flash.run(.sequence([
            .group([
                .scale(to: 1.4, duration: 0.18),
                .sequence([.wait(forDuration: 0.12), .fadeOut(withDuration: 0.50)])
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Private helpers

    private func buildDots(count: Int) {
        let spacing: CGFloat = 14
        let totalW = spacing * CGFloat(count - 1)
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.strokeColor = .clear
            dots.append(dot)
            addChild(dot)
        }
        // Initial positions set in init after cardY is known
        _ = totalW   // silence warning
    }

    private func updateDotPositions(y: CGFloat) {
        let spacing: CGFloat = 14
        let totalW = spacing * CGFloat(dots.count - 1)
        for (i, dot) in dots.enumerated() {
            dot.position = CGPoint(x: -totalW/2 + CGFloat(i) * spacing, y: y)
        }
    }

    private func updateDots(current: Int) {
        for (i, dot) in dots.enumerated() {
            if i < current {
                dot.fillColor = SKColor(red: 0.25, green: 0.75, blue: 0.30, alpha: 0.60)
            } else if i == current {
                dot.fillColor = SKColor(red: 0.35, green: 1.00, blue: 0.40, alpha: 1.00)
                dot.run(.sequence([
                    .scale(to: 1.5, duration: 0.12),
                    .scale(to: 1.0, duration: 0.10)
                ]))
            } else {
                dot.fillColor = SKColor(white: 0.30, alpha: 0.60)
            }
        }
    }
}
