import SpriteKit

enum UpgradeType: String, CaseIterable {
    case rage, durability, virulence, conversion
    case unlockHunter, unlockBrute, unlockScreamer, unlockStalker, unlockSpitter
}

class EvolutionPanelNode: SKNode {

    struct Def {
        let type:  UpgradeType
        let name:  String
        let desc:  String
        let costs: [Int]
        let icon:  String
    }

    static let defs: [Def] = [
        Def(type: .rage,          name: "INFECTED RAGE",   desc: "+20% zombie speed per tier",    costs: [1, 2, 3], icon: "⚡"),
        Def(type: .durability,    name: "NECROTIC HIDE",   desc: "+25 max HP per tier",           costs: [1, 2, 3], icon: "🛡"),
        Def(type: .virulence,     name: "VIRAL OVERLOAD",  desc: "40% faster infection per tier", costs: [2, 4],    icon: "🦠"),
        Def(type: .conversion,    name: "RAPID MUTATION",  desc: "Cut ceiling: 15s→10s→7s",      costs: [2, 3],    icon: "🧫"),
        Def(type: .unlockHunter,  name: "HUNTER STRAIN",  desc: "🐺 Fast · tough · wrecks tanks",costs: [4],       icon: "🐺"),
        Def(type: .unlockBrute,   name: "BRUTE STRAIN",   desc: "👹 Massive HP · slow · wide",   costs: [3],       icon: "👹"),
        Def(type: .unlockScreamer,name: "SCREAMER STRAIN",desc: "👻 Converts 60% faster",        costs: [3],       icon: "👻"),
        Def(type: .unlockStalker, name: "STALKER STRAIN", desc: "🦎 Extreme speed · fragile",    costs: [3],       icon: "🦎"),
        Def(type: .unlockSpitter, name: "SPITTER STRAIN", desc: "🤢 Long range · faster infect", costs: [3],       icon: "🤢"),
    ]

    var onBuy:   ((UpgradeType) -> Void)?
    var onClose: (() -> Void)?

    private let W:    CGFloat
    private let H:    CGFloat
    private let rowH: CGFloat
    private var pointsLabel: SKLabelNode!

    init(sceneSize: CGSize) {
        W    = min(sceneSize.width * 0.88, 520)
        let maxH = sceneSize.height * 0.91
        let ideal = CGFloat(EvolutionPanelNode.defs.count) * 78 + 92
        H    = min(ideal, maxH)
        rowH = (H - 92) / CGFloat(EvolutionPanelNode.defs.count)
        super.init()
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildUI() {
        let dim = SKShapeNode(rectOf: CGSize(width: 5000, height: 5000))
        dim.fillColor = SKColor(white: 0, alpha: 0.70); dim.strokeColor = .clear; dim.zPosition = -1
        addChild(dim)

        let card = SKShapeNode(rectOf: CGSize(width: W, height: H), cornerRadius: 14)
        card.fillColor   = SKColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 0.97)
        card.strokeColor = SKColor(red: 0.25, green: 0.80, blue: 0.25, alpha: 0.65)
        card.lineWidth   = 2
        addChild(card)

        addChild(mk("🧬  VIRUS EVOLUTION", font: "Menlo-Bold", size: 17,
                     color: SKColor(red: 0.30, green: 1.00, blue: 0.30, alpha: 1),
                     at: CGPoint(x: 0, y: H/2 - 26)))

        pointsLabel = mk("", font: "Menlo-Bold", size: 12,
                          color: SKColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1),
                          at: CGPoint(x: 0, y: H/2 - 48))
        addChild(pointsLabel)

        addChild(hline(y: H/2 - 62))

        for (i, def) in EvolutionPanelNode.defs.enumerated() {
            let cy = H/2 - 62 - rowH/2 - CGFloat(i) * rowH
            addChild(buildRow(def, centerY: cy))
        }

