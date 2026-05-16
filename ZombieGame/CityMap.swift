import SpriteKit

// MARK: - Data types

struct BuildingData {
    let rect: CGRect
    let color: SKColor
}

struct CarData {
    let rect: CGRect
    let color: SKColor
    let isHorizontal: Bool
}

// MARK: - CityMap

class CityMap {

    // Layout constants
    static let streetW: CGFloat = 84
    static let blockW:  CGFloat = 204
    static let cellW:   CGFloat = streetW + blockW  // 288

    let worldSize: CGSize
    private(set) var buildings: [BuildingData] = []
    private(set) var cars:      [CarData]      = []

    // Street centre lines (for wander target snapping)
    lazy var streetCenterXs: [CGFloat] = {
        var xs: [CGFloat] = []
        var x: CGFloat = 0
        while x < worldSize.width  { xs.append(x + CityMap.streetW / 2); x += CityMap.cellW }
        return xs
    }()
    lazy var streetCenterYs: [CGFloat] = {
        var ys: [CGFloat] = []
        var y: CGFloat = 0
        while y < worldSize.height { ys.append(y + CityMap.streetW / 2); y += CityMap.cellW }
        return ys
    }()

    init(worldSize: CGSize) {
        self.worldSize = worldSize
        generate()
    }

    // MARK: - Generation

    private func generate() {
        let sw = CityMap.streetW, bw = CityMap.blockW, cw = CityMap.cellW

        let wallColors: [SKColor] = [
            SKColor(red: 0.22, green: 0.22, blue: 0.30, alpha: 1),
            SKColor(red: 0.26, green: 0.20, blue: 0.20, alpha: 1),
            SKColor(red: 0.18, green: 0.24, blue: 0.18, alpha: 1),
            SKColor(red: 0.28, green: 0.24, blue: 0.18, alpha: 1),
            SKColor(red: 0.24, green: 0.20, blue: 0.26, alpha: 1),
        ]

        var ox = sw
        while ox + bw <= worldSize.width {
            var oy = sw
            while oy + bw <= worldSize.height {
                if Float.random(in: 0...1) > 0.10 {   // 10 % open lots
                    placeBuildings(at: CGPoint(x: ox, y: oy),
                                   blockSize: bw, colors: wallColors)
                }
                oy += cw
            }
            ox += cw
        }

        placeCars()
    }

    private func placeBuildings(at origin: CGPoint, blockSize: CGFloat,
                                colors: [SKColor]) {
        let g: CGFloat = 8
        switch Int.random(in: 0...2) {

        case 0:   // one large building
            buildings.append(BuildingData(
                rect: CGRect(x: origin.x + g, y: origin.y + g,
                             width: blockSize - g*2, height: blockSize - g*2),
                color: colors.randomElement()!))

        case 1:   // 2×2 quad
            let sub = (blockSize - g * 3) / 2
            for row in 0..<2 {
                for col in 0..<2 {
                    buildings.append(BuildingData(
                        rect: CGRect(x: origin.x + g + CGFloat(col)*(sub+g),
                                     y: origin.y + g + CGFloat(row)*(sub+g),
                                     width: sub, height: sub),
                        color: colors.randomElement()!))
                }
            }

        default:  // two side-by-side
            let w1 = CGFloat.random(in: 80...110)
            let w2 = blockSize - w1 - g * 3
            if w2 > 40 {
                buildings.append(BuildingData(
                    rect: CGRect(x: origin.x + g, y: origin.y + g,
                                 width: w1, height: blockSize - g*2),
                    color: colors.randomElement()!))
                buildings.append(BuildingData(
                    rect: CGRect(x: origin.x + w1 + g*2, y: origin.y + g,
                                 width: w2, height: blockSize - g*2),
                    color: colors.randomElement()!))
            } else {
                buildings.append(BuildingData(
                    rect: CGRect(x: origin.x + g, y: origin.y + g,
                                 width: blockSize - g*2, height: blockSize - g*2),
                    color: colors.randomElement()!))
            }
        }
    }

