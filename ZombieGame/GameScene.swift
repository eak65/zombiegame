import SpriteKit

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

// MARK: - GameScene

class GameScene: SKScene {

    // MARK: - Constants
    private let worldSize   = CGSize(width: 2016, height: 2016)
    private let biteRadius: CGFloat = 50
    private let playerSpeed: CGFloat = 160
    private let aiSpeed:     CGFloat = 92
    private let humanSpeed:  CGFloat = 38
    private let humanCount  = 20
    private let copCount     = 18
    private let soldierCount = 5

    // MARK: - State
    private var cityMap:    CityMap!
    private var worldNode:  SKNode!
    private var gameCamera: SKCameraNode!
    private var joystick:   JoystickNode!
    private var player:     CharacterNode!
    private var aiZombies:  [CharacterNode] = []
    private var humans:     [CharacterNode] = []
    private var cops:       [CopNode]       = []
    private var soldiers:   [SoldierNode]   = []
    private var bullets:    [BulletNode]    = []

    private var humanLabel:  SKLabelNode!
    private var zombieLabel: SKLabelNode!

    private var formationThreatDir: CGVector = .zero

    private var upgradeRage       = 0
    private var upgradeDurability = 0
    private var upgradeVirulence  = 0
    private var upgradeConversion = 0
    private var evolutionPoints   = 0

    private var evolutionPanel: EvolutionPanelNode!
    private var evoButtonNode:  SKNode!
    private var evoBadgeLabel:  SKLabelNode!

    private var effectivePlayerSpeed: CGFloat { playerSpeed * (1.0 + 0.20 * CGFloat(upgradeRage)) }
    private var effectiveAISpeed:     CGFloat { aiSpeed     * (1.0 + 0.20 * CGFloat(upgradeRage)) }
    private var conversionCeiling:    TimeInterval { [15.0, 10.0, 7.0][min(upgradeConversion, 2)] }

