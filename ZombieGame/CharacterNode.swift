import SpriteKit

class CharacterNode: SKNode {

    enum Kind { case playerZombie, aiZombie, human }

    private(set) var kind: Kind
    var isBeingBitten = false
    var targetHuman: CharacterNode?

    private var icon: SKLabelNode!

    init(type: Kind) {
        self.kind = type
        super.init()
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        // Drop shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 34, height: 10))
        shadow.fillColor = SKColor(white: 0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -20)
        shadow.zPosition = -1
        addChild(shadow)

        icon = SKLabelNode()
        icon.fontSize = 38
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.zPosition = 1
        addChild(icon)

        applyAppearance()
    }

    private func applyAppearance() {
        switch kind {
        case .playerZombie:
            icon.text = "🧟"
            addPlayerGlow()
        case .aiZombie:
            icon.text = "🧟"
        case .human:
            icon.text = "🧑"
            startIdleBreathing()
        }
    }

    private func addPlayerGlow() {
        let glow = SKShapeNode(circleOfRadius: 28)
        glow.fillColor = SKColor(red: 1, green: 0.15, blue: 0.15, alpha: 0.22)
        glow.strokeColor = SKColor(red: 1, green: 0.4, blue: 0.4, alpha: 0.55)
        glow.lineWidth = 2
        glow.zPosition = 0
        glow.name = "glow"
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.35, duration: 0.55),
            .scale(to: 1.00, duration: 0.55)
        ])))
        addChild(glow)
    }

    private func startIdleBreathing() {
        icon.run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 1.2),
            .scale(to: 1.00, duration: 1.2)
        ])), withKey: "breathe")
    }

    // MARK: - Public API

    func faceDirection(_ dir: CGVector) {
        guard abs(dir.dx) > 0.05 else { return }
        xScale = dir.dx < 0 ? -1 : 1
    }

    func playBiteAnimation() {
        let shake = SKAction.sequence([
            .moveBy(x: -7, y: 0, duration: 0.055),
            .moveBy(x: 14, y: 0, duration: 0.055),
            .moveBy(x: -7, y: 0, duration: 0.055)
        ])
        run(.repeat(shake, count: 3))
        icon.run(.sequence([
            .scale(to: 1.3, duration: 0.15),
            .scale(to: 1.0, duration: 0.15)
        ]))
    }

    func becomeZombie() {
        kind = .aiZombie
        isBeingBitten = false
        icon.removeAction(forKey: "breathe")
        icon.text = "🧟"
        // Flash effect
        run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.12),
            .fadeAlpha(to: 1.0, duration: 0.12),
            .fadeAlpha(to: 0.2, duration: 0.12),
            .fadeAlpha(to: 1.0, duration: 0.12)
        ]))
    }
}
