import SpriteKit

class SoldierNode: SKNode {

    // M4 carbine constants
    static let maxAmmo      = 12
    static let fireInterval: TimeInterval = 0.22   // full-auto, ~4-5 rps
    static let reloadTime:   TimeInterval = 3.5    // faster than revolver
    static let shootRange:   CGFloat      = 340
    static let bulletSpread: CGFloat      = 0.18   // auto-fire has more spread

    var isBeingBitten = false

    private(set) var ammo      = SoldierNode.maxAmmo
    private(set) var reloading = false
    private var sinceShot:  TimeInterval = SoldierNode.fireInterval
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

        icon = SKLabelNode(text: "🪖")
        icon.fontSize                = 36
        icon.verticalAlignmentMode   = .center
        icon.horizontalAlignmentMode = .center
        icon.zPosition               = 5
        addChild(icon)

        hudNode           = SKNode()
        hudNode.zPosition = 6
        addChild(hudNode)

        // 12 ammo dots in two rows of 6
        let spacing: CGFloat = 8
        let colCount = 6
        for i in 0 ..< SoldierNode.maxAmmo {
            let col = i % colCount
            let row = i / colCount          // 0 = bottom row, 1 = top row
            let dot = SKShapeNode(circleOfRadius: 2.8)
            dot.fillColor   = ammoColor(loaded: true)
            dot.strokeColor = .clear
            let totalW = spacing * CGFloat(colCount - 1)
            dot.position = CGPoint(
                x: -totalW/2 + CGFloat(col) * spacing,
                y: 28 + CGFloat(row) * 7
            )
            ammoDots.append(dot)
            hudNode.addChild(dot)
        }

        reloadLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        reloadLabel.text                    = "RELOAD"
        reloadLabel.fontSize                = 9
        reloadLabel.fontColor               = SKColor(red: 0.30, green: 1.00, blue: 0.30, alpha: 1)
        reloadLabel.horizontalAlignmentMode = .center
        reloadLabel.position                = CGPoint(x: 0, y: 30)
        reloadLabel.isHidden                = true
        hudNode.addChild(reloadLabel)
    }

    // MARK: - Per-frame update

    func update(dt: TimeInterval, toward target: SKNode?) -> CGVector? {
        guard !isBeingBitten else { return nil }

        if reloading {
            reloadLeft -= dt
            if reloadLeft <= 0 {
                reloading            = false
                ammo                 = SoldierNode.maxAmmo
                sinceShot            = SoldierNode.fireInterval
                reloadLabel.isHidden = true
                reloadLabel.removeAction(forKey: "blink")
                refreshDots()
            }
            return nil
        }

        sinceShot += dt
        guard sinceShot >= SoldierNode.fireInterval, let target, ammo > 0 else { return nil }

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
        let spread = CGFloat.random(in: -SoldierNode.bulletSpread ... SoldierNode.bulletSpread)
        let angle  = base + spread
        faceDirection(CGVector(dx: dx, dy: dy))
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    // MARK: - Bite

    func playBiteAnimation() {
        let shake = SKAction.sequence([
            .moveBy(x: -7, y: 0, duration: 0.055),
            .moveBy(x: 14, y: 0, duration: 0.055),
            .moveBy(x: -7, y: 0, duration: 0.055)
        ])
        run(.repeat(shake, count: 3))
    }

    // MARK: - Formation facing

    func lookAt(_ target: CGPoint) {
        let dx = target.x - position.x
        guard abs(dx) > 0.05 else { return }
        xScale         = dx < 0 ? -1 : 1
        hudNode.xScale = xScale
    }

    // MARK: - Private helpers

    private func beginReload() {
        reloading            = true
        reloadLeft           = SoldierNode.reloadTime
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
        loaded
            ? SKColor(red: 0.30, green: 0.90, blue: 0.30, alpha: 1)
            : SKColor(white: 0.28, alpha: 1)
    }

    private func muzzleFlash() {
        let flash = SKShapeNode(circleOfRadius: 9)
        flash.fillColor   = SKColor(red: 0.70, green: 1.00, blue: 0.40, alpha: 0.88)
        flash.strokeColor = .clear
        flash.position    = CGPoint(x: 0, y: 12)
        flash.zPosition   = 7
        addChild(flash)
        flash.run(.sequence([
            .scale(to: 1.8, duration: 0.03),
            .fadeOut(withDuration: 0.05),
            .removeFromParent()
        ]))
    }

    private func faceDirection(_ dir: CGVector) {
        guard abs(dir.dx) > 0.05 else { return }
        xScale         = dir.dx < 0 ? -1 : 1
        hudNode.xScale = xScale
    }
}