        let closeBtn = SKShapeNode(circleOfRadius: 15)
        closeBtn.fillColor   = SKColor(red: 0.40, green: 0.08, blue: 0.08, alpha: 1)
        closeBtn.strokeColor = SKColor(red: 1, green: 0.25, blue: 0.25, alpha: 0.80)
        closeBtn.lineWidth   = 1.5
        closeBtn.position    = CGPoint(x: W/2 - 20, y: H/2 - 20)
        closeBtn.name        = "evo_close"
        let xLbl = mk("✕", font: "Menlo-Bold", size: 14, color: .white, at: .zero)
        xLbl.verticalAlignmentMode = .center
        closeBtn.addChild(xLbl)
        addChild(closeBtn)
    }

    private func buildRow(_ def: Def, centerY: CGFloat) -> SKNode {
        let row   = SKNode()
        row.position = CGPoint(x: 0, y: centerY)

        let h  = rowH - 6
        let bg = SKShapeNode(rectOf: CGSize(width: W - 20, height: h), cornerRadius: 7)
        bg.fillColor   = SKColor(white: 0.10, alpha: 0.70)
        bg.strokeColor = SKColor(white: 0.22, alpha: 0.40)
        bg.lineWidth   = 1
        row.addChild(bg)

        // Icon
        let iconLbl = mk(def.icon, font: "Menlo", size: 22, color: .white,
                         at: CGPoint(x: -W/2 + 30, y: 2))
        row.addChild(iconLbl)

        // Name
        let nameLbl = mk(def.name, font: "Menlo-Bold", size: 11,
                         color: SKColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1),
                         at: CGPoint(x: -W/2 + 64, y: 14))
        nameLbl.horizontalAlignmentMode = .left
        row.addChild(nameLbl)

        // Desc
        let descLbl = mk(def.desc, font: "Menlo", size: 9,
                         color: SKColor(white: 0.52, alpha: 1),
                         at: CGPoint(x: -W/2 + 64, y: 1))
        descLbl.horizontalAlignmentMode = .left
        row.addChild(descLbl)

        // Level pips
        for i in 0..<def.costs.count {
            let pip = SKShapeNode(circleOfRadius: 4.5)
            pip.fillColor   = SKColor(white: 0.22, alpha: 1)
            pip.strokeColor = .clear
            pip.position    = CGPoint(x: -W/2 + 64 + CGFloat(i) * 13, y: -12)
            pip.name        = "pip_\(def.type.rawValue)_\(i)"
            row.addChild(pip)
        }

        // Buy button
        let btn = SKShapeNode(rectOf: CGSize(width: 84, height: 30), cornerRadius: 6)
        btn.fillColor   = SKColor(red: 0.08, green: 0.26, blue: 0.08, alpha: 1)
        btn.strokeColor = SKColor(red: 0.20, green: 0.72, blue: 0.20, alpha: 0.80)
        btn.lineWidth   = 1.5
        btn.position    = CGPoint(x: W/2 - 56, y: 2)
        btn.name        = "btn_\(def.type.rawValue)"

        let btnLbl = mk("", font: "Menlo-Bold", size: 10,
                        color: SKColor(red: 0.30, green: 1.00, blue: 0.30, alpha: 1), at: .zero)
        btnLbl.verticalAlignmentMode = .center
        btnLbl.name = "btnlbl_\(def.type.rawValue)"
        btn.addChild(btnLbl)
        row.addChild(btn)

        return row
    }

    // MARK: - Refresh

    func refresh(points: Int, levels: [UpgradeType: Int]) {
        pointsLabel.text = "⚡ \(points) EVOLUTION POINT\(points == 1 ? "" : "S")"

        for def in EvolutionPanelNode.defs {
            let lvl    = levels[def.type] ?? 0
            let maxLvl = def.costs.count
            let cost   = lvl < maxLvl ? def.costs[lvl] : 0
            let maxed  = lvl >= maxLvl
            let canBuy = !maxed && points >= cost

            for i in 0..<maxLvl {
                if let pip = childNode(withName: "//pip_\(def.type.rawValue)_\(i)") as? SKShapeNode {
                    pip.fillColor = i < lvl
                        ? SKColor(red: 0.15, green: 0.90, blue: 0.15, alpha: 1)
                        : SKColor(white: 0.22, alpha: 1)
                }
            }

            if let btn = childNode(withName: "//btn_\(def.type.rawValue)") as? SKShapeNode,
               let bl  = childNode(withName: "//btnlbl_\(def.type.rawValue)") as? SKLabelNode {
                if maxed {
                    btn.fillColor   = SKColor(white: 0.10, alpha: 1)
                    btn.strokeColor = SKColor(white: 0.22, alpha: 0.35)
                    bl.text = "MAXED"; bl.fontColor = SKColor(white: 0.32, alpha: 1)
                } else {
                    btn.fillColor   = canBuy
                        ? SKColor(red: 0.08, green: 0.26, blue: 0.08, alpha: 1)
                        : SKColor(red: 0.18, green: 0.08, blue: 0.08, alpha: 1)
                    btn.strokeColor = canBuy
                        ? SKColor(red: 0.20, green: 0.72, blue: 0.20, alpha: 0.80)
                        : SKColor(red: 0.50, green: 0.12, blue: 0.12, alpha: 0.60)
                    bl.text      = "⚡\(cost) UP"
                    bl.fontColor = canBuy
                        ? SKColor(red: 0.30, green: 1.00, blue: 0.30, alpha: 1)
                        : SKColor(white: 0.30, alpha: 1)
                }
            }
        }
    }

    // MARK: - Touch

    func handleTouch(at camPt: CGPoint) {
        // contains() takes a point in the node's *parent* coordinate space.
        // close is a direct child of self, so camPt (panel space) is already correct.
        if let close = childNode(withName: "evo_close") {
            if close.contains(camPt) { onClose?(); return }
        }
        // Buy buttons are grandchildren (panel → row → btn), so convert camPt
        // into each row's local space before calling contains on the button.
        for def in EvolutionPanelNode.defs {
            if let btn = childNode(withName: "//btn_\(def.type.rawValue)"),
               let row = btn.parent {
                let rowPt = row.convert(camPt, from: self)
                if btn.contains(rowPt) { onBuy?(def.type); return }
            }
        }
    }

    // MARK: - Helpers

    private func mk(_ text: String, font: String, size: CGFloat,
                    color: SKColor, at pos: CGPoint) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: font)
        l.text = text; l.fontSize = size; l.fontColor = color
        l.horizontalAlignmentMode = .center; l.verticalAlignmentMode = .baseline
        l.position = pos; return l
    }

    private func hline(y: CGFloat) -> SKShapeNode {
        let s = SKShapeNode(); let p = CGMutablePath()
        p.move(to: CGPoint(x: -W/2 + 18, y: y)); p.addLine(to: CGPoint(x: W/2 - 18, y: y))
        s.path = p; s.strokeColor = SKColor(white: 0.28, alpha: 0.55); s.lineWidth = 1; return s
    }
}
