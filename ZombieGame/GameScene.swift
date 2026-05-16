import SpriteKit

// MARK: - Comparable helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - GameScene

class GameScene: SKScene {

    // MARK: Constants

    private let worldSize    = CGSize(width: 2000, height: 2000)
    private let biteRadius: CGFloat = 52
    private let playerSpeed: CGFloat = 165
    private let aiSpeed:     CGFloat = 95
    private let humanCount   = 20

    // MARK: Nodes

    private var worldNode: SKNode!
    private var gameCamera: SKCameraNode!
    private var joystick: JoystickNode!
    private var player: CharacterNode!
    private var aiZombies: [CharacterNode] = []
    private var humans: [CharacterNode] = []

    // MARK: HUD

    private var humanLabel:  SKLabelNode!
    private var zombieLabel: SKLabelNode!

    // MARK: State

    private var lastTime: TimeInterval = 0
    private var gameOver = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupWorld()
        setupCamera()
        setupPlayer()
        spawnHumans()
        setupJoystick()
        setupHUD()
    }

    // MARK: - Setup

    private func setupWorld() {
        worldNode = SKNode()
        addChild(worldNode)

        // Dark green background
        let bg = SKShapeNode(rectOf: worldSize)
        bg.fillColor = SKColor(red: 0.04, green: 0.08, blue: 0.04, alpha: 1)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        worldNode.addChild(bg)

        // Grid overlay
        let gridColor = SKColor(white: 0.22, alpha: 0.18)
        for x in stride(from: 0, through: Int(worldSize.width), by: 100) {
            addGridLine(from: CGPoint(x: CGFloat(x), y: 0),
                        to: CGPoint(x: CGFloat(x), y: worldSize.height),
                        color: gridColor)
        }
        for y in stride(from: 0, through: Int(worldSize.height), by: 100) {
            addGridLine(from: CGPoint(x: 0, y: CGFloat(y)),
                        to: CGPoint(x: worldSize.width, y: CGFloat(y)),
                        color: gridColor)
        }

        // World border
        let border = SKShapeNode(rectOf: CGSize(width: worldSize.width - 4,
                                                height: worldSize.height - 4),
                                 cornerRadius: 8)
        border.fillColor = .clear
        border.strokeColor = SKColor(red: 0.35, green: 0.75, blue: 0.25, alpha: 0.45)
        border.lineWidth = 4
        border.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        worldNode.addChild(border)

        // Scattered debris dots for visual texture
        for _ in 0..<80 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            dot.fillColor = SKColor(white: 0.18, alpha: CGFloat.random(in: 0.3...0.6))
            dot.strokeColor = .clear
            dot.position = CGPoint(
                x: CGFloat.random(in: 10...(worldSize.width - 10)),
                y: CGFloat.random(in: 10...(worldSize.height - 10))
            )
            worldNode.addChild(dot)
        }
    }

    private func addGridLine(from a: CGPoint, to b: CGPoint, color: SKColor) {
        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        line.path = path
        line.strokeColor = color
        line.lineWidth = 0.5
        worldNode.addChild(line)
    }

    private func setupCamera() {
        gameCamera = SKCameraNode()
        camera = gameCamera
        addChild(gameCamera)
    }

    private func setupPlayer() {
        player = CharacterNode(type: .playerZombie)
        player.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        worldNode.addChild(player)
    }

    private func spawnHumans() {
        let margin: CGFloat = 160
        for _ in 0..<humanCount {
            let human = CharacterNode(type: .human)
            var pos: CGPoint
            repeat {
                pos = CGPoint(
                    x: CGFloat.random(in: margin...(worldSize.width  - margin)),
                    y: CGFloat.random(in: margin...(worldSize.height - margin))
                )
            } while dist(pos, player.position) < 250
            human.position = pos
            worldNode.addChild(human)
            humans.append(human)
            scheduleWander(human)
        }
    }

    private func setupJoystick() {
        joystick = JoystickNode()
        joystick.position = CGPoint(x: -size.width / 2 + 110, y: -size.height / 2 + 110)
        joystick.zPosition = 100
        gameCamera.addChild(joystick)
    }

    private func setupHUD() {
        let bar = SKShapeNode(rectOf: CGSize(width: size.width, height: 48))
        bar.fillColor = SKColor(white: 0, alpha: 0.60)
        bar.strokeColor = .clear
        bar.position = CGPoint(x: 0, y: size.height / 2 - 24)
        bar.zPosition = 100
        gameCamera.addChild(bar)

        zombieLabel = makeHUDLabel(x: -size.width / 4,
                                   color: SKColor(red: 0.35, green: 1, blue: 0.35, alpha: 1))
        humanLabel  = makeHUDLabel(x:  size.width / 4,
                                   color: SKColor(red: 0.40, green: 0.75, blue: 1.00, alpha: 1))
        refreshHUD()
    }

    private func makeHUDLabel(x: CGFloat, color: SKColor) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.fontSize = 20
        lbl.fontColor = color
        lbl.horizontalAlignmentMode = .center
        lbl.position = CGPoint(x: x, y: size.height / 2 - 40)
        lbl.zPosition = 101
        gameCamera.addChild(lbl)
        return lbl
    }

    private func refreshHUD() {
        zombieLabel.text = "🧟  \(aiZombies.count + 1)"
        humanLabel.text  = "🧑  \(humans.count)"
    }

    // MARK: - Human wandering

    private func scheduleWander(_ human: CharacterNode) {
        guard !human.isBeingBitten, human.parent != nil else { return }
        let duration = Double.random(in: 1.5...4.0)
        let angle    = CGFloat.random(in: 0 ... .pi * 2)
        let distance = CGFloat.random(in: 60...200)
        let tx = (human.position.x + cos(angle) * distance).clamped(to: 80...(worldSize.width  - 80))
        let ty = (human.position.y + sin(angle) * distance).clamped(to: 80...(worldSize.height - 80))
        let target = CGPoint(x: tx, y: ty)
        let dir    = CGVector(dx: tx - human.position.x, dy: ty - human.position.y)
        human.run(.sequence([
            .run { human.faceDirection(dir) },
            .move(to: target, duration: duration),
            .run { [weak self, weak human] in
                guard let self, let human else { return }
                self.scheduleWander(human)
            }
        ]), withKey: "wander")
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        guard !gameOver else { return }
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 1.0 / 30)
        lastTime = currentTime

        updatePlayer(dt: dt)
        updateAI(dt: dt)
        checkBites()
        clampCamera()

        if humans.isEmpty { showWin() }
    }

    private func updatePlayer(dt: TimeInterval) {
        let v = joystick.velocity
        guard v != .zero else { return }
        let step = CGFloat(dt) * playerSpeed
        player.position.x = (player.position.x + v.dx * step).clamped(to: 0...worldSize.width)
        player.position.y = (player.position.y + v.dy * step).clamped(to: 0...worldSize.height)
        player.faceDirection(v)
    }

    private func updateAI(dt: TimeInterval) {
        let step = CGFloat(dt) * aiSpeed
        for zombie in aiZombies {
            // Re-target if needed
            if zombie.targetHuman == nil
                || zombie.targetHuman?.parent == nil
                || zombie.targetHuman?.isBeingBitten == true {
                zombie.targetHuman = nearestHuman(to: zombie)
            }
            guard let target = zombie.targetHuman else { continue }
            let dx = target.position.x - zombie.position.x
            let dy = target.position.y - zombie.position.y
            let d  = sqrt(dx * dx + dy * dy)
            guard d > 1 else { continue }
            zombie.position.x += (dx / d) * step
            zombie.position.y += (dy / d) * step
            zombie.faceDirection(CGVector(dx: dx, dy: dy))
        }
    }

    private func checkBites() {
        var toConvert: [CharacterNode] = []
        for human in humans {
            guard !human.isBeingBitten else { continue }
            if dist(player.position, human.position) < biteRadius {
                toConvert.append(human)
                continue
            }
            for zombie in aiZombies where zombie.targetHuman === human {
                if dist(zombie.position, human.position) < biteRadius {
                    toConvert.append(human)
                    break
                }
            }
        }
        toConvert.forEach { startBite($0) }
    }

    private func startBite(_ human: CharacterNode) {
        human.isBeingBitten = true
        human.removeAction(forKey: "wander")
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

    private func nearestHuman(to node: SKNode) -> CharacterNode? {
        humans
            .filter { !$0.isBeingBitten }
            .min { dist(node.position, $0.position) < dist(node.position, $1.position) }
    }

    private func clampCamera() {
        let hw = size.width  / 2
        let hh = size.height / 2
        gameCamera.position.x = player.position.x.clamped(to: hw...(worldSize.width  - hw))
        gameCamera.position.y = player.position.y.clamped(to: hh...(worldSize.height - hh))
    }

    // MARK: - Win screen

    private func showWin() {
        gameOver = true
        joystick.reset()

        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor(red: 0, green: 0.25, blue: 0, alpha: 0.88)
        overlay.strokeColor = SKColor(red: 0.25, green: 1, blue: 0.25, alpha: 0.70)
        overlay.lineWidth = 3
        overlay.zPosition = 200
        gameCamera.addChild(overlay)

        let title = makeCenteredLabel("INFECTION COMPLETE", font: "Menlo-Bold", size: 34,
                                      color: .white, y: 55)
        title.zPosition = 201
        gameCamera.addChild(title)

        let sub = makeCenteredLabel("All \(aiZombies.count + 1) humans turned",
                                    font: "Menlo", size: 20,
                                    color: SKColor(red: 0.55, green: 1, blue: 0.55, alpha: 1), y: 5)
        sub.zPosition = 201
        gameCamera.addChild(sub)

        let tap = makeCenteredLabel("tap to play again", font: "Menlo", size: 16,
                                    color: SKColor(white: 0.75, alpha: 1), y: -55)
        tap.zPosition = 201
        tap.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.65),
            .fadeAlpha(to: 1.00, duration: 0.65)
        ])))
        gameCamera.addChild(tap)
    }

    private func makeCenteredLabel(_ text: String, font: String, size: CGFloat,
                                   color: SKColor, y: CGFloat) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: font)
        lbl.text = text
        lbl.fontSize = size
        lbl.fontColor = color
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

    // MARK: - Helpers

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}