    private var lastTime: TimeInterval = 0
    private var gameOver  = false

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
        spawnCops()
        spawnSoldiers()
        setupJoystick()
        setupHUD()
        setupEvolutionUI()
    }

    // MARK: - Setup

    private func setupCamera() {
        gameCamera = SKCameraNode()
        camera = gameCamera
        addChild(gameCamera)
    }

    private func setupPlayer() {
        player = CharacterNode(type: .playerZombie)
        player.position  = centerStreetPoint()
        player.zPosition = 10
        worldNode.addChild(player)
    }

    private func spawnHumans() {
        var placed = 0; var attempts = 0
        while placed < humanCount && attempts < 500 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 250 else { continue }
            let h = CharacterNode(type: .human)
            h.position     = pos
            h.zPosition    = 10
            h.wanderTarget = cityMap.randomStreetPoint()
            worldNode.addChild(h)
            humans.append(h)
            placed += 1
        }
    }

    private func spawnCops() {
        if !buildFormation() { fallbackFormation() }
    }

    /// Places cops in a line behind parked cars on a horizontal street.
    /// Returns true when a suitable street was found and all cops placed.
    private func buildFormation() -> Bool {
        let worldMid: CGFloat = worldSize.height / 2

        var bestStreetY: CGFloat = -1
        var bestOuterCars: [CarData] = []

        for streetY in cityMap.streetCenterYs {
            guard abs(player.position.y - streetY) > 300 else { continue }

            let outerCars: [CarData]
            if streetY < worldMid {
                outerCars = cityMap.cars.filter { $0.isHorizontal && $0.rect.midY < streetY }
            } else {
                outerCars = cityMap.cars.filter { $0.isHorizontal && $0.rect.midY > streetY }
            }

            if outerCars.count > bestOuterCars.count {
                bestOuterCars = outerCars
                bestStreetY   = streetY
            }
        }

        guard bestStreetY >= 0, bestOuterCars.count >= 2 else { return false }

        let sorted = bestOuterCars.sorted { $0.rect.midX < $1.rect.midX }
        let start  = max(0, (sorted.count - copCount) / 2)
        let end    = min(sorted.count, start + copCount)
        let chosen = Array(sorted[start..<end])

        let coverOffset: CGFloat = bestStreetY < worldMid ? 23 : -23
        formationThreatDir = bestStreetY < worldMid
            ? CGVector(dx: 0, dy: -1)
            : CGVector(dx: 0, dy:  1)

        for car in chosen {
            let cop = CopNode()
            cop.position  = CGPoint(x: car.rect.midX, y: car.rect.midY + coverOffset)
            cop.zPosition = 10
            worldNode.addChild(cop)
            cops.append(cop)
        }
        return true
    }

    private func fallbackFormation() {
        formationThreatDir = .zero
        var placed = 0; var attempts = 0
        while placed < copCount && attempts < 300 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 300 else { continue }
            guard !cops.contains(where: { dist($0.position, pos) < 200 }) else { continue }
            let cop = CopNode()
            cop.position  = pos
            cop.zPosition = 10
            worldNode.addChild(cop)
            cops.append(cop)
            placed += 1
        }
    }

    private func spawnSoldiers() {
        var placed = 0; var attempts = 0
        while placed < soldierCount && attempts < 400 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 350 else { continue }
            guard !cops.contains(where: { dist($0.position, pos) < 150 }) else { continue }
            guard !soldiers.contains(where: { dist($0.position, pos) < 200 }) else { continue }
            let s = SoldierNode()
            s.position  = pos
            s.zPosition = 10
            worldNode.addChild(s)
            soldiers.append(s)
            placed += 1
        }
    }

    private func setupJoystick() {
        joystick          = JoystickNode()
        joystick.position = CGPoint(x: -size.width/2 + 110, y: -size.height/2 + 110)
        joystick.zPosition = 100
        gameCamera.addChild(joystick)
    }

    private func setupHUD() {
        let bar = SKShapeNode(rectOf: CGSize(width: size.width, height: 48))
        bar.fillColor  = SKColor(white: 0, alpha: 0.60)
        bar.strokeColor = .clear
        bar.position   = CGPoint(x: 0, y: size.height/2 - 24)
        bar.zPosition  = 100
        gameCamera.addChild(bar)

        zombieLabel = makeHUDLabel(x: -size.width/4,
                                   color: SKColor(red: 0.35, green: 1.00, blue: 0.35, alpha: 1))
        humanLabel  = makeHUDLabel(x:  size.width/4,
                                   color: SKColor(red: 0.40, green: 0.75, blue: 1.00, alpha: 1))
        refreshHUD()
    }

    private func makeHUDLabel(x: CGFloat, color: SKColor) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.fontSize               = 20
        lbl.fontColor              = color
        lbl.horizontalAlignmentMode = .center
        lbl.position               = CGPoint(x: x, y: size.height/2 - 40)
        lbl.zPosition              = 101
        gameCamera.addChild(lbl)
        return lbl
    }

    private func refreshHUD() {
        zombieLabel.text = "🧟  \(aiZombies.count + 1)"
        humanLabel.text  = "🧑  \(humans.count + cops.count + soldiers.count)"
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        guard !gameOver else { return }
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 1.0/30)
        lastTime = currentTime

        updatePlayer(dt: dt)
        updateHumans(dt: dt)
        updateAI(dt: dt)
        updateCops(dt: dt)
        updateSoldiers(dt: dt)
        updateBullets(dt: dt)
        checkBites()
        clampCamera()

        if humans.isEmpty && cops.isEmpty && soldiers.isEmpty { showWin() }
    }

    // MARK: - Movement

    private func updatePlayer(dt: TimeInterval) {
        let v = joystick.velocity
        guard v != .zero else { return }
        let speed = effectivePlayerSpeed * cityMap.speedMultiplier(at: player.position)
        let raw   = CGPoint(x: player.position.x + v.dx * speed * CGFloat(dt),
                            y: player.position.y + v.dy * speed * CGFloat(dt))
        player.position = cityMap.resolve(newPos: clampToWorld(raw), from: player.position)
        player.faceDirection(v)
    }

    private func updateHumans(dt: TimeInterval) {
        for human in humans {
            if let wt = human.wanderTarget, dist(human.position, wt) < 18 {
                human.wanderTarget = cityMap.randomStreetPoint()
            }
            if human.wanderTarget == nil { human.wanderTarget = cityMap.randomStreetPoint() }
            guard let target = human.wanderTarget else { continue }

            let dx = target.x - human.position.x
            let dy = target.y - human.position.y
            let d  = sqrt(dx*dx + dy*dy)
            guard d > 1 else { continue }

            let speed = humanSpeed * cityMap.speedMultiplier(at: human.position)
            let raw   = CGPoint(x: human.position.x + (dx/d) * speed * CGFloat(dt),
                                y: human.position.y + (dy/d) * speed * CGFloat(dt))
            human.position = cityMap.resolve(newPos: clampToWorld(raw), from: human.position)
            human.faceDirection(CGVector(dx: dx, dy: dy))
        }
    }

    private func updateAI(dt: TimeInterval) {
        for zombie in aiZombies {
            // Immediately escape if somehow inside a building
            if cityMap.isInBuilding(zombie.position, radius: 10) {
                zombie.stuckWaypoint = nearestStreetPoint(to: zombie.position)
                zombie.stuckTimer    = 0
            }

            // Re-target if needed (targets humans AND cops)
            if zombie.target == nil
                || zombie.target?.parent == nil
                || (zombie.target as? CharacterNode)?.isBeingBitten == true
                || (zombie.target as? CopNode)?.isBeingBitten == true
                || (zombie.target as? SoldierNode)?.isBeingBitten == true {
                zombie.target = nearestNonZombie(to: zombie)
            }

            // Decide movement goal: waypoint takes priority over normal target
            let goalPos: CGPoint
            if let wp = zombie.stuckWaypoint {
                if dist(zombie.position, wp) < 30 {
                    zombie.stuckWaypoint = nil
                    zombie.stuckTimer    = 0
                    goalPos = zombie.target.map { $0.position } ?? wp
                } else {
                    goalPos = wp
                }
            } else {
                guard let target = zombie.target else { continue }
                goalPos = target.position
            }

            let dx = goalPos.x - zombie.position.x
            let dy = goalPos.y - zombie.position.y
            let d  = sqrt(dx*dx + dy*dy)
            guard d > 1 else { continue }

            let prevPos = zombie.position
            let speed = effectiveAISpeed * cityMap.speedMultiplier(at: zombie.position)
            let raw   = CGPoint(x: zombie.position.x + (dx/d) * speed * CGFloat(dt),
                                y: zombie.position.y + (dy/d) * speed * CGFloat(dt))
            zombie.position = cityMap.resolve(newPos: clampToWorld(raw), from: zombie.position)
            zombie.faceDirection(CGVector(dx: dx, dy: dy))

            // Stuck detection: if barely moved, count up; assign escape waypoint
            let moved = dist(zombie.position, prevPos)
            if moved < 0.5 {
                zombie.stuckTimer += dt
                if zombie.stuckTimer > 1.0 && zombie.stuckWaypoint == nil {
                    zombie.stuckWaypoint = nearestStreetPoint(to: zombie.position)
                    zombie.stuckTimer    = 0
                }
            } else {
                zombie.stuckTimer = 0
            }
        }
    }

    private func nearestStreetPoint(to pos: CGPoint) -> CGPoint {
        let xs = cityMap.streetCenterXs
        let ys = cityMap.streetCenterYs
        let nx = xs.min(by: { abs($0 - pos.x) < abs($1 - pos.x) }) ?? pos.x
        let ny = ys.min(by: { abs($0 - pos.y) < abs($1 - pos.y) }) ?? pos.y
        // Add small random jitter so multiple stuck zombies don't pick identical waypoints
        let jitter: CGFloat = CGFloat.random(in: -20...20)
        return CGPoint(x: nx + jitter, y: ny + jitter)
    }

    // MARK: - Cops

    private func updateCops(dt: TimeInterval) {
        for cop in cops {
            let nearestZ = nearestZombieInRange(of: cop)
            if let dir = cop.update(dt: dt, toward: nearestZ) {
                spawnBullet(direction: dir, from: cop.position)
            } else if nearestZ == nil && formationThreatDir != .zero {
                cop.lookAt(CGPoint(x: cop.position.x + formationThreatDir.dx * 100,
                                   y: cop.position.y + formationThreatDir.dy * 100))
            }
        }
    }

    private func updateSoldiers(dt: TimeInterval) {
        for soldier in soldiers {
            let nearestZ = nearestZombieInRange(ofSoldier: soldier)
            if let dir = soldier.update(dt: dt, toward: nearestZ) {
                spawnBullet(direction: dir, from: soldier.position)
            }
        }
    }

    private func nearestZombieInRange(of cop: CopNode) -> CharacterNode? {
        let allZombies: [CharacterNode] = [player] + aiZombies
        return allZombies
            .filter { dist(cop.position, $0.position) <= CopNode.shootRange }
            .min { dist(cop.position, $0.position) < dist(cop.position, $1.position) }
    }

    private func nearestZombieInRange(ofSoldier soldier: SoldierNode) -> CharacterNode? {
        let allZombies: [CharacterNode] = [player] + aiZombies
        return allZombies
            .filter { dist(soldier.position, $0.position) <= SoldierNode.shootRange }
            .min { dist(soldier.position, $0.position) < dist(soldier.position, $1.position) }
    }

    // MARK: - Bullets

    private func spawnBullet(direction: CGVector, from origin: CGPoint) {
        let bullet = BulletNode(direction: direction, from: origin)
        worldNode.addChild(bullet)
        bullets.append(bullet)
    }

    private func updateBullets(dt: TimeInterval) {
        var toRemove: [Int] = []
        let allZombies: [CharacterNode] = [player] + aiZombies

        for (i, bullet) in bullets.enumerated() {
            let expired     = bullet.advance(dt: dt)
            let inBuilding  = cityMap.isInBuilding(bullet.position, radius: 2)

            // Check hits against all zombies
            var hit = false
            for zombie in allZombies {
                guard dist(bullet.position, zombie.position) < 22 else { continue }
                bullet.spawnImpact()
                hit = true

                if zombie.takeDamage(BulletNode.damage) {
                    // Zombie died
                    if zombie === player {
                        playerDied()
                    } else {
                        zombieDied(zombie)
                    }
                }
                break
            }

            if hit || expired || inBuilding {
                if !hit && !inBuilding { /* expired naturally, no spark needed */ }
                else if inBuilding || expired { /* silent removal */ }
                bullet.removeFromParent()
                toRemove.append(i)
            }
        }
        for i in toRemove.reversed() { bullets.remove(at: i) }
    }

    // MARK: - Bite logic

    private func checkBites() {
        var humansToConvert:   [(CharacterNode, CharacterNode)] = []
        var copsToConvert:     [CopNode]     = []
        var soldiersToConvert: [SoldierNode] = []

        let allZombies: [CharacterNode] = [player] + aiZombies

        for zombie in allZombies {
            for human in humans {
                guard !human.isBeingBitten else { continue }
                let isTargeted = (zombie === player) || (zombie.target === human)
                guard isTargeted, dist(zombie.position, human.position) < biteRadius else { continue }
                if !humansToConvert.contains(where: { $0.0 === human }) {
                    humansToConvert.append((human, zombie))
                }
            }
            for cop in cops {
                guard !cop.isBeingBitten else { continue }
                let isTargeted = (zombie === player) || (zombie.target === cop)
                guard isTargeted, dist(zombie.position, cop.position) < biteRadius else { continue }
                if !copsToConvert.contains(where: { $0 === cop }) { copsToConvert.append(cop) }
            }
            for soldier in soldiers {
                guard !soldier.isBeingBitten else { continue }
                let isTargeted = (zombie === player) || (zombie.target === soldier)
                guard isTargeted, dist(zombie.position, soldier.position) < biteRadius else { continue }
                if !soldiersToConvert.contains(where: { $0 === soldier }) { soldiersToConvert.append(soldier) }
            }
        }

        humansToConvert.forEach   { startBiteHuman($0.0, from: $0.1) }
        copsToConvert.forEach     { startBiteCop($0) }
        soldiersToConvert.forEach { startBiteSoldier($0) }
    }

    private func startBiteHuman(_ human: CharacterNode, from biter: CharacterNode) {
        human.isBeingBitten = true

        // Flee in the opposite direction from the biter
        let dx  = human.position.x - biter.position.x
        let dy  = human.position.y - biter.position.y
        let len = max(sqrt(dx*dx + dy*dy), 1)
        human.wanderTarget = CGPoint(
            x: (human.position.x + dx/len * 280).clamped(to: 20...(worldSize.width  - 20)),
            y: (human.position.y + dy/len * 280).clamped(to: 20...(worldSize.height - 20))
        )
        human.startInfectionVisual()

        let delay = TimeInterval.random(in: 3.0...conversionCeiling)
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self, weak human] in
                guard let self, let human, human.parent != nil else { return }
                self.convertHumanToZombie(human)
            }
        ]))
    }

    private func startBiteCop(_ cop: CopNode) {
        cop.isBeingBitten = true
        cop.playBiteAnimation()
        run(.sequence([
            .wait(forDuration: 0.75),
            .run { [weak self, weak cop] in
                guard let self, let cop else { return }
                self.convertCopToZombie(cop)
            }
        ]))
    }

    private func convertHumanToZombie(_ human: CharacterNode) {
        human.stopInfectionVisual()
        humans.removeAll { $0 === human }
        human.becomeZombie()
        aiZombies.append(human)
        human.target = nearestNonZombie(to: human)
        awardEvolutionPoint()
        refreshHUD()
    }

    private func convertCopToZombie(_ cop: CopNode) {
        cops.removeAll { $0 === cop }
        cop.removeFromParent()

        let zombie = CharacterNode(type: .aiZombie)
        zombie.position  = cop.position
        zombie.zPosition = 10
        worldNode.addChild(zombie)
        aiZombies.append(zombie)
        zombie.target = nearestNonZombie(to: zombie)
        awardEvolutionPoint()
        refreshHUD()
    }

    private func startBiteSoldier(_ soldier: SoldierNode) {
        soldier.isBeingBitten = true
        soldier.playBiteAnimation()
        run(.sequence([
            .wait(forDuration: 0.75),
            .run { [weak self, weak soldier] in
                guard let self, let soldier else { return }
                self.convertSoldierToZombie(soldier)
            }
        ]))
    }

    private func convertSoldierToZombie(_ soldier: SoldierNode) {
        soldiers.removeAll { $0 === soldier }
        soldier.removeFromParent()

        let zombie = CharacterNode(type: .aiZombie)
        zombie.position  = soldier.position
        zombie.zPosition = 10
        worldNode.addChild(zombie)
        aiZombies.append(zombie)
        zombie.target = nearestNonZombie(to: zombie)
        awardEvolutionPoint()
        refreshHUD()
    }

    private func awardEvolutionPoint() {
        evolutionPoints += 1
        updateEvoBadge()
        evoButtonNode.run(.sequence([
            .scale(to: 1.28, duration: 0.10),
            .scale(to: 1.00, duration: 0.12)
        ]))
    }

    // MARK: - Zombie death (shot by police)

    private func zombieDied(_ zombie: CharacterNode) {
        aiZombies.removeAll { $0 === zombie }
        // Cancel any pending targets pointing at this zombie
        for other in aiZombies where other.target === zombie { other.target = nil }

        let pop = SKEmitterNode()   // simple particle burst substitute
        spawnDeathBurst(at: zombie.position)
        zombie.removeFromParent()
        refreshHUD()
    }

    private func playerDied() {
        guard !gameOver else { return }

        // Find nearest AI zombie to possess
        guard let nearest = aiZombies.min(by: {
            dist($0.position, player.position) < dist($1.position, player.position)
        }) else {
            // No zombies left — true game over
            gameOver = true
            joystick.reset()
            showGameOver()
            return
        }

        spawnDeathBurst(at: player.position)
        player.removeFromParent()

        aiZombies.removeAll { $0 === nearest }
        nearest.becomePlayer()
        player = nearest
        refreshHUD()
        showSwitchBanner()
    }

    private func showSwitchBanner() {
        let title = centeredLabel("ZOMBIE DOWN!", font: "Menlo-Bold", size: 22,
                                  color: SKColor(red: 1, green: 0.30, blue: 0.30, alpha: 1), y: 20)
        let sub   = centeredLabel("Possessing nearest zombie…", font: "Menlo", size: 15,
                                  color: SKColor(white: 0.85, alpha: 1), y: -10)
        for lbl in [title, sub] {
            lbl.zPosition = 200
            lbl.run(.sequence([
                .wait(forDuration: 1.8),
                .fadeOut(withDuration: 0.4),
                .removeFromParent()
            ]))
            gameCamera.addChild(lbl)
        }
    }

    private func spawnDeathBurst(at pos: CGPoint) {
        for _ in 0..<8 {
            let shard = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...7))
            shard.fillColor   = SKColor(red: CGFloat.random(in: 0.2...0.5),
                                        green: CGFloat.random(in: 0.5...0.9),
                                        blue: 0.2, alpha: 0.9)
            shard.strokeColor = .clear
            shard.position    = pos
            shard.zPosition   = 12
            worldNode.addChild(shard)
            let angle = CGFloat.random(in: 0 ... .pi*2)
            let d     = CGFloat.random(in: 15...40)
            let dest = CGPoint(x: pos.x + cos(angle) * d, y: pos.y + sin(angle) * d)
            let move = SKAction.move(to: dest, duration: 0.25)
            let fade = SKAction.fadeOut(withDuration: 0.25)
            shard.run(SKAction.sequence([SKAction.group([move, fade]), .removeFromParent()]))
        }
    }

    // MARK: - Evolution UI

    private func setupEvolutionUI() {
        evolutionPanel           = EvolutionPanelNode(sceneSize: size)
        evolutionPanel.position  = .zero
        evolutionPanel.zPosition = 150
        evolutionPanel.isHidden  = true
        evolutionPanel.onBuy     = { [weak self] type in self?.buyUpgrade(type) }
        evolutionPanel.onClose   = { [weak self] in self?.toggleEvolutionPanel() }
        gameCamera.addChild(evolutionPanel)

        let btnPos = CGPoint(x: size.width/2 - 75, y: -size.height/2 + 75)
        let circle = SKShapeNode(circleOfRadius: 36)
        circle.fillColor   = SKColor(red: 0.08, green: 0.22, blue: 0.08, alpha: 0.90)
        circle.strokeColor = SKColor(red: 0.25, green: 0.80, blue: 0.25, alpha: 0.70)
        circle.lineWidth   = 2
        let icon = SKLabelNode(text: "🧬")
        icon.fontSize = 26
        icon.verticalAlignmentMode   = .center
        icon.horizontalAlignmentMode = .center
        circle.addChild(icon)
        evoButtonNode          = circle
        evoButtonNode.position = btnPos
        evoButtonNode.zPosition = 102
        gameCamera.addChild(evoButtonNode)

        let badge = SKShapeNode(circleOfRadius: 11)
        badge.fillColor = SKColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1)
        badge.strokeColor = .clear
        badge.position  = CGPoint(x: 24, y: 24)
        badge.isHidden  = true
        badge.name      = "evoBadge"
        circle.addChild(badge)
        evoBadgeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        evoBadgeLabel.fontSize = 10
        evoBadgeLabel.fontColor = .white
        evoBadgeLabel.verticalAlignmentMode   = .center
        evoBadgeLabel.horizontalAlignmentMode = .center
        badge.addChild(evoBadgeLabel)
    }

    private func toggleEvolutionPanel() {
        evolutionPanel.isHidden.toggle()
        if !evolutionPanel.isHidden {
            evolutionPanel.refresh(points: evolutionPoints, levels: upgradeLevels())
            joystick.reset()
        }
    }

    private func upgradeLevels() -> [UpgradeType: Int] {
        [.rage: upgradeRage, .durability: upgradeDurability,
         .virulence: upgradeVirulence, .conversion: upgradeConversion]
    }

    private func buyUpgrade(_ type: UpgradeType) {
        guard let def = EvolutionPanelNode.defs.first(where: { $0.type == type }) else { return }
        let currentLevel: Int
        switch type {
        case .rage:       currentLevel = upgradeRage
        case .durability: currentLevel = upgradeDurability
        case .virulence:  currentLevel = upgradeVirulence
        case .conversion: currentLevel = upgradeConversion
        }
        guard currentLevel < def.costs.count else { return }
        let cost = def.costs[currentLevel]
        guard evolutionPoints >= cost else { return }

        evolutionPoints -= cost
        switch type {
        case .rage:
            upgradeRage += 1
        case .durability:
            upgradeDurability += 1
            CharacterNode.maxHP += 25
            player.heal(25)
            for z in aiZombies { z.heal(25) }
        case .virulence:
            upgradeVirulence += 1
        case .conversion:
            upgradeConversion += 1
        }
        updateEvoBadge()
        evolutionPanel.refresh(points: evolutionPoints, levels: upgradeLevels())
    }

    private func updateEvoBadge() {
        let badge = evoButtonNode.childNode(withName: "evoBadge")
        badge?.isHidden    = evolutionPoints == 0
        evoBadgeLabel.text = "\(evolutionPoints)"
    }

    // MARK: - Screens

    private func showWin() {
        gameOver = true
        joystick.reset()
        showEndScreen(title: "INFECTION COMPLETE",
                      sub: "All \(aiZombies.count + 1) zombies on the streets",
                      titleColor: .white,
                      bgColor: SKColor(red: 0, green: 0.22, blue: 0, alpha: 0.88),
                      borderColor: SKColor(red: 0.25, green: 1, blue: 0.25, alpha: 0.70))
    }

    private func showGameOver() {
        showEndScreen(title: "YOU WERE SHOT",
                      sub: "The police took you down",
                      titleColor: SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 1),
                      bgColor: SKColor(red: 0.20, green: 0, blue: 0, alpha: 0.88),
                      borderColor: SKColor(red: 1, green: 0.25, blue: 0.25, alpha: 0.70))
    }

    private func showEndScreen(title: String, sub: String,
                               titleColor: SKColor, bgColor: SKColor, borderColor: SKColor) {
        let overlay      = SKShapeNode(rectOf: size)
        overlay.fillColor   = bgColor
        overlay.strokeColor = borderColor
        overlay.lineWidth   = 3
        overlay.zPosition   = 200
        gameCamera.addChild(overlay)

        let t = centeredLabel(title, font: "Menlo-Bold", size: 34, color: titleColor, y: 55)
        t.zPosition = 201; gameCamera.addChild(t)

        let s = centeredLabel(sub, font: "Menlo", size: 20,
                              color: SKColor(white: 0.80, alpha: 1), y: 5)
        s.zPosition = 201; gameCamera.addChild(s)

        let tap = centeredLabel("tap to play again", font: "Menlo", size: 16,
                                color: SKColor(white: 0.70, alpha: 1), y: -55)
        tap.zPosition = 201
        tap.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.65),
            .fadeAlpha(to: 1.00, duration: 0.65)
        ])))
        gameCamera.addChild(tap)
    }

    // MARK: - Helpers

    private func nearestNonZombie(to node: SKNode) -> SKNode? {
        var best: SKNode? = nil
        var bestDist = CGFloat.infinity
        for h in humans where !h.isBeingBitten {
            let d = dist(node.position, h.position)
            if d < bestDist { bestDist = d; best = h }
        }
        for c in cops where !c.isBeingBitten {
            let d = dist(node.position, c.position)
            if d < bestDist { bestDist = d; best = c }
        }
        for s in soldiers where !s.isBeingBitten {
            let d = dist(node.position, s.position)
            if d < bestDist { bestDist = d; best = s }
        }
        return best
    }

    private func clampCamera() {
        let hw = size.width/2, hh = size.height/2
        gameCamera.position.x = player.position.x.clamped(to: hw...(worldSize.width  - hw))
        gameCamera.position.y = player.position.y.clamped(to: hh...(worldSize.height - hh))
    }

    private func clampToWorld(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x.clamped(to: 10...(worldSize.width  - 10)),
                y: p.y.clamped(to: 10...(worldSize.height - 10)))
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y))
    }

    private func centerStreetPoint() -> CGPoint {
        let xs = cityMap.streetCenterXs
        let ys = cityMap.streetCenterYs
        let mx = xs.min(by: { abs($0 - worldSize.width/2)  < abs($1 - worldSize.width/2)  })!
        let my = ys.min(by: { abs($0 - worldSize.height/2) < abs($1 - worldSize.height/2) })!
        return CGPoint(x: mx, y: my)
    }

    private func centeredLabel(_ text: String, font: String, size: CGFloat,
                               color: SKColor, y: CGFloat) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: font)
        lbl.text = text; lbl.fontSize = size; lbl.fontColor = color
        lbl.horizontalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: y)
        return lbl
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameOver { restart(); return }
        for touch in touches {
            let camPt = touch.location(in: gameCamera)
            if !evolutionPanel.isHidden {
                evolutionPanel.handleTouch(at: camPt)
            } else if dist(camPt, evoButtonNode.position) < 52 {
                toggleEvolutionPanel()
            } else {
                joystick.touchBegan(touch)
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard evolutionPanel.isHidden else { return }
        touches.forEach { joystick.touchMoved($0) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard evolutionPanel.isHidden else { return }
        touches.forEach { joystick.touchEnded($0) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard evolutionPanel.isHidden else { return }
        touches.forEach { joystick.touchEnded($0) }
    }

    private func restart() {
        let scene = GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .fade(withDuration: 0.5))
    }
}
