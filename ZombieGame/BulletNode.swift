import SpriteKit

class BulletNode: SKNode {

    static let speed:    CGFloat = 500
    static let maxRange: CGFloat = 360
    static let damage:   CGFloat = 25

    private let vel:      CGVector
    private var traveled: CGFloat = 0

    init(direction: CGVector, from origin: CGPoint) {
        vel = CGVector(dx: direction.dx * BulletNode.speed,
                       dy: direction.dy * BulletNode.speed)
        super.init()
        position  = origin
        zPosition = 8

        // Bullet head
        let head = SKShapeNode(circleOfRadius: 3.5)
        head.fillColor   = SKColor(red: 1.00, green: 0.95, blue: 0.55, alpha: 1)
        head.strokeColor = SKColor(red: 1.00, green: 0.70, blue: 0.10, alpha: 0.80)
        head.lineWidth   = 1
        addChild(head)

        // Short trail behind the bullet
        let trailLen: CGFloat = 14
        let trail = SKShapeNode()
        let path  = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: -direction.dx * trailLen,
                                 y: -direction.dy * trailLen))
        trail.path        = path
        trail.strokeColor = SKColor(red: 1, green: 0.80, blue: 0.25, alpha: 0.45)
        trail.lineWidth   = 2
        addChild(trail)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Per-frame advance
    // Returns true when the bullet has exceeded its max range and should be removed.

    func advance(dt: TimeInterval) -> Bool {
        let dx = vel.dx * CGFloat(dt)
        let dy = vel.dy * CGFloat(dt)
        position.x += dx
        position.y += dy
        traveled   += sqrt(dx*dx + dy*dy)
        return traveled >= BulletNode.maxRange
    }

    // MARK: - Impact effect (spawned into parent node before bullet is removed)

    func spawnImpact() {
        guard let parent else { return }
        let spark = SKShapeNode(circleOfRadius: 7)
        spark.fillColor   = SKColor(red: 1, green: 0.82, blue: 0.20, alpha: 0.90)
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
