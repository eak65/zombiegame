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
    private let tankCount       = 2
    private let scientistCount  = 1

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
    private var tanks:       [TankNode]       = []
    private var scientists:  [ScientistNode]  = []
    private var bullets:     [BulletNode]     = []

    private var unlockedZombieTypes:  Set<ZombieType> = [.standard]
    private var activeConversionType: ZombieType      = .standard
    private var strainSelectorNode:   SKNode!
    private var strainSelectorLabel:  SKLabelNode!

    private var humanLabel:  SKLabelNode!
    private var zombieLabel: SKLabelNode!
    private var levelLabel:  SKLabelNode!

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

    private var lastTime:     TimeInterval = 0
    private var gameOver      = false
    private var currentLevel  = 1
    private var levelingUp    = false

    // Escort groups
    private var escortGroups: [EscortGroup] = []

    // Tutorial
    private var isTutorial        = false
    private var tutorialStep      = TutorialStep.move
    private var tutorialNode:     TutorialNode?
    private var tutorialStartPos: CGPoint = .zero

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        cityMap   = CityMap(worldSize: worldSize)
        worldNode = SKNode()
        addChild(worldNode)

        cityMap.buildScene(into: worldNode)
        setupCamera()
        setupPlayer()
        setupJoystick()
        setupHUD()
        setupEvolutionUI()
        setupStrainSelector()

        let tutorialDone = UserDefaults.standard.bool(forKey: "tutorialCompleted")
        if tutorialDone {
            spawnHumans()
            spawnCops()
            spawnSoldiers()
            spawnScientists(count: scientistCount)
            // Tanks unlock at level 3
        } else {
            isTutorial = true
            startTutorial()
        }
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
        if !buildFormationWithCount(copCount) { fallbackFormationWithCount(copCount) }
    }

    /// Places cops in a line behind parked cars on a horizontal street.
    /// Returns true when a suitable street was found and cops placed.
    @discardableResult
    private func buildFormationWithCount(_ count: Int) -> Bool {
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
        let start  = max(0, (sorted.count - count) / 2)
        let end    = min(sorted.count, start + count)
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
        // Scatter any overflow cops that didn't fit behind cars
        let overflow = count - chosen.count
        if overflow > 0 { fallbackFormationWithCount(overflow) }
        return true
    }

    private func fallbackFormationWithCount(_ count: Int) {
        formationThreatDir = .zero
        var placed = 0; var attempts = 0
        while placed < count && attempts < 400 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 300 else { continue }
            guard !cops.contains(where: { dist($0.position, pos) < 120 }) else { continue }
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
        while placed < soldierCount && attempts < 600 {
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
        levelLabel  = makeHUDLabel(x: 0, color: SKColor(red: 1.00, green: 0.85, blue: 0.30, alpha: 1))
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
        let enemies = humans.count + cops.count + soldiers.count + tanks.count + scientists.count
        humanLabel.text  = "🧑  \(enemies)"
        levelLabel.text  = "LVL \(currentLevel)"
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        guard !gameOver else { return }
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 1.0/30)
        lastTime = currentTime

        updatePlayer(dt: dt)
        updateEscortGroups(dt: dt)
        updateHumans(dt: dt)
        updateAI(dt: dt)
        updateCops(dt: dt)
        updateSoldiers(dt: dt)
        updateTanks(dt: dt)
        updateScientists(dt: dt)
        updateBullets(dt: dt)
        checkBites()
        clampCamera()

        if !isTutorial && humans.isEmpty && cops.isEmpty && soldiers.isEmpty && tanks.isEmpty && scientists.isEmpty && !levelingUp { advanceLevel() }
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

        // Tutorial: detect first real movement
        if isTutorial, tutorialStep == .move,
           dist(player.position, tutorialStartPos) > 60 {
            showTutorialStep(.bite)
        }
    }

    private func updateHumans(dt: TimeInterval) {
        for human in humans {
            guard !human.isEscorted else { continue }   // escort group manages these
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
            let typeMult = ZombieTypeData.info(for: zombie.zombieType).speedMult
            let speed = effectiveAISpeed * typeMult * cityMap.speedMultiplier(at: zombie.position)
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

    /// Returns `pos` if it is clear of buildings; otherwise the nearest street intersection.
    /// Uses a 16-pt safety margin to keep newly spawned zombies away from building edges.
    private func safeZombiePosition(near pos: CGPoint) -> CGPoint {
        guard cityMap.isInBuilding(pos, radius: 16) else { return pos }
        let xs = cityMap.streetCenterXs
        let ys = cityMap.streetCenterYs
        // Find the closest intersection that is itself clear
        var best: CGPoint = CGPoint(x: xs[0], y: ys[0])
        var bestDist = CGFloat.greatestFiniteMagnitude
        for x in xs {
            for y in ys {
                let candidate = CGPoint(x: x, y: y)
                if cityMap.isInBuilding(candidate, radius: 16) { continue }
                let d = dist(pos, candidate)
                if d < bestDist { bestDist = d; best = candidate }
            }
        }
        return best
    }

    // MARK: - Cops

    private func updateCops(dt: TimeInterval) {
        for cop in cops {
            let nearestZ = nearestZombieInRange(of: cop)
            let visibleZ = nearestZ.flatMap { z in
                cityMap.hasLineOfSight(from: cop.position, to: z.position) ? z : nil
            }
            if let dir = cop.update(dt: dt, toward: visibleZ) {
                spawnBullet(direction: dir, from: cop.position, damage: 35)
            } else if nearestZ == nil && formationThreatDir != .zero {
                cop.lookAt(CGPoint(x: cop.position.x + formationThreatDir.dx * 100,
                                   y: cop.position.y + formationThreatDir.dy * 100))
            }
        }
    }

    private func updateSoldiers(dt: TimeInterval) {
        for soldier in soldiers {
            let nearestZ = nearestZombieInRange(ofSoldier: soldier)
            let visibleZ = nearestZ.flatMap { z in
                cityMap.hasLineOfSight(from: soldier.position, to: z.position) ? z : nil
            }
            if let dir = soldier.update(dt: dt, toward: visibleZ) {
                spawnBullet(direction: dir, from: soldier.position, damage: 45)
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

    private func spawnBullet(direction: CGVector, from origin: CGPoint,
                             damage: CGFloat = 35, isCure: Bool = false) {
        let bullet = BulletNode(direction: direction, from: origin, damage: damage, isCure: isCure)
        worldNode.addChild(bullet)
        bullets.append(bullet)
    }

    private func updateBullets(dt: TimeInterval) {
        var toRemove: [Int] = []
        let allZombies: [CharacterNode] = [player] + aiZombies

        for (i, bullet) in bullets.enumerated() {
            let expired    = bullet.advance(dt: dt)
            let inBuilding = cityMap.isInBuilding(bullet.position, radius: 2)

            var hit = false
            for zombie in allZombies {
                guard dist(bullet.position, zombie.position) < 22 else { continue }
                bullet.spawnImpact()
                hit = true

                if bullet.isCure {
                    // Cure needle — convert back to human if enough hits
                    if zombie.takeCureHit() {
                        if zombie === player {
                            playerCured()
                        } else {
                            convertZombieToHuman(zombie)
                        }
                    }
                } else {
                    if zombie.takeDamage(bullet.damage) {
                        if zombie === player { playerDied() } else { zombieDied(zombie) }
                    }
                }
                break
            }

            if hit || expired || inBuilding {
                bullet.removeFromParent()
                toRemove.append(i)
            }
        }
        for i in toRemove.reversed() { bullets.remove(at: i) }
    }

    // MARK: - Bite logic

    private func checkBites() {
        var humansToConvert:     [(CharacterNode, CharacterNode)] = []
        var copsToConvert:       [CopNode]       = []
        var soldiersToConvert:   [SoldierNode]   = []
        var scientistsToConvert: [ScientistNode] = []

        let allZombies: [CharacterNode] = [player] + aiZombies

        for zombie in allZombies {
            let br = biteRadius + ZombieTypeData.info(for: zombie.zombieType).biteRadiusBonus
            for human in humans {
                guard !human.isBeingBitten else { continue }
                let isTargeted = (zombie === player) || (zombie.target === human)
                guard isTargeted, dist(zombie.position, human.position) < br else { continue }
                if !humansToConvert.contains(where: { $0.0 === human }) {
                    humansToConvert.append((human, zombie))
                }
            }
            for cop in cops {
                guard !cop.isBeingBitten else { continue }
                let isTargeted = (zombie === player) || (zombie.target === cop)
                guard isTargeted, dist(zombie.position, cop.position) < br else { continue }
                if !copsToConvert.contains(where: { $0 === cop }) { copsToConvert.append(cop) }
            }
            for soldier in soldiers {
                guard !soldier.isBeingBitten else { continue }
                let isTargeted = (zombie === player) || (zombie.target === soldier)
                guard isTargeted, dist(zombie.position, soldier.position) < br else { continue }
                if !soldiersToConvert.contains(where: { $0 === soldier }) { soldiersToConvert.append(soldier) }
            }
            for scientist in scientists {
                guard !scientist.isBeingBitten else { continue }
                let isTargeted = (zombie === player) || (zombie.target === scientist)
                guard isTargeted, dist(zombie.position, scientist.position) < br else { continue }
                if !scientistsToConvert.contains(where: { $0 === scientist }) { scientistsToConvert.append(scientist) }
            }
        }

        humansToConvert.forEach     { startBiteHuman($0.0, from: $0.1) }
        copsToConvert.forEach       { startBiteCop($0) }
        soldiersToConvert.forEach   { startBiteSoldier($0) }
        scientistsToConvert.forEach { startBiteScientist($0) }
    }

    private func startBiteScientist(_ scientist: ScientistNode) {
        scientist.isBeingBitten = true
        scientist.playBiteAnimation()
        run(.sequence([
            .wait(forDuration: 0.75),
            .run { [weak self, weak scientist] in
                guard let self, let scientist else { return }
                self.convertScientistToZombie(scientist)
            }
        ]))
    }

    private func convertScientistToZombie(_ scientist: ScientistNode) {
        scientists.removeAll { $0 === scientist }
        scientist.removeFromParent()
        let zombie = CharacterNode(type: .aiZombie)
        zombie.position  = safeZombiePosition(near: scientist.position)
        zombie.zPosition = 10
        worldNode.addChild(zombie)
        aiZombies.append(zombie)
        zombie.target = nearestNonZombie(to: zombie)
        awardEvolutionPoint()
        refreshHUD()
    }

    private func startBiteHuman(_ human: CharacterNode, from biter: CharacterNode) {
        human.isBeingBitten    = true
        human.pendingZombieType = (biter === player) ? activeConversionType : .standard

        // Tutorial: first bite starts the "watch for conversion" phase
        if isTutorial, tutorialStep == .bite {
            tutorialNode?.showStep(.bite,
                                   title: "Infected! 🦠 Conversion in progress…",
                                   body:  "The civilian will turn into a zombie shortly")
        }

        let dx  = human.position.x - biter.position.x
        let dy  = human.position.y - biter.position.y
        let len = max(sqrt(dx*dx + dy*dy), 1)
        human.wanderTarget = CGPoint(
            x: (human.position.x + dx/len * 280).clamped(to: 20...(worldSize.width  - 20)),
            y: (human.position.y + dy/len * 280).clamped(to: 20...(worldSize.height - 20))
        )
        human.startInfectionVisual()

        let infMult = ZombieTypeData.info(for: human.pendingZombieType).infectionMult
        let floor   = max(0.5, 3.0 * infMult)
        let ceiling = max(floor + 0.1, conversionCeiling * infMult)
        let delay   = TimeInterval.random(in: floor...ceiling)
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
        human.position = safeZombiePosition(near: human.position)
        human.becomeZombie(type: human.pendingZombieType)
        aiZombies.append(human)
        human.target = nearestNonZombie(to: human)
        awardEvolutionPoint()
        refreshHUD()

        // Tutorial: first conversion → show EP earned step
        if isTutorial, tutorialStep == .bite {
            showTutorialStep(.evoPoint)
        }
    }

    private func convertCopToZombie(_ cop: CopNode) {
        cops.removeAll { $0 === cop }
        cop.removeFromParent()

        let zombie = CharacterNode(type: .aiZombie)
        zombie.position  = safeZombiePosition(near: cop.position)
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
        zombie.position  = safeZombiePosition(near: soldier.position)
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
        if !evolutionPanel.isHidden {
            evolutionPanel.refresh(points: evolutionPoints, levels: upgradeLevels())
        }
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
            // Tutorial: advance when panel first opened
            if isTutorial, tutorialStep == .openPanel {
                showTutorialStep(.buyUpgrade)
            }
        }
    }

    private func upgradeLevels() -> [UpgradeType: Int] {
        [.rage: upgradeRage, .durability: upgradeDurability,
         .virulence: upgradeVirulence, .conversion: upgradeConversion,
         .unlockHunter:   unlockedZombieTypes.contains(.hunter)   ? 1 : 0,
         .unlockBrute:    unlockedZombieTypes.contains(.brute)    ? 1 : 0,
         .unlockScreamer: unlockedZombieTypes.contains(.screamer) ? 1 : 0,
         .unlockStalker:  unlockedZombieTypes.contains(.stalker)  ? 1 : 0,
         .unlockSpitter:  unlockedZombieTypes.contains(.spitter)  ? 1 : 0]
    }

    private func buyUpgrade(_ type: UpgradeType) {
        guard let def = EvolutionPanelNode.defs.first(where: { $0.type == type }) else { return }
        let currentLevel: Int
        switch type {
        case .rage:           currentLevel = upgradeRage
        case .durability:     currentLevel = upgradeDurability
        case .virulence:      currentLevel = upgradeVirulence
        case .conversion:     currentLevel = upgradeConversion
        case .unlockHunter:   currentLevel = unlockedZombieTypes.contains(.hunter)   ? 1 : 0
        case .unlockBrute:    currentLevel = unlockedZombieTypes.contains(.brute)    ? 1 : 0
        case .unlockScreamer: currentLevel = unlockedZombieTypes.contains(.screamer) ? 1 : 0
        case .unlockStalker:  currentLevel = unlockedZombieTypes.contains(.stalker)  ? 1 : 0
        case .unlockSpitter:  currentLevel = unlockedZombieTypes.contains(.spitter)  ? 1 : 0
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
            // Recompute each zombie's instanceMaxHP so HP scales with their type
            let allZ: [CharacterNode] = [player] + aiZombies
            for z in allZ {
                let newMax = CharacterNode.maxHP * ZombieTypeData.info(for: z.zombieType).hpMult
                let bonus  = newMax - z.instanceMaxHP
                z.setInstanceMaxHP(newMax)
                z.heal(bonus)
            }
        case .virulence:
            upgradeVirulence += 1
        case .conversion:
            upgradeConversion += 1
        case .unlockHunter:
            unlockedZombieTypes.insert(.hunter);   updateStrainSelector()
        case .unlockBrute:
            unlockedZombieTypes.insert(.brute);    updateStrainSelector()
        case .unlockScreamer:
            unlockedZombieTypes.insert(.screamer); updateStrainSelector()
        case .unlockStalker:
            unlockedZombieTypes.insert(.stalker);  updateStrainSelector()
        case .unlockSpitter:
            unlockedZombieTypes.insert(.spitter);  updateStrainSelector()
        }
        updateEvoBadge()
        evolutionPanel.refresh(points: evolutionPoints, levels: upgradeLevels())

        // Tutorial: first upgrade purchased → complete the tutorial
        if isTutorial, tutorialStep == .buyUpgrade {
            evolutionPanel.isHidden = true
            showTutorialStep(.complete)
        }
    }

    private func updateEvoBadge() {
        let badge = evoButtonNode.childNode(withName: "evoBadge")
        badge?.isHidden    = evolutionPoints == 0
        evoBadgeLabel.text = "\(evolutionPoints)"
    }

    // MARK: - Level system

    private func advanceLevel() {
        levelingUp = true
        joystick.reset()
        currentLevel += 1

        // Base forces — scientists ramp faster in later levels
        let nextCops       = copCount      + (currentLevel - 1) * 6
        var nextSoldiers   = soldierCount  + (currentLevel - 1) * 2
        let nextTanks      = currentLevel >= 3 ? tankCount + (currentLevel - 3) : 0
        var nextScientists = 1 + (currentLevel - 1) + max(0, currentLevel - 3)
        let nextEscorts    = currentLevel >= 2 ? min(2, currentLevel - 1) : 0

        // Zombie-cap enforcement: if the horde exceeds 50 boost scientists & soldiers
        let hordeSize = aiZombies.count + 1   // +1 for the player
        let overflow  = max(0, hordeSize - 50)
        let bonusScientists = overflow / 8    // +1 scientist per 8 excess zombies
        let bonusSoldiers   = overflow / 5    // +1 soldier  per 5 excess zombies
        nextScientists += bonusScientists
        nextSoldiers   += bonusSoldiers

        let subtitle = overflow > 0
            ? "⚠️ Horde size \(hordeSize) — reinforcements boosted!"
            : "Reinforcements incoming…"

        showLevelBanner(level: currentLevel, cops: nextCops, soldiers: nextSoldiers,
                        tanks: nextTanks, scientists: nextScientists, escorts: nextEscorts,
                        subtitle: subtitle) { [weak self] in
            guard let self else { return }
            self.spawnLevelForces(cops: nextCops, soldiers: nextSoldiers,
                                  tanks: nextTanks, scientists: nextScientists)
            self.spawnEscortGroups(count: nextEscorts)
            self.levelingUp = false
        }
    }

    private func showLevelBanner(level: Int, cops: Int, soldiers: Int, tanks: Int, scientists: Int, escorts: Int = 0, subtitle: String = "Reinforcements incoming…", completion: @escaping () -> Void) {
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width * 0.78, height: 170), cornerRadius: 16)
        overlay.fillColor   = SKColor(red: 0.04, green: 0.10, blue: 0.04, alpha: 0.94)
        overlay.strokeColor = SKColor(red: 0.25, green: 1.00, blue: 0.25, alpha: 0.70)
        overlay.lineWidth   = 2.5
        overlay.zPosition   = 200
        gameCamera.addChild(overlay)

        let title = centeredLabel("LEVEL \(level)", font: "Menlo-Bold", size: 36,
                                  color: SKColor(red: 0.30, green: 1.00, blue: 0.30, alpha: 1), y: 46)
        title.zPosition = 201; gameCamera.addChild(title)

        let subColor = subtitle.hasPrefix("⚠️")
            ? SKColor(red: 1.00, green: 0.65, blue: 0.15, alpha: 1)
            : SKColor(white: 0.80, alpha: 1)
        let sub = centeredLabel(subtitle, font: "Menlo", size: 15, color: subColor, y: 10)
        sub.zPosition = 201; gameCamera.addChild(sub)

        let escortStr = escorts > 0 ? "  🚶 \(escorts) ESCORT" : ""
        let detail = centeredLabel("👮 \(cops)  🪖 \(soldiers)  💣 \(tanks)  👨‍🔬 \(scientists)\(escortStr)", font: "Menlo-Bold", size: 14,
                                   color: SKColor(red: 1.00, green: 0.80, blue: 0.30, alpha: 1), y: -20)
        detail.zPosition = 201; gameCamera.addChild(detail)

        let nodes = [overlay, title, sub, detail]
        let wait  = SKAction.wait(forDuration: 2.8)
        let fade  = SKAction.fadeOut(withDuration: 0.5)
        run(.sequence([wait, .run {
            nodes.forEach { $0.run(.sequence([fade, .removeFromParent()])) }
        }, .wait(forDuration: 0.5), .run(completion)]))
    }

    private func regroupZombies() {
        // Discard any lingering escort groups from the previous level
        for group in escortGroups {
            group.safeMarker?.removeFromParent()
            group.escortLabel?.removeFromParent()
            group.humans.forEach { $0.isEscorted = false }
        }
        escortGroups.removeAll()

        let xs = cityMap.streetCenterXs.sorted()
        let ys = cityMap.streetCenterYs.sorted()

        // Build a pool of guaranteed-clear intersections in the bottom-left area
        var slots: [CGPoint] = []
        for xi in 0..<min(3, xs.count) {
            for yi in 0..<min(3, ys.count) {
                slots.append(CGPoint(x: xs[xi], y: ys[yi]))
            }
        }

        let allZombies: [CharacterNode] = [player] + aiZombies
        for (i, zombie) in allZombies.enumerated() {
            let base = slots[i % slots.count]
            // Try up to 8 random jitters; fall back to the bare intersection if all clip a wall
            var placed = false
            for _ in 0..<8 {
                let candidate = CGPoint(x: base.x + CGFloat.random(in: -15...15),
                                        y: base.y + CGFloat.random(in: -15...15))
                if !cityMap.isInBuilding(candidate, radius: 16) {
                    zombie.position = candidate
                    placed = true
                    break
                }
            }
            if !placed { zombie.position = base }   // bare intersection is always clear
            zombie.stuckTimer    = 0
            zombie.stuckWaypoint = nil
        }
    }

    private func spawnLevelForces(cops copsToSpawn: Int, soldiers soldiersToSpawn: Int,
                                  tanks tanksToSpawn: Int, scientists scientistsToSpawn: Int) {
        // Regroup all zombies at the bottom-left street corner
        regroupZombies()

        // Respawn humans too so the level has targets
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

        // Cops — try formation, fall back to scatter
        if !buildFormationWithCount(copsToSpawn) {
            fallbackFormationWithCount(copsToSpawn)
        }

        // Soldiers — scatter
        placed = 0; attempts = 0
        while placed < soldiersToSpawn && attempts < 600 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 350 else { continue }
            guard !cops.contains(where: { dist($0.position, pos) < 120 }) else { continue }
            guard !soldiers.contains(where: { dist($0.position, pos) < 200 }) else { continue }
            let s = SoldierNode()
            s.position  = pos
            s.zPosition = 10
            worldNode.addChild(s)
            soldiers.append(s)
            placed += 1
        }

        spawnTanks(count: tanksToSpawn)
        spawnScientists(count: scientistsToSpawn)
        refreshHUD()
    }

    // MARK: - Screens

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
        for t in tanks {  // always targetable — multiple zombies can swarm
            let d = dist(node.position, t.position)
            if d < bestDist { bestDist = d; best = t }
        }
        for sc in scientists where !sc.isBeingBitten {
            let d = dist(node.position, sc.position)
            if d < bestDist { bestDist = d; best = sc }
        }
        return best
    }

    // MARK: - Tanks

    private func spawnTanks(count: Int) {
        var placed = 0; var attempts = 0
        while placed < count && attempts < 400 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 400 else { continue }
            guard !tanks.contains(where: { dist($0.position, pos) < 260 }) else { continue }
            let tank = TankNode()
            tank.position  = pos
            tank.zPosition = 10
            worldNode.addChild(tank)
            tanks.append(tank)
            placed += 1
        }
    }

    private func updateTanks(dt: TimeInterval) {
        var toDestroy: [TankNode] = []
        let allZombies: [CharacterNode] = [player] + aiZombies

        for tank in tanks {
            // Swarm damage: every zombie within swarmRadius deals tankDmgPerSec
            let swarming = allZombies.filter { dist($0.position, tank.position) < TankNode.swarmRadius }
            if !swarming.isEmpty {
                let totalDmg = CGFloat(dt) * swarming.reduce(0) {
                    $0 + ZombieTypeData.info(for: $1.zombieType).tankDmgPerSec
                }
                if tank.takeDamage(totalDmg) {
                    toDestroy.append(tank); continue
                }
            }

            // Cannon fire with line-of-sight check
            let nearestZ = nearestZombieInRange(ofTank: tank)
            let visibleZ = nearestZ.flatMap { z in
                cityMap.hasLineOfSight(from: tank.position, to: z.position) ? z : nil
            }
            if let blastTarget = tank.update(dt: dt, toward: visibleZ) {
                let target = blastTarget
                run(.sequence([
                    .wait(forDuration: 0.35),
                    .run { [weak self] in self?.spawnBlast(at: target) }
                ]))
            }
        }
        for tank in toDestroy { tankDestroyed(tank) }
    }

    private func nearestZombieInRange(ofTank tank: TankNode) -> CharacterNode? {
        let allZombies: [CharacterNode] = [player] + aiZombies
        return allZombies
            .filter { dist(tank.position, $0.position) <= TankNode.shootRange }
            .min { dist(tank.position, $0.position) < dist(tank.position, $1.position) }
    }

    private func tankDestroyed(_ tank: TankNode) {
        tanks.removeAll { $0 === tank }
        for z in aiZombies where z.target === tank { z.target = nil }
        if player.target === tank { player.target = nil }
        spawnTankExplosion(at: tank.position)
        tank.removeFromParent()
        refreshHUD()
    }

    private func spawnBlast(at center: CGPoint) {
        let blast = SKShapeNode(circleOfRadius: TankNode.blastRadius)
        blast.fillColor   = SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.75)
        blast.strokeColor = SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.90)
        blast.lineWidth   = 3
        blast.position    = center
        blast.zPosition   = 15
        worldNode.addChild(blast)
        blast.run(.sequence([
            .group([.scale(to: 1.5, duration: 0.15), .fadeAlpha(to: 0, duration: 0.30)]),
            .removeFromParent()
        ]))

        let core = SKShapeNode(circleOfRadius: TankNode.blastRadius * 0.45)
        core.fillColor   = SKColor(red: 1.0, green: 1.0, blue: 0.85, alpha: 1.0)
        core.strokeColor = .clear
        core.position    = center
        core.zPosition   = 16
        worldNode.addChild(core)
        core.run(.sequence([.fadeOut(withDuration: 0.14), .removeFromParent()]))

        // Damage all zombies in blast radius
        let allZombies: [CharacterNode] = [player] + aiZombies
        for zombie in allZombies {
            guard dist(zombie.position, center) < TankNode.blastRadius else { continue }
            if zombie.takeDamage(TankNode.blastDamage) {
                if zombie === player { playerDied() } else { zombieDied(zombie) }
            }
        }
    }

    private func spawnTankExplosion(at pos: CGPoint) {
        for _ in 0..<14 {
            let shard = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...11))
            shard.fillColor   = SKColor(red: CGFloat.random(in: 0.7...1.0),
                                        green: CGFloat.random(in: 0.3...0.7),
                                        blue: 0.0, alpha: 1.0)
            shard.strokeColor = .clear
            shard.position    = pos
            shard.zPosition   = 15
            worldNode.addChild(shard)
            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let d     = CGFloat.random(in: 30...80)
            let dest  = CGPoint(x: pos.x + cos(angle) * d, y: pos.y + sin(angle) * d)
            shard.run(.sequence([
                .group([.move(to: dest, duration: 0.38), .fadeOut(withDuration: 0.38)]),
                .removeFromParent()
            ]))
        }
        let ring = SKShapeNode(circleOfRadius: 12)
        ring.fillColor   = .clear
        ring.strokeColor = SKColor(red: 1.0, green: 0.70, blue: 0.0, alpha: 1.0)
        ring.lineWidth   = 7
        ring.position    = pos
        ring.zPosition   = 16
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 9, duration: 0.42), .fadeOut(withDuration: 0.42)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Scientists

    private func spawnScientists(count: Int) {
        var placed = 0; var attempts = 0
        while placed < count && attempts < 400 {
            attempts += 1
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 450 else { continue }
            guard !scientists.contains(where: { dist($0.position, pos) < 300 }) else { continue }
            guard !tanks.contains(where: { dist($0.position, pos) < 200 }) else { continue }
            let s = ScientistNode()
            s.position  = pos
            s.zPosition = 10
            worldNode.addChild(s)
            scientists.append(s)
            placed += 1
        }
    }

    private func updateScientists(dt: TimeInterval) {
        for scientist in scientists {
            let nearestZ = nearestZombieInRange(ofScientist: scientist)
            let visibleZ = nearestZ.flatMap { z in
                cityMap.hasLineOfSight(from: scientist.position, to: z.position) ? z : nil
            }
            if let dir = scientist.update(dt: dt, toward: visibleZ) {
                spawnBullet(direction: dir, from: scientist.position, damage: 0, isCure: true)
            }
        }
    }

    private func nearestZombieInRange(ofScientist scientist: ScientistNode) -> CharacterNode? {
        let allZombies: [CharacterNode] = [player] + aiZombies
        return allZombies
            .filter { dist(scientist.position, $0.position) <= ScientistNode.shootRange }
            .min { dist(scientist.position, $0.position) < dist(scientist.position, $1.position) }
    }

    private func convertZombieToHuman(_ zombie: CharacterNode) {
        aiZombies.removeAll { $0 === zombie }
        for z in aiZombies where z.target === zombie { z.target = nil }
        spawnCureBurst(at: zombie.position)
        zombie.becomeHuman()
        zombie.wanderTarget = cityMap.randomStreetPoint()
        humans.append(zombie)
        refreshHUD()
    }

    private func spawnCureBurst(at pos: CGPoint) {
        // Expanding cyan ring
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.strokeColor = SKColor(red: 0.20, green: 0.95, blue: 0.95, alpha: 0.90)
        ring.fillColor   = SKColor(red: 0.15, green: 0.90, blue: 0.90, alpha: 0.25)
        ring.lineWidth   = 2.5
        ring.position    = pos
        ring.zPosition   = 12
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 3.2, duration: 0.35),
                .fadeOut(withDuration: 0.35)
            ]),
            .removeFromParent()
        ]))

        // "CURED" pop label
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.text      = "CURED"
        lbl.fontSize  = 13
        lbl.fontColor = SKColor(red: 0.20, green: 1.00, blue: 1.00, alpha: 1)
        lbl.horizontalAlignmentMode = .center
        lbl.position  = CGPoint(x: pos.x, y: pos.y + 28)
        lbl.zPosition = 13
        worldNode.addChild(lbl)
        lbl.run(.sequence([
            .group([
                .moveBy(x: 0, y: 22, duration: 0.55),
                .sequence([.wait(forDuration: 0.20), .fadeOut(withDuration: 0.35)])
            ]),
            .removeFromParent()
        ]))
    }

    private func playerCured() {
        guard !gameOver else { return }
        guard let nearest = aiZombies.min(by: {
            dist($0.position, player.position) < dist($1.position, player.position)
        }) else {
            gameOver = true
            joystick.reset()
            showGameOver()
            return
        }
        player.becomeHuman()
        player.wanderTarget = cityMap.randomStreetPoint()
        humans.append(player)
        aiZombies.removeAll { $0 === nearest }
        nearest.becomePlayer()
        player = nearest
        refreshHUD()
        showCuredBanner()
    }

    private func showCuredBanner() {
        let title = centeredLabel("CURED!", font: "Menlo-Bold", size: 22,
                                  color: SKColor(red: 0.20, green: 0.95, blue: 0.95, alpha: 1), y: 20)
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

    // MARK: - Tutorial

    private func startTutorial() {
        // Four civilians placed close to the player on clear street spots
        let offsets: [CGPoint] = [
            CGPoint(x:  160, y:    0),
            CGPoint(x: -160, y:    0),
            CGPoint(x:    0, y:  160),
            CGPoint(x:  120, y: -120)
        ]
        for offset in offsets {
            let raw = CGPoint(x: player.position.x + offset.x,
                              y: player.position.y + offset.y)
            let pos = safeZombiePosition(near: raw)
            let h   = CharacterNode(type: .human)
            h.position     = pos
            h.zPosition    = 10
            h.wanderTarget = cityMap.randomStreetPoint()
            worldNode.addChild(h)
            humans.append(h)
        }

        // Seed 3 evolution points so the player can definitely buy something
        evolutionPoints = 3
        refreshHUD()

        tutorialStartPos = player.position

        let overlay = TutorialNode(sceneSize: size)
        overlay.zPosition = 200
        gameCamera.addChild(overlay)
        tutorialNode = overlay

        showTutorialStep(.move)
    }

    private func showTutorialStep(_ step: TutorialStep) {
        tutorialStep = step
        guard let tut = tutorialNode else { return }

        let joystickPos = CGPoint(x: -size.width/2 + 110, y: -size.height/2 + 110)
        let evoBtnPos   = CGPoint(x:  size.width/2 - 75,  y: -size.height/2 + 75)

        switch step {
        case .move:
            tut.showStep(.move,
                         title: "Drag the joystick to move",
                         body:  "Use the circle in the bottom-left corner",
                         arrowAt: joystickPos)

        case .bite:
            tut.showStep(.bite,
                         title: "Walk into a 🧑 civilian to infect them!",
                         body:  "Move close enough and the bite happens automatically")

        case .evoPoint:
            tut.showStep(.evoPoint,
                         title: "Evolution Point earned! 🧬",
                         body:  "Infecting civilians grows your horde & rewards EP")
            tut.flash(label: "+1 EP")
            // Auto-advance after 2.5 s
            run(.sequence([
                .wait(forDuration: 2.5),
                .run { [weak self] in self?.showTutorialStep(.openPanel) }
            ]), withKey: "tutAutoAdv")

        case .openPanel:
            tut.showStep(.openPanel,
                         title: "Tap 🧬 to open the Virus Lab",
                         body:  "Spend Evolution Points to upgrade your strain",
                         arrowAt: evoBtnPos)

        case .buyUpgrade:
            tut.showStep(.buyUpgrade,
                         title: "Select an upgrade to evolve!",
                         body:  "Tap any row to buy — you have 3 EP to spend")

        case .complete:
            tut.showStep(.complete,
                         title: "Tutorial complete! 🧟",
                         body:  "Infect the whole city — good luck!")
            run(.sequence([
                .wait(forDuration: 2.8),
                .run { [weak self] in self?.finishTutorial() }
            ]), withKey: "tutComplete")
        }
    }

    private func finishTutorial() {
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
        tutorialNode?.dismiss {  }
        tutorialNode = nil
        isTutorial   = false

        // Spawn the real level forces (no tanks until level 3)
        spawnCops()
        spawnSoldiers()
        spawnScientists(count: scientistCount)

        // Replenish civilians so level 1 is properly populated
        spawnHumans()

        // Brief "Level 1 start" banner
        let banner = centeredLabel("LEVEL 1 — SURVIVE!", font: "Menlo-Bold", size: 20,
                                   color: SKColor(red: 1, green: 0.85, blue: 0.30, alpha: 1), y: 0)
        banner.zPosition = 201
        banner.run(.sequence([
            .wait(forDuration: 2.0),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
        gameCamera.addChild(banner)
    }

    // MARK: - Escort groups

    private func spawnEscortGroups(count: Int) {
        for _ in 0..<count { spawnEscortGroup() }
    }

    private func spawnEscortGroup() {
        let xs = cityMap.streetCenterXs
        let ys = cityMap.streetCenterYs

        // Safe zone: upper-right quadrant of the map
        let destXs = xs.filter { $0 > worldSize.width  * 0.55 }
        let destYs = ys.filter { $0 > worldSize.height * 0.55 }
        guard let destX = destXs.randomElement(), let destY = destYs.randomElement() else { return }
        let dest = CGPoint(x: destX, y: destY)

        // Escort start: anywhere on the map far from player AND safe zone
        var origin: CGPoint?
        for _ in 0..<300 {
            let pos = cityMap.randomStreetPoint()
            guard dist(pos, player.position) > 420 else { continue }
            guard dist(pos, dest)             > 480 else { continue }
            origin = pos; break
        }
        guard let origin else { return }

        // Safe-zone marker (in worldNode)
        let marker = makeEscortSafeMarker(at: dest)
        worldNode.addChild(marker)

        // Civilians tight cluster around origin
        let civCount = Int.random(in: 3...5)
        var groupHumans: [CharacterNode] = []
        for i in 0..<civCount {
            let angle = CGFloat(i) / CGFloat(civCount) * 2 * .pi
            let raw   = CGPoint(x: origin.x + 28 * cos(angle),
                                y: origin.y + 28 * sin(angle))
            let pos   = safeZombiePosition(near: raw)
            let h     = CharacterNode(type: .human)
            h.position     = pos
            h.zPosition    = 10
            h.isEscorted   = true
            h.wanderTarget = nil
            worldNode.addChild(h)
            humans.append(h)
            groupHumans.append(h)
        }

        // Escort cops orbiting the cluster
        let copRing = Int.random(in: 3...4)
        var groupCops: [CopNode] = []
        for i in 0..<copRing {
            let angle = CGFloat(i) / CGFloat(copRing) * 2 * .pi
            let raw   = CGPoint(x: origin.x + 85 * cos(angle),
                                y: origin.y + 85 * sin(angle))
            let pos   = safeZombiePosition(near: raw)
            let cop   = CopNode()
            cop.position  = pos
            cop.zPosition = 10
            worldNode.addChild(cop)
            cops.append(cop)
            groupCops.append(cop)
        }

        // Floating "ESCORT" label that follows the group centroid
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.text      = "▶ ESCORT"
        lbl.fontSize  = 11
        lbl.fontColor = SKColor(red: 0.25, green: 1.00, blue: 0.30, alpha: 0.90)
        lbl.horizontalAlignmentMode = .center
        lbl.position  = CGPoint(x: origin.x, y: origin.y + 100)
        lbl.zPosition = 15
        worldNode.addChild(lbl)

        let group          = EscortGroup(humans: groupHumans, cops: groupCops, dest: dest)
        group.safeMarker   = marker
        group.escortLabel  = lbl
        escortGroups.append(group)
        refreshHUD()
    }

    private func updateEscortGroups(dt: TimeInterval) {
        var finished: [EscortGroup] = []

        for group in escortGroups {
            // Prune members lost to infection or conversion
            group.humans.removeAll { h in !humans.contains { $0 === h } }
            group.cops.removeAll   { c in !cops.contains   { $0 === c } }

            if group.humans.isEmpty {
                group.safeMarker?.removeFromParent()
                group.escortLabel?.removeFromParent()
                finished.append(group); continue
            }

            let centre = group.centroid
            let dx = group.dest.x - centre.x
            let dy = group.dest.y - centre.y
            let dd = sqrt(dx*dx + dy*dy)

            // Arrived at safe zone
            if dd < 55 {
                let saved = group.humans.count
                for h in group.humans {
                    h.isEscorted = false
                    humans.removeAll { $0 === h }
                    h.removeFromParent()
                }
                group.humans.removeAll()
                group.safeMarker?.removeFromParent()
                group.escortLabel?.removeFromParent()
                spawnEscapedBanner(at: group.dest, count: saved)
                finished.append(group)
                refreshHUD(); continue
            }

            // Move civilians toward safe zone
            let nx = dx / dd, ny = dy / dd
            let civStep = group.speed * CGFloat(dt)
            for h in group.humans {
                let raw = CGPoint(x: h.position.x + nx * civStep,
                                  y: h.position.y + ny * civStep)
                h.position = cityMap.resolve(newPos: clampToWorld(raw), from: h.position)
                h.faceDirection(CGVector(dx: nx, dy: ny))
            }

            // Move cops in a protective ring around the centroid
            let n = max(1, group.cops.count)
            for (i, cop) in group.cops.enumerated() {
                let angle = CGFloat(i) / CGFloat(n) * 2 * .pi
                let orbitPt = CGPoint(x: centre.x + group.orbitRadius * cos(angle),
                                     y: centre.y + group.orbitRadius * sin(angle))
                let cdx = orbitPt.x - cop.position.x
                let cdy = orbitPt.y - cop.position.y
                let cd  = sqrt(cdx*cdx + cdy*cdy)
                guard cd > 6 else { continue }
                let raw = CGPoint(x: cop.position.x + (cdx/cd) * 110 * CGFloat(dt),
                                  y: cop.position.y + (cdy/cd) * 110 * CGFloat(dt))
                cop.position = cityMap.resolve(newPos: clampToWorld(raw), from: cop.position)
            }

            // Keep the label floating above the group
            group.escortLabel?.position = CGPoint(x: centre.x,
                                                  y: centre.y + group.orbitRadius + 20)
        }

        escortGroups.removeAll { g in finished.contains { $0 === g } }
    }

    private func makeEscortSafeMarker(at pos: CGPoint) -> SKNode {
        let node = SKNode()
        node.position  = pos
        node.zPosition = 4

        // ── Landing pad ──────────────────────────────────────────────
        let pad = SKShapeNode(circleOfRadius: 38)
        pad.fillColor   = SKColor(red: 0.05, green: 0.22, blue: 0.08, alpha: 0.70)
        pad.strokeColor = SKColor(red: 0.25, green: 0.90, blue: 0.30, alpha: 0.90)
        pad.lineWidth   = 2.5
        node.addChild(pad)

        // "H" helipad marker
        let hMark = SKLabelNode(fontNamed: "Menlo-Bold")
        hMark.text                    = "H"
        hMark.fontSize                = 30
        hMark.fontColor               = SKColor(red: 0.25, green: 0.90, blue: 0.30, alpha: 0.85)
        hMark.verticalAlignmentMode   = .center
        hMark.horizontalAlignmentMode = .center
        node.addChild(hMark)

        // ── Helicopter hovering above ─────────────────────────────────
        let heli = makeHelicopterNode()
        heli.position = CGPoint(x: 0, y: 60)
        node.addChild(heli)

        // "EXTRACT" label below the pad
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.text                    = "EXTRACT"
        lbl.fontSize                = 11
        lbl.fontColor               = SKColor(red: 0.30, green: 1.00, blue: 0.35, alpha: 1)
        lbl.horizontalAlignmentMode = .center
        lbl.position                = CGPoint(x: 0, y: -52)
        node.addChild(lbl)

        return node
    }

    private func makeHelicopterNode() -> SKNode {
        let heli = SKNode()

        // ── Fuselage ──────────────────────────────────────────────────
        let body = SKShapeNode(rectOf: CGSize(width: 38, height: 16), cornerRadius: 6)
        body.fillColor   = SKColor(red: 0.22, green: 0.32, blue: 0.22, alpha: 1)
        body.strokeColor = SKColor(red: 0.38, green: 0.52, blue: 0.38, alpha: 1)
        body.lineWidth   = 1.5
        heli.addChild(body)

        // Cockpit glass
        let glass = SKShapeNode(rectOf: CGSize(width: 13, height: 9), cornerRadius: 3)
        glass.fillColor   = SKColor(red: 0.55, green: 0.82, blue: 1.00, alpha: 0.80)
        glass.strokeColor = .clear
        glass.position    = CGPoint(x: 11, y: 2)
        heli.addChild(glass)

        // ── Tail boom ────────────────────────────────────────────────
        let boom = SKShapeNode(rectOf: CGSize(width: 20, height: 5), cornerRadius: 1.5)
        boom.fillColor   = SKColor(red: 0.18, green: 0.27, blue: 0.18, alpha: 1)
        boom.strokeColor = .clear
        boom.position    = CGPoint(x: -19, y: 1)
        heli.addChild(boom)

        // Tail rotor (spins fast)
        let tailRotor = SKShapeNode(rectOf: CGSize(width: 2, height: 12), cornerRadius: 1)
        tailRotor.fillColor   = SKColor(white: 0.75, alpha: 0.85)
        tailRotor.strokeColor = .clear
        tailRotor.position    = CGPoint(x: -29, y: 1)
        tailRotor.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.12)))
        heli.addChild(tailRotor)

        // ── Main rotor mast ──────────────────────────────────────────
        let mast = SKShapeNode(rectOf: CGSize(width: 3, height: 7), cornerRadius: 1)
        mast.fillColor   = SKColor(white: 0.55, alpha: 1)
        mast.strokeColor = .clear
        mast.position    = CGPoint(x: 0, y: 12)
        heli.addChild(mast)

        // Main rotor hub + two blades (spins)
        let hub = SKNode()
        hub.position = CGPoint(x: 0, y: 16)
        for angle in [CGFloat(0), .pi / 2] {
            let blade = SKShapeNode(rectOf: CGSize(width: 54, height: 3), cornerRadius: 1.5)
            blade.fillColor   = SKColor(white: 0.72, alpha: 0.88)
            blade.strokeColor = .clear
            blade.zRotation   = angle
            hub.addChild(blade)
        }
        hub.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.22)))
        heli.addChild(hub)

        // ── Landing skids ─────────────────────────────────────────────
        let skid = SKShapeNode(rectOf: CGSize(width: 30, height: 3), cornerRadius: 1)
        skid.fillColor   = SKColor(white: 0.42, alpha: 1)
        skid.strokeColor = .clear
        skid.position    = CGPoint(x: 0, y: -12)
        heli.addChild(skid)

        // Blinking nav light
        let light = SKShapeNode(circleOfRadius: 3)
        light.fillColor   = SKColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1)
        light.strokeColor = .clear
        light.position    = CGPoint(x: 17, y: -8)
        light.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.10, duration: 0.45),
            .fadeAlpha(to: 1.00, duration: 0.45)
        ])))
        heli.addChild(light)

        // Gentle hover bob
        heli.run(.repeatForever(.sequence([
            .moveBy(x: 0, y:  5, duration: 0.85),
            .moveBy(x: 0, y: -5, duration: 0.85)
        ])))

        return heli
    }

    private func spawnEscapedBanner(at pos: CGPoint, count: Int) {
        let node = SKNode()
        node.position  = pos
        node.zPosition = 20
        worldNode.addChild(node)

        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.text      = "\(count) ESCAPED!"
        lbl.fontSize  = 16
        lbl.fontColor = SKColor(red: 0.20, green: 1.00, blue: 0.30, alpha: 1)
        lbl.horizontalAlignmentMode = .center
        node.addChild(lbl)

        node.run(.sequence([
            .group([
                .moveBy(x: 0, y: 52, duration: 1.8),
                .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 1.2)])
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Strain selector

    private func setupStrainSelector() {
        let bg = SKShapeNode(rectOf: CGSize(width: 140, height: 34), cornerRadius: 10)
        bg.fillColor   = SKColor(red: 0.05, green: 0.10, blue: 0.05, alpha: 0.88)
        bg.strokeColor = SKColor(red: 0.20, green: 0.70, blue: 0.20, alpha: 0.65)
        bg.lineWidth   = 1.5
        bg.name        = "strainBtn"

        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.fontSize                = 11
        lbl.fontColor               = SKColor(red: 0.30, green: 1.00, blue: 0.30, alpha: 1)
        lbl.verticalAlignmentMode   = .center
        lbl.horizontalAlignmentMode = .center
        lbl.name                    = "strainLbl"
        bg.addChild(lbl)
        strainSelectorLabel = lbl

        strainSelectorNode          = bg
        strainSelectorNode.position = CGPoint(x: 0, y: -size.height/2 + 38)
        strainSelectorNode.zPosition = 102
        gameCamera.addChild(strainSelectorNode)
        updateStrainSelector()
    }

    private func updateStrainSelector() {
        let info = ZombieTypeData.info(for: activeConversionType)
        strainSelectorLabel.text = "\(info.emoji) \(info.name)"
        strainSelectorNode.run(.sequence([
            .scale(to: 1.12, duration: 0.08),
            .scale(to: 1.00, duration: 0.10)
        ]))
    }

    private func cycleConversionType() {
        let available = ZombieType.allCases.filter { unlockedZombieTypes.contains($0) }
        guard available.count > 1 else { return }
        let idx = available.firstIndex(of: activeConversionType) ?? 0
        activeConversionType = available[(idx + 1) % available.count]
        updateStrainSelector()
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
            } else if dist(camPt, strainSelectorNode.position) < 72 {
                cycleConversionType()
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

// MARK: - EscortGroup

private final class EscortGroup {
    var humans:  [CharacterNode]
    var cops:    [CopNode]
    let dest:    CGPoint
    weak var safeMarker:  SKNode?
    weak var escortLabel: SKLabelNode?

    let speed:       CGFloat = 42   // px/s — brisk walking pace
    let orbitRadius: CGFloat = 80

    init(humans: [CharacterNode], cops: [CopNode], dest: CGPoint) {
        self.humans = humans; self.cops = cops; self.dest = dest
    }

    var centroid: CGPoint {
        guard !humans.isEmpty else { return dest }
        var sx: CGFloat = 0, sy: CGFloat = 0
        for h in humans { sx += h.position.x; sy += h.position.y }
        let n = CGFloat(humans.count)
        return CGPoint(x: sx / n, y: sy / n)
    }
}
