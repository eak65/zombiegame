import SpriteKit

enum ZombieType: String, CaseIterable {
    case standard, hunter, brute, screamer, stalker, spitter
}

struct ZombieTypeData {
    let type:            ZombieType
    let name:            String
    let emoji:           String
    let description:     String
    let unlockCost:      Int
    let speedMult:       CGFloat   // multiplied by base AI speed
    let hpMult:          CGFloat   // multiplied by CharacterNode.maxHP at spawn
    let tankDmgPerSec:   CGFloat   // damage per second to tanks while in swarm range
    let infectionMult:   CGFloat   // conversion time multiplier (< 1 = faster)
    let biteRadiusBonus: CGFloat   // added to scene's base biteRadius

    static let all: [ZombieTypeData] = [
        .init(type: .standard, name: "STANDARD",
              emoji: "🧟", description: "Default strain",
              unlockCost: 0,
              speedMult: 1.00, hpMult: 1.00, tankDmgPerSec: 2,
              infectionMult: 1.00, biteRadiusBonus: 0),
        .init(type: .hunter, name: "HUNTER",
              emoji: "🐺", description: "Fast · tough · destroys tanks",
              unlockCost: 4,
              speedMult: 1.50, hpMult: 1.50, tankDmgPerSec: 14,
              infectionMult: 1.00, biteRadiusBonus: 8),
        .init(type: .brute, name: "BRUTE",
              emoji: "👹", description: "Massive HP · slow · wide bite",
              unlockCost: 3,
              speedMult: 0.60, hpMult: 3.50, tankDmgPerSec: 5,
              infectionMult: 1.00, biteRadiusBonus: 18),
        .init(type: .screamer, name: "SCREAMER",
              emoji: "👻", description: "Converts civilians 60% faster",
              unlockCost: 3,
              speedMult: 1.20, hpMult: 0.65, tankDmgPerSec: 1,
              infectionMult: 0.40, biteRadiusBonus: 0),
        .init(type: .stalker, name: "STALKER",
              emoji: "🦎", description: "Extreme speed · very fragile",
              unlockCost: 3,
              speedMult: 1.90, hpMult: 0.50, tankDmgPerSec: 1,
              infectionMult: 1.00, biteRadiusBonus: 0),
        .init(type: .spitter, name: "SPITTER",
              emoji: "🤢", description: "Long bite range · infects faster",
              unlockCost: 3,
              speedMult: 1.00, hpMult: 0.85, tankDmgPerSec: 1,
              infectionMult: 0.65, biteRadiusBonus: 28),
    ]

    static func info(for t: ZombieType) -> ZombieTypeData {
        all.first { $0.type == t }!
    }
}
