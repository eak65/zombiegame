import SpriteKit

class JoystickNode: SKNode {

    private(set) var velocity: CGVector = .zero

    private let baseRadius: CGFloat = 65
    private let thumbRadius: CGFloat = 28
    private var base: SKShapeNode!
    private var thumb: SKShapeNode!
    private var activeTouch: UITouch?

    override init() {
        super.init()

        base = SKShapeNode(circleOfRadius: baseRadius)
        base.fillColor = SKColor(white: 1, alpha: 0.10)
        base.strokeColor = SKColor(white: 1, alpha: 0.30)
        base.lineWidth = 2
        addChild(base)

        let midRing = SKShapeNode(circleOfRadius: baseRadius * 0.55)
        midRing.fillColor = .clear
        midRing.strokeColor = SKColor(white: 1, alpha: 0.15)
        midRing.lineWidth = 1
        addChild(midRing)

        thumb = SKShapeNode(circleOfRadius: thumbRadius)
        thumb.fillColor = SKColor(white: 1, alpha: 0.40)
        thumb.strokeColor = SKColor(white: 1, alpha: 0.70)
        thumb.lineWidth = 2
        addChild(thumb)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Touch forwarding (called from GameScene)

    func touchBegan(_ touch: UITouch) {
        guard activeTouch == nil else { return }
        let loc = touch.location(in: self)
        let distSq = loc.x * loc.x + loc.y * loc.y
        let hitRadiusSq = (baseRadius * 1.8) * (baseRadius * 1.8)
        if distSq < hitRadiusSq {
            activeTouch = touch
            move(to: loc)
        }
    }

    func touchMoved(_ touch: UITouch) {
        guard touch === activeTouch else { return }
        move(to: touch.location(in: self))
    }

    func touchEnded(_ touch: UITouch) {
        guard touch === activeTouch else { return }
        reset()
    }

    func reset() {
        activeTouch = nil
        thumb.position = .zero
        velocity = .zero
    }

    // MARK: - Private

    private func move(to loc: CGPoint) {
        let maxDist = baseRadius - thumbRadius
        let dist = sqrt(loc.x * loc.x + loc.y * loc.y)
        if dist <= maxDist {
            thumb.position = loc
            velocity = CGVector(dx: loc.x / maxDist, dy: loc.y / maxDist)
        } else {
            let angle = atan2(loc.y, loc.x)
            thumb.position = CGPoint(x: cos(angle) * maxDist, y: sin(angle) * maxDist)
            velocity = CGVector(dx: cos(angle), dy: sin(angle))
        }
    }
}
