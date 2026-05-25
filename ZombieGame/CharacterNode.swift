import SpriteKit

class CharacterNode: SKNode {

    enum Kind { case playerZombie, aiZombie, human }

    private(set) var kind: Kind
    var isBeingBitten = false
    var isEscorted    = false     // true while member of an EscortGroup
    var target:        SKNode?    // AI zombies — CharacterNode (human) or CopNode / TankNode
    var wanderTarget:  CGPoint?   // humans

    // Stuck-detection / escape
    var stuckTimer:    TimeInterval = 0
    var stuckWaypoint: CGPoint?     = nil

    // Zombie strain
    var zombieType:        ZombieType = .standard
    var pendingZombieType: ZombieType = .standard  // set in startBiteHuman before conversion
    var cureHits:          Int        = 0          // needle hits from scientists

    // HP — per-instance max accounts for zombie type HP multiplier
    private(set) var hp:          CGFloat = 100
    private(set) var instanceMaxHP: CGFloat = 100
    static var maxHP: CGFloat = 100  // base HP; increased by durability upgrade

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
            instanceMaxHP = CharacterNode.maxHP
            hp            = instanceMaxHP
            icon.text = "🧟"
            addPlayerGlow()
            buildHealthBar()
        case .aiZombie:
            instanceMaxHP = CharacterNode.maxHP
            hp            = instanceMaxHP
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
        let pct = hp / max(1, instanceMaxHP)
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

    func heal(_ amount: CGFloat) {
        guard kind == .playerZombie || kind == .aiZombie else { return }
        hp = min(hp + amount, instanceMaxHP)
        refreshHPBar()
    }

    func setInstanceMaxHP(_ newMax: CGFloat) {
        instanceMaxHP = newMax
    }

    func startInfectionVisual() {
        icon.run(.repeatForever(.sequence([
            .colorize(with: SKColor(red: 0.10, green: 0.85, blue: 0.10, alpha: 1),
                      colorBlendFactor: 0.65, duration: 0.35),
            .colorize(withColorBlendFactor: 0, duration: 0.35)
        ])), withKey: "infected")
    }

    func stopInfectionVisual() {
        icon.removeAction(forKey: "infected")
        icon.run(.colorize(withColorBlendFactor: 0, duration: 0.08))
    }

    func becomePlayer() {
        kind = .playerZombie
        instanceMaxHP = CharacterNode.maxHP * ZombieTypeData.info(for: zombieType).hpMult
        addPlayerGlow()
        if hpFill == nil { buildHealthBar() }
        run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.08), .fadeAlpha(to: 1.0, duration: 0.08),
            .fadeAlpha(to: 0.2, duration: 0.08), .fadeAlpha(to: 1.0, duration: 0.08)
        ]))
    }

    func becomeZombie(type: ZombieType = .standard) {
        zombieType    = type
        kind          = .aiZombie
        isBeingBitten = false
        isEscorted    = false
        cureHits      = 0
        wanderTarget  = nil
        instanceMaxHP = CharacterNode.maxHP * ZombieTypeData.info(for: type).hpMult
        hp            = instanceMaxHP

        icon.removeAllActions()         // clear breathe, infection animations
        icon.setScale(1.0)              // reset scale left over from breathe animation
        icon.run(.colorize(withColorBlendFactor: 0, duration: 0))  // clear any colorize
        icon.text = ZombieTypeData.info(for: type).emoji

        // Scale icon by type so strains are visually distinct even at a glance
        switch type {
        case .brute:   icon.setScale(1.35)
        case .hunter:  icon.setScale(1.10)
        case .stalker: icon.setScale(0.80)
        default:       icon.setScale(1.00)
        }

        if hpFill == nil { buildHealthBar() }
        refreshHPBar()
        addStrainGlow(for: type)

        run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.12), .fadeAlpha(to: 1.0, duration: 0.12),
            .fadeAlpha(to: 0.2, duration: 0.12), .fadeAlpha(to: 1.0, duration: 0.12)
        ]))
    }

    func becomeHuman() {
        kind          = .human
        zombieType    = .standard
        isBeingBitten = false
        isEscorted    = false
        cureHits      = 0
        target        = nil
        stuckTimer    = 0
        stuckWaypoint = nil

        // Remove strain glow and HP bar
        children.filter { $0.name == "strainGlow" }.forEach { $0.removeFromParent() }
        hudNode.removeAllChildren()
        hpFill = nil

        icon.removeAllActions()
        icon.setScale(1.0)
        icon.run(.colorize(withColorBlendFactor: 0, duration: 0))
        icon.text = "🧑"
        icon.run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 1.2),
            .scale(to: 1.00, duration: 1.2)
        ])), withKey: "breathe")

        // Flash white-blue (cured)
        run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.08), .fadeAlpha(to: 1.0, duration: 0.08),
            .fadeAlpha(to: 0.2, duration: 0.08), .fadeAlpha(to: 1.0, duration: 0.08)
        ]))
    }

    /// Returns true when enough cure hits have accumulated to convert back to human.
    func takeCureHit() -> Bool {
        guard kind == .playerZombie || kind == .aiZombie else { return false }
        cureHits += 1
        icon.run(.sequence([
            .colorize(with: SKColor(red: 0.20, green: 0.95, blue: 0.95, alpha: 1),
                      colorBlendFactor: 0.75, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.25)
        ]))
        return cureHits >= ScientistNode.cureHitsNeeded
    }

    private func addStrainGlow(for type: ZombieType) {
        children.filter { $0.name == "strainGlow" }.forEach { $0.removeFromParent() }
        guard type != .standard else { return }

        let (fillColor, strokeColor, radius, pulseDur): (SKColor, SKColor, CGFloat, Double)
        switch type {
        case .hunter:
            fillColor   = SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 0.20)
            strokeColor = SKColor(red: 1.00, green: 0.65, blue: 0.10, alpha: 0.70)
            radius = 24; pulseDur = 0.45
        case .brute:
            fillColor   = SKColor(red: 0.55, green: 0.00, blue: 0.80, alpha: 0.22)
            strokeColor = SKColor(red: 0.70, green: 0.10, blue: 1.00, alpha: 0.75)
            radius = 34; pulseDur = 0.90
        case .screamer:
            fillColor   = SKColor(red: 0.80, green: 0.00, blue: 1.00, alpha: 0.18)
            strokeColor = SKColor(red: 0.90, green: 0.20, blue: 1.00, alpha: 0.65)
            radius = 22; pulseDur = 0.30
        case .stalker:
            fillColor   = SKColor(red: 0.00, green: 0.95, blue: 0.90, alpha: 0.16)
            strokeColor = SKColor(red: 0.10, green: 1.00, blue: 0.95, alpha: 0.65)
            radius = 20; pulseDur = 0.20
        case .spitter:
            fillColor   = SKColor(red: 0.25, green: 1.00, blue: 0.00, alpha: 0.18)
            strokeColor = SKColor(red: 0.40, green: 1.00, blue: 0.10, alpha: 0.65)
            radius = 24; pulseDur = 0.55
        default: return
        }

        let glow = SKShapeNode(circleOfRadius: radius)
        glow.fillColor   = fillColor
        glow.strokeColor = strokeColor
        glow.lineWidth   = 2
        glow.zPosition   = 0
        glow.name        = "strainGlow"
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.35, duration: pulseDur),
            .scale(to: 1.00, duration: pulseDur)
        ])))
        addChild(glow)
    }
}
