import SpriteKit

class BulletNode: SKNode {

    static let speed:    CGFloat = 500
    static let maxRange: CGFloat = 360

    let damage: CGFloat   // 0 for cure needles
    let isCure: Bool

    private let vel:      CGVector
    private var traveled: CGFloat = 0

    init(direction: CGVector, from origin: CGPoint, damage: CGFloat = 35, isCure: Bool = false) {
        self.damage = damage
        self.isCure = isCure
        vel = CGVector(dx: direction.dx * BulletNode.speed,
                       dy: direction.dy * BulletNode.speed)
        super.init()
        position  = origin
        zPosition = 8

        if isCure {
            // Cure needle — thin cyan capsule
            let head = SKShapeNode(rectOf: CGSize(width: 8, height: 3.5), cornerRadius: 1.8)
            head.fillColor   = SKColor(red: 0.15, green: 0.95, blue: 0.95, alpha: 1)
            head.strokeColor = .clear
            addChild(head)

            let trail = SKShapeNode()
            let path  = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: -direction.dx * 12, y: -direction.dy * 12))
            trail.path        = path
            trail.strokeColor = SKColor(red: 0.20, green: 0.85, blue: 0.85, alpha: 0.40)
            trail.lineWidth   = 1.5
            addChild(trail)
        } else {
            // Regular bullet — yellow/gold
            let head = SKShapeNode(circleOfRadius: 3.5)
            head.fillColor   = SKColor(red: 1.00, green: 0.95, blue: 0.55, alpha: 1)
            head.strokeColor = SKColor(red: 1.00, green: 0.70, blue: 0.10, alpha: 0.80)
            head.lineWidth   = 1
            addChild(head)

            let trail = SKShapeNode()
            let path  = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: -direction.dx * 14, y: -direction.dy * 14))
            trail.path        = path
            trail.strokeColor = SKColor(red: 1, green: 0.80, blue: 0.25, alpha: 0.45)
            trail.lineWidth   = 2
            addChild(trail)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Per-frame advance
    // Returns true when the bullet has exceeded its max range.

    func advance(dt: TimeInterval) -> Bool {
        let dx = vel.dx * CGFloat(dt)
        let dy = vel.dy * CGFloat(dt)
        position.x += dx
        position.y += dy
        traveled   += sqrt(dx*dx + dy*dy)
        return traveled >= BulletNode.maxRange
    }

    // MARK: - Impact effect

    func spawnImpact() {
        guard let parent else { return }
        let color = isCure
            ? SKColor(red: 0.20, green: 0.95, blue: 0.95, alpha: 0.90)
            : SKColor(red: 1.00, green: 0.82, blue: 0.20, alpha: 0.90)
        let spark = SKShapeNode(circleOfRadius: isCure ? 5 : 7)
        spark.fillColor   = color
        spark.strokeColor = .clear
        spark.position    = position
        spark.zPosition   = 9
        parent.addChild(spark)
        spark.run(.sequence([
            .scale(to: 2.0, duration: 0.06),
            .fadeOut(withDuration: 0.10),
            .removeFromParent()
        ]))
    }
}
