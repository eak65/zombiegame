import SpriteKit

class ScientistNode: SKNode {

    static let maxAmmo:      Int          = 6
    static let fireInterval: TimeInterval = 0.85   // clinical, steady fire
    static let reloadTime:   TimeInterval = 8.0    // reloading cure dispenser
    static let shootRange:   CGFloat      = 260
    static let bulletSpread: CGFloat      = 0.05   // very precise
    static let cureHitsNeeded: Int        = 3      // hits to cure a zombie

    var isBeingBitten = false

    private(set) var ammo      = ScientistNode.maxAmmo
    private(set) var reloading = false
    private var sinceShot:  TimeInterval = ScientistNode.fireInterval
    private var reloadLeft: TimeInterval = 0

    private var icon:        SKLabelNode!
    private var hudNode:     SKNode!
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

        // Lab coat glow
        let glow = SKShapeNode(circleOfRadius: 24)
        glow.fillColor   = SKColor(red: 0.15, green: 0.80, blue: 0.90, alpha: 0.18)
        glow.strokeColor = SKColor(red: 0.20, green: 0.90, blue: 1.00, alpha: 0.55)
        glow.lineWidth   = 1.5
        glow.zPosition   = 0
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.30, duration: 0.70),
            .scale(to: 1.00, duration: 0.70)
        ])))
        addChild(glow)

        icon = SKLabelNode(text: "👨‍🔬")
        icon.fontSize                = 34
        icon.verticalAlignmentMode   = .center
        icon.horizontalAlignmentMode = .center
        icon.zPosition               = 5
        addChild(icon)

        hudNode           = SKNode()
        hudNode.zPosition = 6
        addChild(hudNode)

        // 6 cure-vial dots
        let spacing: CGFloat = 9
        let totalW = spacing * CGFloat(ScientistNode.maxAmmo - 1)
        for i in 0 ..< ScientistNode.maxAmmo {
            let dot = SKShapeNode(rectOf: CGSize(width: 5, height: 10), cornerRadius: 2)
            dot.fillColor   = ammoColor(loaded: true)
            dot.strokeColor = .clear
            dot.position    = CGPoint(x: -totalW/2 + CGFloat(i) * spacing, y: 28)
            ammoDots.append(dot)
            hudNode.addChild(dot)
        }

        reloadLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        reloadLabel.text                    = "RELOAD"
        reloadLabel.fontSize                = 9
        reloadLabel.fontColor               = SKColor(red: 0.20, green: 1.00, blue: 1.00, alpha: 1)
        reloadLabel.horizontalAlignmentMode = .center
        reloadLabel.position                = CGPoint(x: 0, y: 30)
        reloadLabel.isHidden                = true
        hudNode.addChild(reloadLabel)
    }

    // MARK: - Per-frame update

    func update(dt: TimeInterval, toward target: CharacterNode?) -> CGVector? {
        guard !isBeingBitten else { return nil }

        if reloading {
            reloadLeft -= dt
            if reloadLeft <= 0 {
                reloading            = false
                ammo                 = ScientistNode.maxAmmo
                sinceShot            = ScientistNode.fireInterval
                reloadLabel.isHidden = true
                reloadLabel.removeAction(forKey: "blink")
                refreshDots()
            }
            return nil
        }

        sinceShot += dt
        guard sinceShot >= ScientistNode.fireInterval, let target, ammo > 0 else { return nil }

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
        let spread = CGFloat.random(in: -ScientistNode.bulletSpread ... ScientistNode.bulletSpread)
        let angle  = base + spread
        lookAt(CGPoint(x: target.position.x, y: target.position.y))
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    func playBiteAnimation() {
        let shake = SKAction.sequence([
            .moveBy(x: -7, y: 0, duration: 0.055),
            .moveBy(x: 14, y: 0, duration: 0.055),
            .moveBy(x: -7, y: 0, duration: 0.055)
        ])
        run(.repeat(shake, count: 3))
    }

    func lookAt(_ target: CGPoint) {
        let dx = target.x - position.x
        guard abs(dx) > 0.05 else { return }
        xScale         = dx < 0 ? -1 : 1
        hudNode.xScale = xScale
    }

    // MARK: - Private helpers

    private func beginReload() {
        reloading            = true
        reloadLeft           = ScientistNode.reloadTime
        reloadLabel.isHidden = false
        reloadLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.35),
            .fadeAlpha(to: 1.00, duration: 0.35)
        ])), withKey: "blink")
    }

    private func refreshDots() {
        for (i, dot) in ammoDots.enumerated() {
            dot.fillColor = ammoColor(loaded: i < ammo)
        }
    }

    private func ammoColor(loaded: Bool) -> SKColor {
        loaded ? SKColor(red: 0.20, green: 0.90, blue: 0.90, alpha: 1)
               : SKColor(white: 0.28, alpha: 1)
    }

    private func muzzleFlash() {
        let flash = SKShapeNode(circleOfRadius: 7)
        flash.fillColor   = SKColor(red: 0.20, green: 0.95, blue: 0.95, alpha: 0.90)
        flash.strokeColor = .clear
        flash.position    = CGPoint(x: 0, y: 12)
        flash.zPosition   = 7
        addChild(flash)
        flash.run(.sequence([
            .scale(to: 1.6, duration: 0.04),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }
}