    private func placeCars() {
        let sw = CityMap.streetW
        let cw = CityMap.cellW
        let carL: CGFloat = 46, carS: CGFloat = 22, edge: CGFloat = 8

        let carColors: [SKColor] = [
            SKColor(red: 0.75, green: 0.15, blue: 0.15, alpha: 1),
            SKColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1),
            SKColor(red: 0.70, green: 0.60, blue: 0.10, alpha: 1),
            SKColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1),
            SKColor(red: 0.10, green: 0.45, blue: 0.20, alpha: 1),
            SKColor(red: 0.55, green: 0.30, blue: 0.10, alpha: 1),
            SKColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1),
        ]

        // Horizontal streets
        var sy: CGFloat = 0
        while sy < worldSize.height {
            var cx: CGFloat = 30
            while cx + carL < worldSize.width {
                if Float.random(in: 0...1) < 0.45 {
                    cars.append(CarData(
                        rect: CGRect(x: cx, y: sy + edge, width: carL, height: carS),
                        color: carColors.randomElement()!, isHorizontal: true))
                }
                if Float.random(in: 0...1) < 0.45 {
                    cars.append(CarData(
                        rect: CGRect(x: cx, y: sy + sw - edge - carS, width: carL, height: carS),
                        color: carColors.randomElement()!, isHorizontal: true))
                }
                cx += carL + CGFloat.random(in: 6...22)
            }
            sy += cw
        }

        // Vertical streets
        var sx: CGFloat = 0
        while sx < worldSize.width {
            var cy: CGFloat = 30
            while cy + carL < worldSize.height {
                if Float.random(in: 0...1) < 0.45 {
                    cars.append(CarData(
                        rect: CGRect(x: sx + edge, y: cy, width: carS, height: carL),
                        color: carColors.randomElement()!, isHorizontal: false))
                }
                if Float.random(in: 0...1) < 0.45 {
                    cars.append(CarData(
                        rect: CGRect(x: sx + sw - edge - carS, y: cy, width: carS, height: carL),
                        color: carColors.randomElement()!, isHorizontal: false))
                }
                cy += carL + CGFloat.random(in: 6...22)
            }
            sx += cw
        }
    }

    // MARK: - Scene building

    func buildScene(into node: SKNode) {
        // Asphalt ground
        let bg = SKShapeNode(rectOf: worldSize)
        bg.fillColor = SKColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: worldSize.width/2, y: worldSize.height/2)
        node.addChild(bg)

        addSidewalks(to: node)
        addRoadMarkings(to: node)

        for b in buildings {
            let shape = SKShapeNode(rectOf: b.rect.size, cornerRadius: 3)
            shape.fillColor = b.color
            shape.strokeColor = SKColor(white: 0.50, alpha: 0.70)
            shape.lineWidth = 1.5
            shape.position = CGPoint(x: b.rect.midX, y: b.rect.midY)
            shape.zPosition = 1
            node.addChild(shape)
            addWindows(to: node, building: b)
        }

        for car in cars {
            addCarNode(car, to: node)
        }

        // World border
        let border = SKShapeNode(rectOf: CGSize(width: worldSize.width - 4,
                                                height: worldSize.height - 4))
        border.fillColor = .clear
        border.strokeColor = SKColor(white: 0.55, alpha: 0.80)
        border.lineWidth = 4
        border.position = CGPoint(x: worldSize.width/2, y: worldSize.height/2)
        border.zPosition = 3
        node.addChild(border)
    }

    private func addSidewalks(to node: SKNode) {
        let sw = CityMap.streetW, bw = CityMap.blockW, cw = CityMap.cellW
        let sidewalkColor = SKColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1)

        var ox = sw
        while ox + bw <= worldSize.width {
            var oy = sw
            while oy + bw <= worldSize.height {
                let side = SKShapeNode(rectOf: CGSize(width: bw, height: bw))
                side.fillColor = sidewalkColor
                side.strokeColor = .clear
                side.position = CGPoint(x: ox + bw/2, y: oy + bw/2)
                side.zPosition = 0
                node.addChild(side)
                oy += cw
            }
            ox += cw
        }
    }

    private func addRoadMarkings(to node: SKNode) {
        let sw = CityMap.streetW, cw = CityMap.cellW
        let dashLen: CGFloat = 18, dashGap: CGFloat = 14
        let lineColor = SKColor(white: 0.55, alpha: 0.35)

        // Horizontal dashes
        var sy: CGFloat = 0
        while sy < worldSize.height {
            let cy = sy + sw/2
            var dx: CGFloat = 0
            while dx < worldSize.width {
                let line = SKShapeNode()
                let p = CGMutablePath()
                p.move(to: CGPoint(x: dx, y: cy))
                p.addLine(to: CGPoint(x: min(dx + dashLen, worldSize.width), y: cy))
                line.path = p; line.strokeColor = lineColor; line.lineWidth = 2
                node.addChild(line)
                dx += dashLen + dashGap
            }
            sy += cw
        }

        // Vertical dashes
        var sx: CGFloat = 0
        while sx < worldSize.width {
            let cx = sx + sw/2
            var dy: CGFloat = 0
            while dy < worldSize.height {
                let line = SKShapeNode()
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cx, y: dy))
                p.addLine(to: CGPoint(x: cx, y: min(dy + dashLen, worldSize.height)))
                line.path = p; line.strokeColor = lineColor; line.lineWidth = 2
                node.addChild(line)
                dy += dashLen + dashGap
            }
            sx += cw
        }
    }

    private func addWindows(to node: SKNode, building: BuildingData) {
        let ws: CGFloat = 7, wg: CGFloat = 11, margin: CGFloat = 11
        var wy = building.rect.minY + margin
        while wy + ws < building.rect.maxY - margin/2 {
            var wx = building.rect.minX + margin
            while wx + ws < building.rect.maxX - margin/2 {
                if Float.random(in: 0...1) > 0.28 {
                    let win = SKShapeNode(rectOf: CGSize(width: ws, height: ws))
                    let br = CGFloat.random(in: 0.65...1.0)
                    win.fillColor = Float.random(in: 0...1) > 0.45
                        ? SKColor(red: br, green: br*0.82, blue: br*0.28, alpha: 0.90)
                        : SKColor(red: 0.35, green: 0.55, blue: br, alpha: 0.85)
                    win.strokeColor = .clear
                    win.position = CGPoint(x: wx + ws/2, y: wy + ws/2)
                    win.zPosition = 2
                    node.addChild(win)
                }
                wx += ws + wg
            }
            wy += ws + wg
        }
    }

    private func addCarNode(_ car: CarData, to node: SKNode) {
        let body = SKShapeNode(rectOf: car.rect.size, cornerRadius: 5)
        body.fillColor = car.color
        body.strokeColor = SKColor(white: 0.85, alpha: 0.55)
        body.lineWidth = 1
        body.position = CGPoint(x: car.rect.midX, y: car.rect.midY)
        body.zPosition = 1

        // Windshield tint
        let ww: CGFloat = car.isHorizontal ? car.rect.width * 0.38 : car.rect.width * 0.72
        let wh: CGFloat = car.isHorizontal ? car.rect.height * 0.72 : car.rect.height * 0.38
        let glass = SKShapeNode(rectOf: CGSize(width: ww, height: wh), cornerRadius: 2)
        glass.fillColor = SKColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 0.55)
        glass.strokeColor = .clear
        glass.zPosition = 1
        body.addChild(glass)

        node.addChild(body)
    }

    // MARK: - Runtime queries

    /// 1/3 speed when standing on a car, otherwise 1.0
    func speedMultiplier(at point: CGPoint) -> CGFloat {
        for car in cars where car.rect.contains(point) { return 1.0/3.0 }
        return 1.0
    }

    /// Push newPos out of any building, sliding along walls.
    func resolve(newPos: CGPoint, from oldPos: CGPoint, radius: CGFloat = 16) -> CGPoint {
        var pos = newPos
        let r = radius
        for b in buildings {
            let expanded = b.rect.insetBy(dx: -r, dy: -r)
            guard expanded.contains(pos) else { continue }
            // Try X-slide
            let xPos = CGPoint(x: pos.x, y: oldPos.y)
            if !buildings.contains(where: { $0.rect.insetBy(dx: -r, dy: -r).contains(xPos) }) {
                pos = xPos; continue
            }
            // Try Y-slide
            let yPos = CGPoint(x: oldPos.x, y: pos.y)
            if !buildings.contains(where: { $0.rect.insetBy(dx: -r, dy: -r).contains(yPos) }) {
                pos = yPos; continue
            }
            pos = oldPos
        }
        return pos
    }

    /// True if point is inside a building footprint.
    func isInBuilding(_ point: CGPoint, radius: CGFloat = 20) -> Bool {
        buildings.contains { $0.rect.insetBy(dx: -radius, dy: -radius).contains(point) }
    }

    /// Random point guaranteed to be on the street grid.
    func randomStreetPoint() -> CGPoint {
        CGPoint(x: streetCenterXs.randomElement()!,
                y: streetCenterYs.randomElement()!)
    }
}
