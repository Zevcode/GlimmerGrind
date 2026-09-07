import Foundation

// MARK: - Destinations

struct Area {
    let name: String
    let faction: Faction
    let sub: String
    let hex: UInt32
}

enum Faction: String, Codable, CaseIterable {
    case fallen = "Fallen"
    case cabal = "Cabal"
    case hive = "Hive"
    case vex = "Vex"
    case taken = "Taken"
    case scorn = "Scorn"
}

enum GameData {

    static let areas: [Area] = [
        Area(name: "Cosmodrome",          faction: .fallen, sub: "House of Dusk",        hex: 0x6E9BD8),
        Area(name: "European Dead Zone",  faction: .cabal,  sub: "Red Legion Remnant",   hex: 0xE0574F),
        Area(name: "Luna",                faction: .hive,   sub: "Hidden Swarm",         hex: 0x9FD16A),
        Area(name: "Nessus",              faction: .vex,    sub: "Sol Divisive",         hex: 0xD9C24F),
        Area(name: "The Dreaming City",   faction: .taken,  sub: "Riven's Brood",        hex: 0xB366E8),
        Area(name: "Tangled Shore",       faction: .scorn,  sub: "Barons of the Reef",   hex: 0xE0709A),
        Area(name: "Europa",              faction: .fallen, sub: "House of Salvation",   hex: 0x7FD8FF),
        Area(name: "Neomuna",             faction: .vex,    sub: "Radial Mind",          hex: 0x7A7BF0)
    ]

    static let enemies: [Faction: [String]] = [
        .fallen: ["Dreg", "Vandal", "Marauder", "Captain", "Shank", "Servitor"],
        .cabal:  ["Legionary", "Psion", "Incendior", "Centurion", "Gladiator", "Colossus"],
        .hive:   ["Thrall", "Acolyte", "Cursed Thrall", "Knight", "Wizard", "Ogre"],
        .vex:    ["Goblin", "Harpy", "Hobgoblin", "Minotaur", "Cyclops", "Hydra"],
        .taken:  ["Taken Thrall", "Taken Psion", "Taken Vandal", "Taken Phalanx", "Taken Knight", "Taken Centurion"],
        .scorn:  ["Screeb", "Stalker", "Ravager", "Abomination", "Chieftain", "Wraith"]
    ]

    static let bossNames: [Faction: [String]] = [
        .fallen: ["Vokaal", "Rekkis", "Draksis", "Yavik", "Skaarn", "Thaviks"],
        .cabal:  ["Bracus Val", "Thumos", "Gaunt", "Ozletc", "Karrun", "Mekris"],
        .hive:   ["Alzok", "Kranox", "Hashladun", "Navota", "Zulmak", "Xortal"],
        .vex:    ["Praetorian", "Zydron", "Sekrion", "Qodron", "Brakion", "Hezen"],
        .taken:  ["Kelgorath", "Nurizel", "Tha'lam", "Ur Haask", "Malok", "Sedia"],
        .scorn:  ["Hiraks", "Elykris", "Kaniks", "Reksis", "Pirrha", "Yaviks"]
    ]

    static let bossTitles: [Faction: [String]] = [
        .fallen: ["Baron of Splinters", "the Splicer Priest", "Kell of the Dusk", "Archon Reborn"],
        .cabal:  ["the Siege Engine", "Blood Guard Primus", "the Unbroken", "War Beast Handler"],
        .hive:   ["the Bone Collector", "Wizard of Sorrow", "Deathsinger's Voice", "the Blighted"],
        .vex:    ["Axis Mind", "the Gate Lord", "Precursor Construct", "Undying Mind"],
        .taken:  ["the Cursed", "Blight Herald", "the Ascendant", "Voice of Riven"],
        .scorn:  ["the Rider", "Mad Bomber", "Machinist of Bone", "the Rifleman"]
    ]

    static let enemyPrefixes = ["Splinter", "Fell", "Wretched", "Blighted", "Rift", "Hollow", "Ashen", "Torn"]

    // MARK: - Fireteam

    struct GuardianDef {
        let name: String
        let role: String
        let cost: Double
        let dps: Double
        let glyph: ClassGlyph
    }

    enum ClassGlyph: String, Codable { case titan, hunter, warlock, shell }

