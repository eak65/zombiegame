import SpriteKit

class TankNode: SKNode {

    static let maxHP:        CGFloat      = 400
    static let fireInterval: TimeInterval = 15.0
    static let shootRange:   CGFloat      = 340
    static let blastRadius:  CGFloat      = 90
    static let blastDamage:  CGFloat      = 60
    static let swarmRadius:  CGFloat      = 52

    // Always false so multiple zombies can target and swarm simultaneously
    var isBeingBitten = false
    private(set) var hp: CGFloat = TankNode.maxHP

    private var reloadLeft: TimeInterval = TankNode.fireInterval * 0.4
    private var hpFill:     SKShapeNode!
    private let hpBarW:     CGFloat = 60

    override init() {
        super.init()
        buildVisual()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Visual

    private func buildVisual() {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 66, height: 20))
        shadow.fillColor   = SKColor(white: 0, alpha: 0.32)
        shadow.strokeColor = .clear
        shadow.position    = CGPoint(x: 0, y: -28)
        shadow.zPosition   = -1
        addChild(shadow)

        // Left track
        let trackL = SKShapeNode(rectOf: CGSize(width: 64, height: 11), cornerRadius: 3)
        trackL.fillColor   = SKColor(red: 0.14, green: 0.14, blue: 0.10, alpha: 1)
        trackL.strokeColor = .clear
        trackL.position    = CGPoint(x: 0, y: -14)
        addChild(trackL)

        // Right track
        let trackR = SKShapeNode(rectOf: CGSize(width: 64, height: 11), cornerRadius: 3)
        trackR.fillColor   = SKColor(red: 0.14, green: 0.14, blue: 0.10, alpha: 1)
        trackR.strokeColor = .clear
        trackR.position    = CGPoint(x: 0, y: 14)
        addChild(trackR)

        // Hull
        let hull = SKShapeNode(rectOf: CGSize(width: 56, height: 26), cornerRadius: 4)
        hull.fillColor   = SKColor(red: 0.22, green: 0.30, blue: 0.12, alpha: 1)
        hull.strokeColor = SKColor(red: 0.38, green: 0.52, blue: 0.20, alpha: 1)
        hull.lineWidth   = 1.5
        hull.zPosition   = 1
        addChild(hull)

        // Turret
        let turret = SKShapeNode(circleOfRadius: 13)
        turret.fillColor   = SKColor(red: 0.18, green: 0.26, blue: 0.10, alpha: 1)
        turret.strokeColor = SKColor(red: 0.36, green: 0.50, blue: 0.18, alpha: 1)
        turret.lineWidth   = 1.5
        turret.zPosition   = 2
        addChild(turret)

        // Barrel
        let barrel = SKShapeNode(rectOf: CGSize(width: 28, height: 7), cornerRadius: 2)
        barrel.fillColor   = SKColor(red: 0.14, green: 0.20, blue: 0.08, alpha: 1)
        barrel.strokeColor = .clear
        barrel.position    = CGPoint(x: 20, y: 0)
        barrel.zPosition   = 3
        turret.addChild(barrel)

        // HP bar background
        let hpBg = SKShapeNode(rectOf: CGSize(width: hpBarW + 4, height: 9), cornerRadius: 2)
        hpBg.fillColor   = SKColor(white: 0.12, alpha: 0.90)
        hpBg.strokeColor = .clear
        hpBg.position    = CGPoint(x: 0, y: 44)
        hpBg.zPosition   = 6
        addChild(hpBg)

        let fill = SKShapeNode(rectOf: CGSize(width: hpBarW, height: 7), cornerRadius: 2)
        fill.fillColor   = SKColor(red: 0.35, green: 0.75, blue: 0.25, alpha: 1)
        fill.strokeColor = .clear
        fill.position    = CGPoint(x: 0, y: 44)
        fill.zPosition   = 7
        addChild(fill)
        hpFill = fill

        // Loading label
        let rl = SKLabelNode(fontNamed: "Menlo-Bold")
        rl.text      = "LOADING"
        rl.fontSize  = 9
        rl.fontColor = SKColor(red: 1.0, green: 0.75, blue: 0.15, alpha: 1)
        rl.horizontalAlignmentMode = .center
        rl.position  = CGPoint(x: 0, y: 56)
        rl.zPosition = 7
        rl.name      = "reloadLbl"
        rl.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.28, duration: 0.45),
            .fadeAlpha(to: 1.00, duration: 0.45)
        ])))
        addChild(rl)
    }

    // MARK: - Per-frame update

    /// Returns the blast target position if the cannon fires this frame, otherwise nil.
    func update(dt: TimeInterval, toward target: CharacterNode?) -> CGPoint? {
        reloadLeft -= dt
        if let lbl = childNode(withName: "reloadLbl") as? SKLabelNode {
            lbl.isHidden = reloadLeft <= 0
        }
        guard reloadLeft <= 0, let target else { return nil }

        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        guard sqrt(dx*dx + dy*dy) <= TankNode.shootRange else { return nil }

        reloadLeft = TankNode.fireInterval
        muzzleFlash()
        return target.position
    }

    private func muzzleFlash() {
        let flash = SKShapeNode(circleOfRadius: 20)
        flash.fillColor   = SKColor(red: 1.0, green: 0.80, blue: 0.10, alpha: 0.95)
        flash.strokeColor = .clear
        flash.position    = CGPoint(x: 34, y: 0)
        flash.zPosition   = 8
        addChild(flash)
        flash.run(.sequence([
            .scale(to: 2.6, duration: 0.07),
            .group([.fadeOut(withDuration: 0.14), .scale(to: 0.5, duration: 0.14)]),
            .removeFromParent()
        ]))
        run(.sequence([.scale(to: 1.06, duration: 0.05), .scale(to: 1.00, duration: 0.05)]))
    }

    // MARK: - Damage

    func takeDamage(_ amount: CGFloat) -> Bool {
        hp = max(0, hp - amount)
        refreshHPBar()
        return hp <= 0
    }

    private func refreshHPBar() {
        let pct = hp / TankNode.maxHP
        hpFill.xScale     = pct
        hpFill.position.x = -(hpBarW / 2) * (1 - pct)
        switch pct {
        case 0.5...: hpFill.fillColor = SKColor(red: 0.35, green: 0.75, blue: 0.25, alpha: 1)
        case 0.25...: hpFill.fillColor = SKColor(red: 1.00, green: 0.65, blue: 0.10, alpha: 1)
        default:     hpFill.fillColor = SKColor(red: 0.90, green: 0.10, blue: 0.10, alpha: 1)
        }
    }
}
