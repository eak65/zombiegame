import SpriteKit

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - GameScene

class GameScene: SKScene {

    // MARK: - Constants
    private let worldSize    = CGSize(width: 2016, height: 2016) // 7 × cellW (288)
    private let biteRadius:   CGFloat = 50
    private let playerSpeed:  CGFloat = 160
    private let aiSpeed:      CGFloat = 92   // zombie base speed (further slowed by cars)
    private let humanSpeed:   CGFloat = 38
    private let humanCount            = 20

    // MARK: - State
    private var cityMap:   CityMap!
    private var worldNode: SKNode!
    private var gameCamera: SKCameraNode!
    private var joystick:  JoystickNode!
    private var player:    CharacterNode!
    private var aiZombies: [CharacterNode] = []
    private var humans:    [CharacterNode] = []

    // HUD
    private var humanLabel:  SKLabelNode!
    private var zombieLabel: SKLabelNode!

    private var lastTime: TimeInterval = 0
    private var gameOver = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        cityMap   = CityMap(worldSize: worldSize)
        worldNode = SKNode()
        addChild(worldNode)

        cityMap.buildScene(into: worldNode)
        setupCamera()
        setupPlayer()
        spawnHumans()
        setupJoystick()
        setupHUD()
    }

    // MARK: - Setup

    private func setupCamera() {
        gameCamera = SKCameraNode()
        camera = gameCamera
        addChild(gameCamera)
    }

    private func setupPlayer() {
        player = CharacterNode(type: .playerZombie)
        player.position = centerStreetPoint()
        player.zPosition = 10
        worldNode.addChild(player)
    }

    private func spawnHumans() {
        var placed = 0
        var attempts = 0
        while placed < humanCount && attempts < 500 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 250 else { continue }
            let human = CharacterNode(type: .human)
            human.position = pos
            human.zPosition = 10
            human.wanderTarget = cityMap.randomStreetPoint()
            worldNode.addChild(human)
            humans.append(human)
            placed += 1
        }
    }

    private func setupJoystick() {
        joystick = JoystickNode()
        joystick.position = CGPoint(x: -size.width/2 + 110, y: -size.height/2 + 110)
        joystick.zPosition = 100
        gameCamera.addChild(joystick)
    }

    private func setupHUD() {
        let bar = SKShapeNode(rectOf: CGSize(width: size.width, height: 48))
        bar.fillColor = SKColor(white: 0, alpha: 0.60)
        bar.strokeColor = .clear
        bar.position = CGPoint(x: 0, y: size.height/2 - 24)
        bar.zPosition = 100
        gameCamera.addChild(bar)

        zombieLabel = makeHUDLabel(x: -size.width/4,
                                   color: SKColor(red: 0.35, green: 1.00, blue: 0.35, alpha: 1))
        humanLabel  = makeHUDLabel(x:  size.width/4,
                                   color: SKColor(red: 0.40, green: 0.75, blue: 1.00, alpha: 1))
        refreshHUD()
    }

    private func makeHUDLabel(x: CGFloat, color: SKColor) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.fontSize = 20
        lbl.fontColor = color
        lbl.horizontalAlignmentMode = .center
        lbl.position = CGPoint(x: x, y: size.height/2 - 40)
        lbl.zPosition = 101
        gameCamera.addChild(lbl)
        return lbl
    }

    private func refreshHUD() {
        zombieLabel.text = "🧟  \(aiZombies.count + 1)"
        humanLabel.text  = "🧑  \(humans.count)"
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        guard !gameOver else { return }
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 1.0/30)
        lastTime = currentTime

        updatePlayer(dt: dt)
        updateHumans(dt: dt)
        updateAI(dt: dt)
        checkBites()
        clampCamera()

        if humans.isEmpty { showWin() }
    }

    // MARK: - Movement

    private func updatePlayer(dt: TimeInterval) {
        let v = joystick.velocity
        guard v != .zero else { return }
        let speed = playerSpeed * cityMap.speedMultiplier(at: player.position)
        let raw   = CGPoint(x: player.position.x + v.dx * speed * CGFloat(dt),
                            y: player.position.y + v.dy * speed * CGFloat(dt))
        let clamped = clamp(raw)
        player.position = cityMap.resolve(newPos: clamped, from: player.position)
        player.faceDirection(v)
    }

    private func updateHumans(dt: TimeInterval) {
        for human in humans {
            guard !human.isBeingBitten else { continue }

            // Pick new wander target when close enough
            if let wt = human.wanderTarget, dist(human.position, wt) < 18 {
                human.wanderTarget = cityMap.randomStreetPoint()
            }
            if human.wanderTarget == nil {
                human.wanderTarget = cityMap.randomStreetPoint()
            }
            guard let target = human.wanderTarget else { continue }

            let dx = target.x - human.position.x
            let dy = target.y - human.position.y
            let d  = sqrt(dx*dx + dy*dy)
            guard d > 1 else { continue }

            let speed = humanSpeed * cityMap.speedMultiplier(at: human.position)
            let step  = speed * CGFloat(dt)
            let raw   = CGPoint(x: human.position.x + (dx/d)*step,
                                y: human.position.y + (dy/d)*step)
            human.position = cityMap.resolve(newPos: clamp(raw), from: human.position)
            human.faceDirection(CGVector(dx: dx, dy: dy))
        }
    }

    private func updateAI(dt: TimeInterval) {
        for zombie in aiZombies {
            // Each zombie independently targets its nearest human
            if zombie.targetHuman == nil
                || zombie.targetHuman?.parent == nil
                || zombie.targetHuman?.isBeingBitten == true {
                zombie.targetHuman = nearestHuman(to: zombie)
            }
            guard let target = zombie.targetHuman else { continue }

            let dx = target.position.x - zombie.position.x
            let dy = target.position.y - zombie.position.y
            let d  = sqrt(dx*dx + dy*dy)
            guard d > 1 else { continue }

            // Zombies take the straight-line (shortest) path; car slowdown still applies
            let speed = aiSpeed * cityMap.speedMultiplier(at: zombie.position)
            let step  = speed * CGFloat(dt)
            let raw   = CGPoint(x: zombie.position.x + (dx/d)*step,
                                y: zombie.position.y + (dy/d)*step)
            zombie.position = cityMap.resolve(newPos: clamp(raw), from: zombie.position)
            zombie.faceDirection(CGVector(dx: dx, dy: dy))
        }
    }

    // MARK: - Bite logic

    private func checkBites() {
        var toConvert: [CharacterNode] = []
        for human in humans {
            guard !human.isBeingBitten else { continue }
            if dist(player.position, human.position) < biteRadius {
                toConvert.append(human); continue
            }
            for zombie in aiZombies where zombie.targetHuman === human {
                if dist(zombie.position, human.position) < biteRadius {
                    toConvert.append(human); break
                }
            }
        }
        toConvert.forEach { startBite($0) }
    }

    private func startBite(_ human: CharacterNode) {
        human.isBeingBitten  = true
        human.wanderTarget   = nil
        human.playBiteAnimation()
        run(.sequence([
            .wait(forDuration: 0.75),
            .run { [weak self, weak human] in
                guard let self, let human else { return }
                self.convertToZombie(human)
            }
        ]))
    }

    private func convertToZombie(_ human: CharacterNode) {
        humans.removeAll { $0 === human }
        human.becomeZombie()
        aiZombies.append(human)
        human.targetHuman = nearestHuman(to: human)
        refreshHUD()
    }

    // MARK: - Helpers

    private func nearestHuman(to node: SKNode) -> CharacterNode? {
        humans
            .filter { !$0.isBeingBitten }
            .min { dist(node.position, $0.position) < dist(node.position, $1.position) }
    }

    private func clampCamera() {
        let hw = size.width/2, hh = size.height/2
        gameCamera.position.x = player.position.x.clamped(to: hw...(worldSize.width  - hw))
        gameCamera.position.y = player.position.y.clamped(to: hh...(worldSize.height - hh))
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x.clamped(to: 10...(worldSize.width  - 10)),
                y: p.y.clamped(to: 10...(worldSize.height - 10)))
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y))
    }

    /// Returns a street-centre point near the world centre to spawn the player.
    private func centerStreetPoint() -> CGPoint {
        let xs = cityMap.streetCenterXs
        let ys = cityMap.streetCenterYs
        let mx = xs.min(by: { abs($0 - worldSize.width/2)  < abs($1 - worldSize.width/2)  })!
        let my = ys.min(by: { abs($0 - worldSize.height/2) < abs($1 - worldSize.height/2) })!
        return CGPoint(x: mx, y: my)
    }

    // MARK: - Win screen

    private func showWin() {
        gameOver = true
        joystick.reset()

        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor(red: 0, green: 0.22, blue: 0, alpha: 0.88)
        overlay.strokeColor = SKColor(red: 0.25, green: 1, blue: 0.25, alpha: 0.70)
        overlay.lineWidth = 3
        overlay.zPosition = 200
        gameCamera.addChild(overlay)

        let title = centeredLabel("INFECTION COMPLETE", font: "Menlo-Bold",
                                  size: 34, color: .white, y: 55)
        title.zPosition = 201
        gameCamera.addChild(title)

        let sub = centeredLabel("All \(aiZombies.count + 1) humans turned",
                                font: "Menlo", size: 20,
                                color: SKColor(red: 0.55, green: 1, blue: 0.55, alpha: 1), y: 5)
        sub.zPosition = 201
        gameCamera.addChild(sub)

        let tap = centeredLabel("tap to play again", font: "Menlo", size: 16,
                                color: SKColor(white: 0.75, alpha: 1), y: -55)
        tap.zPosition = 201
        tap.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.65),
            .fadeAlpha(to: 1.00, duration: 0.65)
        ])))
        gameCamera.addChild(tap)
    }

    private func centeredLabel(_ text: String, font: String, size: CGFloat,
                               color: SKColor, y: CGFloat) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: font)
        lbl.text = text; lbl.fontSize = size; lbl.fontColor = color
        lbl.horizontalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: y)
        return lbl
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameOver { restart(); return }
        touches.forEach { joystick.touchBegan($0) }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { joystick.touchMoved($0) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { joystick.touchEnded($0) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { joystick.touchEnded($0) }
    }

    private func restart() {
        let scene = GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .fade(withDuration: 0.5))
    }
}