    static let guardians: [GuardianDef] = [
        .init(name: "Ghost Shell",    role: "Little Light",     cost: 8,      dps: 0.6,     glyph: .shell),
        .init(name: "New Light",      role: "Rookie Guardian",  cost: 60,     dps: 5,       glyph: .hunter),
        .init(name: "Gunslinger",     role: "Solar Hunter",     cost: 520,    dps: 32,      glyph: .hunter),
        .init(name: "Sentinel",       role: "Void Titan",       cost: 4_200,  dps: 190,     glyph: .titan),
        .init(name: "Stormcaller",    role: "Arc Warlock",      cost: 26_000, dps: 940,     glyph: .warlock),
        .init(name: "Nightstalker",   role: "Void Hunter",      cost: 1.6e5,  dps: 5_000,   glyph: .hunter),
        .init(name: "Dawnblade",      role: "Solar Warlock",    cost: 1.1e6,  dps: 2.7e4,   glyph: .warlock),
        .init(name: "Sunbreaker",     role: "Solar Titan",      cost: 8e6,    dps: 1.5e5,   glyph: .titan),
        .init(name: "Arcstrider",     role: "Arc Hunter",       cost: 6.5e7,  dps: 9e5,     glyph: .hunter),
        .init(name: "Voidwalker",     role: "Void Warlock",     cost: 5.5e8,  dps: 5.5e6,   glyph: .warlock),
        .init(name: "Vanguard Scout", role: "Veteran Operator", cost: 5e9,    dps: 3.4e7,   glyph: .titan),
        .init(name: "Iron Lord",      role: "Risen Legend",     cost: 5e10,   dps: 2.2e8,   glyph: .shell)
    ]

    static let upgradeTiers = [10, 25, 50, 100, 175, 300]

    // MARK: - Subclasses

    struct SubclassDef {
        let name: String
        let hex: UInt32
        let grenade: String
        let melee: String
        let classAbility: String
        let superName: String
        let passive: String
    }

    enum Subclass: String, Codable, CaseIterable { case solar, arc, void }

    static let subclasses: [Subclass: SubclassDef] = [
        .solar: .init(name: "Solar", hex: 0xFF8A3D, grenade: "Fusion Grenade", melee: "Knife Trick",
                      classAbility: "Healing Rift", superName: "Golden Gun",
                      passive: "Radiant: +30% weapon damage"),
        .arc:   .init(name: "Arc", hex: 0x7FD8FF, grenade: "Pulse Grenade", melee: "Ball Lightning",
                      classAbility: "Towering Barricade", superName: "Fists of Havoc",
                      passive: "Amplified: +2 auto-shots per second"),
        .void:  .init(name: "Void", hex: 0xB366E8, grenade: "Vortex Grenade", melee: "Shield Bash",
                      classAbility: "Marksman Dodge", superName: "Nova Bomb",
                      passive: "Devour: +45% glimmer from kills")
    ]

    // MARK: - Gear

    enum SlotKind: String, Codable, CaseIterable {
        case kinetic, energy, power, helmet, arms, chest, legs, mark

        var label: String {
            switch self {
            case .kinetic: return "Kinetic"
            case .energy:  return "Energy"
            case .power:   return "Power"
            case .helmet:  return "Helmet"
            case .arms:    return "Gauntlets"
            case .chest:   return "Chest"
            case .legs:    return "Legs"
            case .mark:    return "Class Item"
            }
        }

        var isWeapon: Bool {
            switch self {
            case .kinetic, .energy, .power: return true
            default: return false
            }
        }
    }

    struct RarityDef {
        let name: String
        let hex: UInt32
        let weight: Double
        let perkCount: Int
        let mult: Double
        let powerBonus: Int
        let shards: Double
    }

    static let rarities: [RarityDef] = [
        .init(name: "Common",    hex: 0xB5AEA6, weight: 44,  perkCount: 1, mult: 1.00, powerBonus: 0,  shards: 2),
        .init(name: "Uncommon",  hex: 0x6FBE5A, weight: 29,  perkCount: 1, mult: 1.45, powerBonus: 4,  shards: 5),
        .init(name: "Rare",      hex: 0x5A8FE0, weight: 18,  perkCount: 2, mult: 1.95, powerBonus: 9,  shards: 12),
        .init(name: "Legendary", hex: 0xB366E8, weight: 7.5, perkCount: 2, mult: 2.70, powerBonus: 16, shards: 30),
        .init(name: "Exotic",    hex: 0xEFD84E, weight: 1.5, perkCount: 3, mult: 3.80, powerBonus: 26, shards: 80)
    ]

    enum PerkKey: String, Codable {
        case click, critChance, critDamage, bossDamage, abilityDamage
        case teamDamage, glimmer, superEnergy, cooldown, luck
    }

    struct PerkDef {
        let key: PerkKey
        let name: String
        let desc: String
        let base: Double
        let negative: Bool
    }

    static let weaponPerks: [PerkDef] = [
        .init(key: .click,         name: "Rangefinder",   desc: "weapon damage",  base: 7,  negative: false),
        .init(key: .critChance,    name: "Outlaw",        desc: "critical chance", base: 1.8, negative: false),
        .init(key: .critDamage,    name: "Firefly",       desc: "critical damage", base: 16, negative: false),
        .init(key: .bossDamage,    name: "Vorpal Weapon", desc: "boss damage",    base: 11, negative: false),
        .init(key: .abilityDamage, name: "Demolitionist", desc: "ability damage", base: 12, negative: false)
    ]

