import SpriteKit

class CharacterNode: SKNode {

    enum Kind { case playerZombie, aiZombie, human }

    private(set) var kind: Kind
    var isBeingBitten = false
    var target:       SKNode?    // AI zombies — CharacterNode (human) or CopNode
    var wanderTarget: CGPoint?   // humans

    // HP — only meaningful for zombies; set when becomeZombie() is called
    private(set) var hp: CGFloat = 100
    static let maxHP: CGFloat    = 100

    private var icon:        SKLabelNode!
    private var hudNode:     SKNode!      // child that stays unflipped
    private var hpFill:      SKShapeNode?
    private let hpBarWidth:  CGFloat = 42

    init(type: Kind) {
        self.kind = type
        super.init()
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 34, height: 10))
        shadow.fillColor  = SKColor(white: 0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.position   = CGPoint(x: 0, y: -20)
        shadow.zPosition  = -1
        addChild(shadow)

        icon = SKLabelNode()
        icon.fontSize                = 38
        icon.verticalAlignmentMode   = .center
        icon.horizontalAlignmentMode = .center
        icon.zPosition               = 1
        addChild(icon)

        // Separate child node for HUD elements — xScale is flipped to counteract
        // the parent's facing flip so bars/labels always read left-to-right.
        hudNode = SKNode()
        hudNode.zPosition = 6
        addChild(hudNode)

        applyAppearance()
    }

    private func applyAppearance() {
        switch kind {
        case .playerZombie:
            icon.text = "🧟"
            addPlayerGlow()
            buildHealthBar()
        case .aiZombie:
            icon.text = "🧟"
            buildHealthBar()
        case .human:
            icon.text = "🧑"
            icon.run(.repeatForever(.sequence([
                .scale(to: 1.08, duration: 1.2),
                .scale(to: 1.00, duration: 1.2)
            ])), withKey: "breathe")
        }
    }

    private func addPlayerGlow() {
        let glow = SKShapeNode(circleOfRadius: 28)
        glow.fillColor   = SKColor(red: 1, green: 0.15, blue: 0.15, alpha: 0.22)
        glow.strokeColor = SKColor(red: 1, green: 0.40, blue: 0.40, alpha: 0.55)
        glow.lineWidth   = 2
        glow.zPosition   = 0
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.35, duration: 0.55),
            .scale(to: 1.00, duration: 0.55)
        ])))
        addChild(glow)
    }

    private func buildHealthBar() {
        let bg = SKShapeNode(rectOf: CGSize(width: hpBarWidth + 4, height: 7), cornerRadius: 2)
        bg.fillColor   = SKColor(white: 0.12, alpha: 0.85)
        bg.strokeColor = .clear
        bg.position    = CGPoint(x: 0, y: 30)
        hudNode.addChild(bg)

        let fill = SKShapeNode(rectOf: CGSize(width: hpBarWidth, height: 5), cornerRadius: 1.5)
        fill.fillColor   = SKColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1)
        fill.strokeColor = .clear
        fill.position    = CGPoint(x: 0, y: 30)
        hudNode.addChild(fill)
        hpFill = fill
    }

    // MARK: - Public API

    /// Returns true when the zombie is dead (hp ≤ 0).
    func takeDamage(_ amount: CGFloat) -> Bool {
        guard kind == .playerZombie || kind == .aiZombie else { return false }
        hp = max(0, hp - amount)
        refreshHPBar()

        // Red flash
        icon.run(.sequence([
            .colorize(with: .red, colorBlendFactor: 0.8, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.15)
        ]))
        return hp <= 0
    }

    private func refreshHPBar() {
        guard let fill = hpFill else { return }
        let pct = hp / CharacterNode.maxHP
        fill.xScale    = pct
        fill.position.x = -(hpBarWidth / 2) * (1 - pct)
        switch pct {
        case 0.5...: fill.fillColor = SKColor(red: 0.15, green: 0.90, blue: 0.15, alpha: 1)
        case 0.25...: fill.fillColor = SKColor(red: 1.00, green: 0.65, blue: 0.10, alpha: 1)
        default:      fill.fillColor = SKColor(red: 0.90, green: 0.10, blue: 0.10, alpha: 1)
        }
    }

    func faceDirection(_ dir: CGVector) {
        guard abs(dir.dx) > 0.05 else { return }
        xScale         = dir.dx < 0 ? -1 : 1
        hudNode.xScale = xScale      // counteract flip so HP bar stays readable
    }

    func playBiteAnimation() {
        let shake = SKAction.sequence([
            .moveBy(x: -7, y: 0, duration: 0.055),
            .moveBy(x: 14, y: 0, duration: 0.055),
            .moveBy(x: -7, y: 0, duration: 0.055)
        ])
        run(.repeat(shake, count: 3))
        icon.run(.sequence([.scale(to: 1.3, duration: 0.15), .scale(to: 1.0, duration: 0.15)]))
    }

    func becomeZombie() {
        kind          = .aiZombie
        isBeingBitten = false
        wanderTarget  = nil
        hp            = CharacterNode.maxHP
        icon.removeAction(forKey: "breathe")
        icon.text = "🧟"

        // Build health bar if not already present (converting from human)
        if hpFill == nil { buildHealthBar() }
        refreshHPBar()

        run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.12), .fadeAlpha(to: 1.0, duration: 0.12),
            .fadeAlpha(to: 0.2, duration: 0.12), .fadeAlpha(to: 1.0, duration: 0.12)
        ]))
    }
}
