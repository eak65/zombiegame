import SpriteKit

class CopNode: SKNode {

    // Revolver constants
    static let maxAmmo      = 6
    static let fireInterval: TimeInterval = 0.55   // ~1 shot / 0.55 s
    static let reloadTime:   TimeInterval = 5.0
    static let shootRange:   CGFloat      = 300
    static let bulletSpread: CGFloat      = 0.10   // ± radians (~5.7°)

    var isBeingBitten = false

    private(set) var ammo      = CopNode.maxAmmo
    private(set) var reloading = false
    private var sinceShot:  TimeInterval = CopNode.fireInterval  // ready immediately
    private var reloadLeft: TimeInterval = 0

    // Visuals
    private var icon:        SKLabelNode!
    private var hudNode:     SKNode!        // stays unflipped when cop faces left
    private var ammoDots:    [SKShapeNode] = []
    private var reloadLabel: SKLabelNode!

    override init() {
        super.init()
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 34, height: 10))
        shadow.fillColor   = SKColor(white: 0, alpha: 0.28)
        shadow.strokeColor = .clear
        shadow.position    = CGPoint(x: 0, y: -20)
        shadow.zPosition   = -1
        addChild(shadow)

        icon = SKLabelNode(text: "👮")
        icon.fontSize                = 36
        icon.verticalAlignmentMode   = .center
        icon.horizontalAlignmentMode = .center
        icon.zPosition               = 5
        addChild(icon)

        hudNode           = SKNode()
        hudNode.zPosition = 6
        addChild(hudNode)

        // 6 ammo dots above the cop
        let spacing: CGFloat = 10
        let totalW           = spacing * CGFloat(CopNode.maxAmmo - 1)
        for i in 0 ..< CopNode.maxAmmo {
            let dot = SKShapeNode(circleOfRadius: 3.5)
            dot.fillColor   = ammoColor(loaded: true)
            dot.strokeColor = .clear
            dot.position    = CGPoint(x: -totalW/2 + CGFloat(i)*spacing, y: 30)
            ammoDots.append(dot)
            hudNode.addChild(dot)
        }

        reloadLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        reloadLabel.text                  = "RELOAD"
        reloadLabel.fontSize              = 9
        reloadLabel.fontColor             = SKColor(red: 1, green: 0.30, blue: 0.30, alpha: 1)
        reloadLabel.horizontalAlignmentMode = .center
        reloadLabel.position              = CGPoint(x: 0, y: 30)
        reloadLabel.isHidden              = true
        hudNode.addChild(reloadLabel)
    }

    // MARK: - Per-frame update
    // Returns the unit-direction vector to fire along, or nil when not firing.

    func update(dt: TimeInterval, toward target: SKNode?) -> CGVector? {
        guard !isBeingBitten else { return nil }

        if reloading {
            reloadLeft -= dt
            if reloadLeft <= 0 {
                reloading            = false
                ammo                 = CopNode.maxAmmo
                sinceShot            = CopNode.fireInterval
                reloadLabel.isHidden = true
                reloadLabel.removeAction(forKey: "blink")
                refreshDots()
            }
            return nil
        }

        sinceShot += dt
        guard sinceShot >= CopNode.fireInterval, let target, ammo > 0 else { return nil }

        sinceShot = 0
        ammo     -= 1
        refreshDots()
        muzzleFlash()

        if ammo == 0 { beginReload() }

        let dx  = target.position.x - position.x
        let dy  = target.position.y - position.y
        let len = sqrt(dx*dx + dy*dy)
        guard len > 0 else { return nil }

        let base   = atan2(dy, dx)
        let spread = CGFloat.random(in: -CopNode.bulletSpread ... CopNode.bulletSpread)
        let angle  = base + spread
        faceDirection(CGVector(dx: dx, dy: dy))
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    // MARK: - Bite (same protocol as humans)

    func playBiteAnimation() {
        let shake = SKAction.sequence([
            .moveBy(x: -7, y: 0, duration: 0.055),
            .moveBy(x: 14, y: 0, duration: 0.055),
            .moveBy(x: -7, y: 0, duration: 0.055)
        ])
        run(.repeat(shake, count: 3))
    }

    // MARK: - Private helpers

    private func beginReload() {
        reloading            = true
        reloadLeft           = CopNode.reloadTime
        reloadLabel.isHidden = false
        reloadLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.40),
            .fadeAlpha(to: 1.00, duration: 0.40)
        ])), withKey: "blink")
    }

    private func refreshDots() {
        for (i, dot) in ammoDots.enumerated() {
            dot.fillColor = ammoColor(loaded: i < ammo)
        }
    }

    private func ammoColor(loaded: Bool) -> SKColor {
        loaded
            ? SKColor(red: 1.0, green: 0.85, blue: 0.10, alpha: 1)
            : SKColor(white: 0.28, alpha: 1)
    }

    private func muzzleFlash() {
        let flash = SKShapeNode(circleOfRadius: 11)
        flash.fillColor   = SKColor(red: 1, green: 0.92, blue: 0.35, alpha: 0.88)
        flash.strokeColor = .clear
        flash.position    = CGPoint(x: 0, y: 12)
        flash.zPosition   = 7
        addChild(flash)
        flash.run(.sequence([
            .scale(to: 1.6, duration: 0.04),
            .fadeOut(withDuration: 0.06),
            .removeFromParent()
        ]))
    }

    private func faceDirection(_ dir: CGVector) {
        guard abs(dir.dx) > 0.05 else { return }
        xScale         = dir.dx < 0 ? -1 : 1
        hudNode.xScale = xScale
    }
}