    static let armorPerks: [PerkDef] = [
        .init(key: .teamDamage,  name: "Bountiful Wells", desc: "fireteam damage",  base: 6,  negative: false),
        .init(key: .glimmer,     name: "Reaper",          desc: "glimmer",          base: 10, negative: false),
        .init(key: .superEnergy, name: "Ashes to Assets", desc: "super energy",     base: 13, negative: false),
        .init(key: .cooldown,    name: "Distribution",    desc: "ability cooldown", base: 4,  negative: true),
        .init(key: .luck,        name: "Prime Focus",     desc: "rare drop weight", base: 7,  negative: false)
    ]

    static let weaponTypes: [SlotKind: [String]] = [
        .kinetic: ["Hand Cannon", "Pulse Rifle", "Scout Rifle", "Auto Rifle", "Sidearm", "Combat Bow"],
        .energy:  ["Submachine Gun", "Fusion Rifle", "Trace Rifle", "Glaive", "Shotgun", "Sniper Rifle"],
        .power:   ["Rocket Launcher", "Linear Fusion", "Sword", "Machine Gun", "Grenade Launcher"]
    ]

    static let adjectives = ["Ashen", "Null", "Iron", "Solemn", "Radiant", "Gilded", "Umbral", "Severed",
                             "Quiet", "Ninth", "Tarnished", "Distant", "Hollow", "Waking", "Sunless",
                             "Vagrant", "Steadfast", "Crooked"]

    static let nouns = ["Verdict", "Refrain", "Compass", "Vow", "Reprisal", "Doctrine", "Lament",
                        "Ascension", "Requiem", "Bargain", "Testimony", "Curfew", "Threnody", "Reverie"]

    static let epithets = ["the Ninth Circle", "Quiet Stars", "Ashen Wake", "the Long Watch", "Broken Suns",
                           "the Undying", "Cold Dawn", "Silent Fathoms", "the Deep Stone", "Fading Light"]

    static let armorWords: [SlotKind: [String]] = [
        .helmet: ["Helm", "Mask", "Cowl", "Visor"],
        .arms:   ["Gauntlets", "Grips", "Gloves", "Bracers"],
        .chest:  ["Plate", "Vest", "Robes", "Harness"],
        .legs:   ["Greaves", "Strides", "Boots", "Treads"],
        .mark:   ["Mark", "Cloak", "Bond", "Sigil"]
    ]

    // MARK: - Shard perks

    struct ShardPerkDef {
        let id: String
        let name: String
        let desc: String
        let max: Int
        let cost: (Int) -> Int
    }

    static let shardPerks: [ShardPerkDef] = [
        .init(id: "attune",    name: "Light Attunement",   desc: "+12% all damage per rank",         max: 50, cost: { 1 + $0 }),
        .init(id: "marksman",  name: "Marksman Protocol",  desc: "+30% weapon damage per rank",      max: 25, cost: { 1 + $0 * 2 }),
        .init(id: "contracts", name: "Glimmer Contracts",  desc: "+25% glimmer per rank",            max: 25, cost: { 1 + $0 * 2 }),
        .init(id: "ordnance",  name: "Ordnance Tuning",    desc: "-4% ability cooldowns per rank",   max: 10, cost: { 2 + $0 * 3 }),
        .init(id: "focus",     name: "Prime Engram Focus", desc: "+9% rare drop weight per rank",    max: 10, cost: { 3 + $0 * 4 }),
        .init(id: "auto",      name: "Auto-Loader",        desc: "+1 auto-shot per second per rank", max: 10, cost: { 5 + $0 * 6 }),
        .init(id: "sparrow",   name: "Sparrow Boost",      desc: "Start 5 sectors higher per rank",  max: 15, cost: { 4 + $0 * 5 })
    ]
}

// MARK: - Number formatting

enum Fmt {
    static let suffixes = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd"]

    static func n(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        if value < 0 { return "-" + n(-value) }
        if value < 1000 {
            return value < 10 ? String(format: "%.1f", value) : String(Int(value))
        }
        var v = value
        var tier = 0
        while v >= 1000 && tier < suffixes.count - 1 { v /= 1000; tier += 1 }
        if v >= 1000 { return String(format: "%.2e", v) }
        let body: String
        if v < 10 { body = String(format: "%.2f", v) }
        else if v < 100 { body = String(format: "%.1f", v) }
        else { body = String(Int(v)) }
        return body + suffixes[tier]
    }

    static func duration(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        return m > 0 ? "\(m)m \(Int(seconds.truncatingRemainder(dividingBy: 60)))s" : "\(Int(seconds))s"
    }
}

// MARK: - Seeded RNG (stable boss names per sector)

struct Mulberry: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(truncatingIfNeeded: seed) &+ 0x9E3779B9 }

    mutating func next() -> UInt64 {
        state = state &+ 0x6D2B79F5
        var z = state
        z = (z ^ (z >> 15)) &* (1 | z)
        z = z &+ ((z ^ (z >> 7)) &* (61 | z))
        return z ^ (z >> 14)
    }
}
