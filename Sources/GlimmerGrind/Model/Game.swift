import Foundation
import CoreGraphics
import Observation

// MARK: - Persisted value types

struct Perk: Codable, Hashable {
    var key: GameData.PerkKey
    var name: String
    var desc: String
    var value: Double
    var negative: Bool
}

struct Item: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var slot: GameData.SlotKind
    var type: String
    var name: String
    var rarity: Int
    var power: Int
    var perks: [Perk]

    var rarityDef: GameData.RarityDef { GameData.rarities[rarity] }
}

struct UnitState: Codable {
    var level: Int = 0
    var upgrades: Int = 0
}

struct Stats: Codable {
    var clicks: Double = 0
    var kills: Double = 0
    var drops: Double = 0
    var bosses: Double = 0
    var resets: Int = 0
    var damage: Double = 0
}

/// A ticker line. Repeats collapse into a count rather than stacking — a
/// boss timer expiring on a loop should read as "×3", not fill the log.
struct LogEntry: Identifiable {
    let id = UUID()
    var text: String
    var count: Int = 1
}

struct Buff: Identifiable {
    enum Kind { case all, click }
    let id = UUID()
    var kind: Kind
    var value: Double
    var remaining: Double
    var name: String
}

struct SaveState: Codable {
    var zone: Int
    var kills: Int
    var glimmer: Double
    var shards: Int
    var shardPerks: [String: Int]
    var stats: Stats
    var best: Int
    var runBest: Int
    var team: [UnitState]
    var gear: [GameData.SlotKind: Item]
    var postmaster: [Item]
    var subclass: GameData.Subclass
    var superEnergy: Double
    var lastSeen: Date
}

enum BuyAmount: Hashable { case one, ten, hundred, max }

// MARK: - Live enemy

struct Enemy {
    var hp: Double
    var maxHP: Double
    var isBoss: Bool
    var name: String
    var rank: String
    var area: Area
    var timer: Double
    /// Set the moment you land a shot or an ability on this target.
    /// Sectors only advance on kills you took part in — the fireteam farms,
    /// but it does not push the front line on its own.
    var playerHit: Bool = false

    /// Champions hold a shield that only the matching ability (or a Super)
    /// will break. nil for ordinary contacts.
    var champion: GameData.ChampionKind?
    var shielded: Bool = false
    /// Seconds left in the break window; the shield re-forms at zero.
    var shieldTimer: Double = 0
    /// Seconds left of Weakened, applied by grenades.
    var weakened: Double = 0
}

// MARK: - Damage popups

struct Popup: Identifiable {
    enum Kind { case hit, crit, ability, precision }
    let id = UUID()
    var text: String
    var kind: Kind
    var x: Double
    var y: Double
    var born: Date = Date()
}

// MARK: - The game

@MainActor
@Observable
final class Game {

    // persisted
    var zone: Int = 1
    var killsInZone: Int = 0
    var glimmer: Double = 0
    var shards: Int = 0
    var shardPerks: [String: Int] = [:]
    var stats = Stats()
    var best: Int = 1
    var runBest: Int = 1
    var team: [UnitState] = GameData.guardians.map { _ in UnitState() }
    var gear: [GameData.SlotKind: Item] = [:]
    var postmaster: [Item] = []
    var subclass: GameData.Subclass = .solar
    var superEnergy: Double = 0
    var lastSeen: Date = Date()

    // session
    var enemy: Enemy?
    var cooldowns: [String: Double] = ["grenade": 0, "melee": 0, "class": 0]
    var buffs: [Buff] = []
    var buyAmount: BuyAmount = .one
    var log: [LogEntry] = []
    var popups: [Popup] = []
    var toast: String?
    var hitPulse: Double = 0
    var flashColor: UInt32?

    /// Weak point drifting across the sigil, in normalised [-1, 1] sigil space.
    var weakPoint: CGPoint = .zero
    private var weakVelocity: CGPoint = .zero

    /// Stacks of sustained fire. Builds on every player hit, decays when you stop.
    var momentum: Int = 0
    private var momentumDecay: Double = 0

    private var autoAccumulator: Double = 0
    private var toastExpiry: Date = .distantPast
    private var lastIdleNotice: Date = .distantPast

    private static let saveKey = "glimmer-grind-save-v1"

    init() {
        if !load() {
            spawn()
            addLog("Ghost online. Hostiles inbound in the <Cosmodrome>.")
            addLog("Sectors advance only on kills you <join>. The fireteam farms glimmer while you idle.")
        }
    }

    // MARK: - Derived

    var area: Area { GameData.areas[((zone - 1) / 5) % GameData.areas.count] }
    var isBossZone: Bool { zone % 5 == 0 }
    var sub: GameData.SubclassDef { GameData.subclasses[subclass]! }

    func enemyMaxHP(_ z: Int, boss: Bool) -> Double {
        let base = 10 * (Double(z) - 1 + pow(1.55, Double(z) - 1))
        return base * (boss ? 9 : 1)
    }

    func glimmerReward(_ z: Int, boss: Bool) -> Double {
        enemyMaxHP(z, boss: false) / 14 * (boss ? 7 : 1) * glimmerMult
    }

    func gearStat(_ key: GameData.PerkKey) -> Double {
        var total: Double = 0
        for slot in GameData.SlotKind.allCases {
            guard let item = gear[slot] else { continue }
            for perk in item.perks where perk.key == key { total += perk.value }
        }
        return total
    }

    var light: Int {
        let sum = GameData.SlotKind.allCases.reduce(0) { $0 + (gear[$1]?.power ?? 0) }
        return sum / GameData.SlotKind.allCases.count
    }

    var lightMult: Double { 1 + Double(light) * 0.016 }

    func shardRank(_ id: String) -> Int { shardPerks[id] ?? 0 }

    var globalMult: Double {
        var m = lightMult * (1 + 0.12 * Double(shardRank("attune")))
        for buff in buffs where buff.kind == .all { m *= buff.value }
        return m
    }

    var fireteamDPS: Double {
        var raw: Double = 0
        for (i, unit) in team.enumerated() where unit.level > 0 {
            raw += GameData.guardians[i].dps * Double(unit.level) * pow(2, Double(unit.upgrades))
        }
        raw *= 1 + gearStat(.teamDamage) / 100
        return raw * globalMult
    }

    func unitDPS(_ index: Int) -> Double {
        let unit = team[index]
        guard unit.level > 0 else { return 0 }
        return GameData.guardians[index].dps * Double(unit.level) * pow(2, Double(unit.upgrades))
            * (1 + gearStat(.teamDamage) / 100) * globalMult
    }

    var clickDamage: Double {
        let base = 2 + fireteamDPS * (0.055 + 0.01 * Double(shardRank("auto")))
        var m = (1 + gearStat(.click) / 100) * (1 + 0.30 * Double(shardRank("marksman")))
        m *= 1 + GameData.momentumPerStack * Double(momentum)
        if subclass == .solar { m *= 1.3 }
        for buff in buffs where buff.kind == .click { m *= buff.value }
        return base * m * globalMult
    }

    var critChance: Double { min(0.75, 0.05 + gearStat(.critChance) / 100) }
    var critMult: Double { 2 + gearStat(.critDamage) / 100 }

    var glimmerMult: Double {
        var m = (1 + gearStat(.glimmer) / 100) * (1 + 0.25 * Double(shardRank("contracts")))
        if subclass == .void { m *= 1.45 }
        return m
    }

    var cooldownMult: Double {
        max(0.3, 1 - gearStat(.cooldown) / 100 - 0.04 * Double(shardRank("ordnance")))
    }

    var abilityMult: Double { 1 + gearStat(.abilityDamage) / 100 }
    var bossMult: Double { 1 + gearStat(.bossDamage) / 100 }
    var autoShots: Double { Double(shardRank("auto")) + (subclass == .arc ? 2 : 0) }

    func shardsFor(_ z: Int) -> Int {
        z < 100 ? 0 : Int(pow((Double(z) - 90) / 10, 1.8))
    }

    var pendingShards: Int { shardsFor(runBest) }

    /// True once you have hit the current target — i.e. this kill will count.
    var engaged: Bool { enemy?.playerHit ?? false }

    var grenadeDamage: Double { (fireteamDPS * 11 + clickDamage * 22) * abilityMult }
    var meleeDamage: Double { (fireteamDPS * 4.5 + clickDamage * 11) * abilityMult }

    // MARK: - Spawning

    func spawn() {
        let boss = isBossZone
        let a = area
        var rng = Mulberry(seed: zone * 7919 + killsInZone * 31 + (boss ? 13 : 0))

        let name: String
        let rank: String
        if boss {
            let base = GameData.bossNames[a.faction]!.randomElement(using: &rng)!
            let title = GameData.bossTitles[a.faction]!.randomElement(using: &rng)!
            name = "\(base), \(title)"
            rank = "Ultra — \(a.faction.rawValue)"
        } else {
            let base = GameData.enemies[a.faction]!.randomElement(using: &rng)!
            rank = base
            name = "\(GameData.enemyPrefixes.randomElement(using: &rng)!) \(base)"
        }

        // Champions: bosses from sector 25 (stable per sector via the seeded
        // generator), ordinary contacts from sector 8 at 12%.
        var champion: GameData.ChampionKind?
        if boss {
            if zone >= 25 { champion = GameData.ChampionKind.allCases.randomElement(using: &rng) }
        } else if zone >= 8, Double.random(in: 0...1) < 0.12 {
            champion = GameData.ChampionKind.allCases.randomElement()
        }

        var hp = enemyMaxHP(zone, boss: boss)
        var finalRank = rank
        if let champion {
            // Bosses already carry a 9x multiplier; stacking champion HP on top
            // of that made them unkillable inside the 30s timer. The shield is
            // the difficulty for a boss champion, not extra health.
            if !boss { hp *= GameData.championHPMultiplier }
            finalRank = "\(champion.label) Champion"
        }

        // The name is the character — "Kelgorath, the Cursed" survives being a
        // champion. The badge and rank carry the champion identity instead.
        enemy = Enemy(hp: hp, maxHP: hp, isBoss: boss, name: name, rank: finalRank,
                      area: a, timer: boss ? 30 : 0,
                      champion: champion, shielded: champion != nil)
        seedWeakPoint()
    }

    /// Re-seeds the drifting weak point for a fresh target.
    private func seedWeakPoint() {
        let angle = Double.random(in: 0..<(2 * .pi))
        let speed = Double.random(in: 0.25...0.45)
        weakPoint = CGPoint(x: Double.random(in: -0.4...0.4), y: Double.random(in: -0.4...0.4))
        weakVelocity = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
    }

    // MARK: - Combat

    func damage(_ amount: Double, popup: Popup.Kind?, at point: (Double, Double)? = nil,
                fromPlayer: Bool = false) {
        guard var e = enemy else { return }
        var dealt = amount
        if e.isBoss { dealt *= bossMult }
        if e.champion != nil {
            // A held shield blunts everything, including the fireteam — which is
            // exactly the pressure: a Champion left to idle DPS stalls.
            dealt *= e.shielded ? GameData.shieldedDamageMultiplier
                                : GameData.brokenDamageMultiplier
        }
        if e.weakened > 0 { dealt *= GameData.weakenedMultiplier }
        e.hp -= dealt
        if fromPlayer { e.playerHit = true }
        stats.damage += dealt
        enemy = e

        if let kind = popup {
            let p = point ?? (Double.random(in: -70...70), Double.random(in: -20...20))
            popups.append(Popup(text: Fmt.n(dealt), kind: kind, x: p.0, y: p.1))
            if popups.count > 24 { popups.removeFirst(popups.count - 24) }
        }
        if e.hp <= 0 { kill() }
    }

    private func kill() {
        guard let e = enemy else { return }
        let boss = e.isBoss

        glimmer += glimmerReward(zone, boss: boss)
        stats.kills += 1
        superEnergy = min(100, superEnergy + (boss ? 22 : 3.2) * (1 + gearStat(.superEnergy) / 100))

        let luck = (gearStat(.luck) + 9 * Double(shardRank("focus"))) / 100
        if boss || Double.random(in: 0...1) < 0.14 {
            stats.drops += 1
            addDrop(rollItem(zone: zone, boss: boss, luck: luck))
        }

        // The fireteam farms on its own, but the front line only moves on kills
        // you took part in. An uncredited kill still pays out — it just respawns.
        guard e.playerHit else {
            if Date().timeIntervalSince(lastIdleNotice) > 25 {
                lastIdleNotice = Date()
                addLog("Idle kill — glimmer only. <Fire on a target> to advance the sector.")
            }
            spawn()
            return
        }

        if boss {
            stats.bosses += 1
            addLog("<Sector \(zone)> cleared — \(e.name) down.")
            advance()
        } else {
            killsInZone += 1
            if killsInZone >= 10 { killsInZone = 0; advance() } else { spawn() }
        }
    }

    private func advance() {
        zone += 1
        killsInZone = 0
        best = Swift.max(best, zone)
        runBest = Swift.max(runBest, zone)
        if zone % 5 == 1 {
            addLog("Transmat to <\(area.name)> — \(area.faction.rawValue) contact.")
        }
        spawn()
    }

    private func bossFail() {
        if enemy?.playerHit == true {
            addLog("Fireteam wiped. Regrouping at Sector \(zone).")
            showToast("Wipe — boss reset")
        }
        spawn()
    }

    /// `manual` is you pulling the trigger. Auto-shots from Arc or Auto-Loader
    /// deal damage and earn glimmer, but they do not count as participation —
    /// advancing a sector is something you do, not something you buy.
    func fire(at point: (Double, Double)? = nil, manual: Bool = true, precision: Bool = false) {
        guard enemy != nil else { return }
        var dmg = clickDamage
        if precision { dmg *= GameData.precisionMultiplier }
        let crit = Double.random(in: 0...1) < critChance
        if crit { dmg *= critMult }
        stats.clicks += 1
        superEnergy = min(100, superEnergy
                          + (precision ? 0.75 : 0.25) * (1 + gearStat(.superEnergy) / 100))

        // Momentum rewards sustained fire, which is what the participation rule
        // now asks for. Auto-shots deal damage but never build it.
        if manual {
            momentum = Swift.min(GameData.momentumCap, momentum + (precision ? 2 : 1))
            momentumDecay = 0
        }

        hitPulse = 1
        let kind: Popup.Kind = precision ? .precision : (crit ? .crit : .hit)
        damage(dmg, popup: kind, at: point, fromPlayer: manual)
    }

    /// Does this ability bring down the current Champion's shield?
    func breaksShield(_ ability: Ability) -> Bool {
        guard let e = enemy, let kind = e.champion, e.shielded else { return false }
        return ability == .superAbility || ability.rawValue == kind.breakerRaw
    }

    private func applyShieldBreak(_ ability: Ability) {
        guard var e = enemy, let kind = e.champion, e.shielded else { return }
        guard ability == .superAbility || ability.rawValue == kind.breakerRaw else { return }
        e.shielded = false
        e.shieldTimer = GameData.shieldBreakWindow
        enemy = e
        addLog("<\(kind.label)> shield broken — \(Int(GameData.shieldBreakWindow))s window.")
        showToast("\(kind.label) broken")
    }

    // MARK: - Abilities

    enum Ability: String { case grenade, melee, classAbility = "class", superAbility }

    func cooldownRemaining(_ ability: Ability) -> Double {
        cooldowns[ability.rawValue] ?? 0
    }

    func cooldownLength(_ ability: Ability) -> Double {
        switch ability {
        case .grenade: return 18 * cooldownMult
        case .melee: return 10 * cooldownMult
        case .classAbility: return 32 * cooldownMult
        case .superAbility: return 1
        }
    }

    func canUse(_ ability: Ability) -> Bool {
        ability == .superAbility ? superEnergy >= 100 : cooldownRemaining(ability) <= 0
    }

    func use(_ ability: Ability) {
        guard canUse(ability), enemy != nil else { return }
        switch ability {
        case .grenade:
            cooldowns["grenade"] = cooldownLength(.grenade)
            applyShieldBreak(.grenade)
            damage(grenadeDamage, popup: .ability, fromPlayer: true)
            if var e = enemy { e.weakened = GameData.weakenedDuration; enemy = e }
            flash(sub.hex)
        case .melee:
            cooldowns["melee"] = cooldownLength(.melee)
            applyShieldBreak(.melee)
            damage(meleeDamage, popup: .ability, fromPlayer: true)
        case .classAbility:
            cooldowns["class"] = cooldownLength(.classAbility)
            applyShieldBreak(.classAbility)
            buffs.append(Buff(kind: .click, value: 2.2, remaining: 14, name: sub.classAbility))
            flash(sub.hex)
            addLog("<\(sub.classAbility)> deployed — 2.2× weapon damage for 14s.")
        case .superAbility:
            superEnergy = 0
            applyShieldBreak(.superAbility)
            let dmg = (fireteamDPS * 45 + clickDamage * 60) * abilityMult
            damage(dmg, popup: .ability, fromPlayer: true)
            buffs.append(Buff(kind: .all, value: 2.5, remaining: 9, name: sub.superName))
            flash(sub.hex)
            addLog("<\(sub.superName)> cast — \(Fmt.n(dmg)) damage, 2.5× for 9s.")
            showToast(sub.superName)
        }
    }

    // MARK: - Loot

    func rollItem(zone z: Int, boss: Bool, luck: Double) -> Item {
        let weights = GameData.rarities.enumerated().map { i, r -> Double in
            r.weight * (i >= 2 ? 1 + luck * Double(i - 1) : 1) * (boss && i >= 3 ? 2.2 : 1)
        }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0...total)
        var rarityIndex = 0
        for (i, w) in weights.enumerated() {
            roll -= w
            if roll <= 0 { rarityIndex = i; break }
        }

        let rarity = GameData.rarities[rarityIndex]
        let slot = GameData.SlotKind.allCases.randomElement()!
        let power = Swift.max(1, Int(
            Double(z) * 6.4 * Double.random(in: 0.92...1.12) + Double(rarity.powerBonus) + (boss ? Double(z) * 0.8 : 0)
        ))

        var pool = slot.isWeapon ? GameData.weaponPerks : GameData.armorPerks
        var perks: [Perk] = []
        for _ in 0..<rarity.perkCount {
            guard !pool.isEmpty else { break }
            let def = pool.remove(at: Int.random(in: 0..<pool.count))
            let value = (def.base * rarity.mult * Double.random(in: 0.80...1.25) * 10).rounded() / 10
            perks.append(Perk(key: def.key, name: def.name, desc: def.desc, value: value, negative: def.negative))
        }

        let name: String
        let type: String
        if slot.isWeapon {
            type = GameData.weaponTypes[slot]!.randomElement()!
            name = "\(GameData.adjectives.randomElement()!) \(GameData.nouns.randomElement()!)"
        } else {
            type = slot.label
            name = "\(GameData.armorWords[slot]!.randomElement()!) of \(GameData.epithets.randomElement()!)"
        }

        return Item(slot: slot, type: type, name: name, rarity: rarityIndex, power: power, perks: perks)
    }

    func addDrop(_ item: Item) {
        postmaster.insert(item, at: 0)
        while postmaster.count > 12 {
            let dropped = postmaster.removeLast()
            glimmer += dropped.rarityDef.shards * Double(zone)
        }
        if item.rarity >= 3 {
            addLog("<\(item.rarityDef.name)> engram decrypted: \(item.name)")
        }
    }

    func equip(_ item: Item) {
        let old = gear[item.slot]
        gear[item.slot] = item
        postmaster.removeAll { $0.id == item.id }
        if let old { glimmer += old.rarityDef.shards * Double(zone) }
        showToast("Equipped")
    }

    func dismantle(_ item: Item) {
        postmaster.removeAll { $0.id == item.id }
        glimmer += item.rarityDef.shards * Double(zone)
    }

    func dismantleAll() {
        guard !postmaster.isEmpty else { return }
        let total = postmaster.reduce(0) { $0 + $1.rarityDef.shards * Double(zone) }
        addLog("Dismantled \(postmaster.count) engrams for <\(Fmt.n(total)) glimmer>.")
        glimmer += total
        postmaster.removeAll()
    }

    // MARK: - Purchasing

    func unitCost(_ index: Int, count: Int) -> Double {
        let def = GameData.guardians[index]
        let owned = Double(team[index].level)
        return def.cost * pow(1.07, owned) * (pow(1.07, Double(count)) - 1) / 0.07
    }

    func maxAffordable(_ index: Int) -> Int {
        let def = GameData.guardians[index]
        let owned = Double(team[index].level)
        let unitPrice: Double = def.cost * pow(1.07, owned)
        guard unitPrice > 0 else { return 0 }
        let ratio: Double = (glimmer * 0.07) / unitPrice + 1.0
        guard ratio > 1 else { return 0 }
        let n: Double = Foundation.log(ratio) / Foundation.log(1.07)
        return Swift.max(0, Int(n))
    }

    func buyCount(_ index: Int) -> Int {
        switch buyAmount {
        case .one: return 1
        case .ten: return 10
        case .hundred: return 100
        case .max: return Swift.max(1, maxAffordable(index))
        }
    }

    func buy(_ index: Int) {
        var count = buyCount(index)
        var cost = unitCost(index, count: count)
        if cost > glimmer {
            count = 1
            cost = unitCost(index, count: 1)
            guard cost <= glimmer else { return }
        }
        glimmer -= cost
        let wasEmpty = team[index].level == 0
        team[index].level += count
        if wasEmpty { addLog("<\(GameData.guardians[index].name)> joined the fireteam.") }
    }

    func upgradeCost(_ index: Int) -> Double {
        GameData.guardians[index].cost * pow(14, Double(team[index].upgrades) + 1) * 4
    }

    func canUpgrade(_ index: Int) -> Bool {
        let tier = team[index].upgrades
        guard tier < GameData.upgradeTiers.count, team[index].level > 0 else { return false }
        return team[index].level >= GameData.upgradeTiers[tier] && glimmer >= upgradeCost(index)
    }

    func upgradeThreshold(_ index: Int) -> Int? {
        let tier = team[index].upgrades
        guard tier < GameData.upgradeTiers.count else { return nil }
        return GameData.upgradeTiers[tier]
    }

    func upgrade(_ index: Int) {
        guard canUpgrade(index) else { return }
        glimmer -= upgradeCost(index)
        team[index].upgrades += 1
        addLog("\(GameData.guardians[index].name) upgraded — damage doubled.")
    }

    func buyShardPerk(_ def: GameData.ShardPerkDef) {
        let rank = shardRank(def.id)
        let cost = def.cost(rank)
        guard rank < def.max, shards >= cost else { return }
        shards -= cost
        shardPerks[def.id] = rank + 1
    }

    // MARK: - Prestige

    func resetLight() {
        let gain = pendingShards
        guard gain > 0 else { return }
        let keptStats = stats
        let keptPerks = shardPerks
        let keptShards = shards + gain
        let keptBest = best
        let keptSub = subclass

        let start = 1 + 5 * (keptPerks["sparrow"] ?? 0)
        zone = start
        killsInZone = 0
        glimmer = 0
        shards = keptShards
        shardPerks = keptPerks
        stats = keptStats
        stats.resets += 1
        best = keptBest
        runBest = start
        team = GameData.guardians.map { _ in UnitState() }
        gear = [:]
        postmaster = []
        subclass = keptSub
        superEnergy = 0
        momentum = 0
        buffs = []
        cooldowns = ["grenade": 0, "melee": 0, "class": 0]

        spawn()
        showToast("+\(gain) Legendary Shards")
        addLog("Light reset. <\(gain)> shards banked. Fireteam disbanded, gear vaulted.")
        save()
    }

    // MARK: - Tick

    func tick(_ dt: Double) {
        let dps = fireteamDPS
        if enemy != nil && dps > 0 { damage(dps * dt, popup: nil) }

        let shots = autoShots
        if shots > 0 {
            autoAccumulator += dt * shots
            while autoAccumulator >= 1 {
                autoAccumulator -= 1
                if enemy != nil { fire(manual: false) }
            }
        }

        for key in cooldowns.keys where cooldowns[key]! > 0 {
            cooldowns[key] = Swift.max(0, cooldowns[key]! - dt)
        }

        if !buffs.isEmpty {
            for i in buffs.indices { buffs[i].remaining -= dt }
            buffs.removeAll { $0.remaining <= 0 }
        }

        if var e = enemy, e.isBoss {
            e.timer -= dt
            enemy = e
            if e.timer <= 0 { bossFail() }
        }

        if hitPulse > 0 { hitPulse = Swift.max(0, hitPulse - dt * 12) }

        driftWeakPoint(dt)

        if momentum > 0 {
            momentumDecay += dt
            if momentumDecay >= GameData.momentumDecayInterval {
                momentumDecay = 0
                momentum -= 1
            }
        }

        if var e = enemy {
            if e.champion != nil, !e.shielded {
                e.shieldTimer -= dt
                if e.shieldTimer <= 0 { e.shielded = true; e.shieldTimer = 0 }
            }
            if e.weakened > 0 { e.weakened = Swift.max(0, e.weakened - dt) }
            enemy = e
        }

        let now = Date()
        popups.removeAll { now.timeIntervalSince($0.born) > 0.95 }
        if toast != nil && now > toastExpiry { toast = nil }
    }

    /// Drifts the weak point and reflects it off a radius-0.8 circle so it
    /// always stays on the sigil.
    private func driftWeakPoint(_ dt: Double) {
        weakPoint.x += weakVelocity.x * dt
        weakPoint.y += weakVelocity.y * dt
        let r = (weakPoint.x * weakPoint.x + weakPoint.y * weakPoint.y).squareRoot()
        guard r > 0.8, r > 0 else { return }
        let nx = weakPoint.x / r, ny = weakPoint.y / r
        let dot = weakVelocity.x * nx + weakVelocity.y * ny
        weakVelocity.x -= 2 * dot * nx
        weakVelocity.y -= 2 * dot * ny
        weakPoint.x = nx * 0.8
        weakPoint.y = ny * 0.8
    }

    // MARK: - Log & toast

    func addLog(_ message: String) {
        if let first = log.first, first.text == message {
            log[0].count += 1
            return
        }
        log.insert(LogEntry(text: message), at: 0)
        if log.count > 14 { log.removeLast() }
    }

    func showToast(_ message: String) {
        toast = message
        toastExpiry = Date().addingTimeInterval(2.2)
    }

    private func flash(_ hex: UInt32) {
        flashColor = hex
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            flashColor = nil
        }
    }

    // MARK: - Persistence

    func save() {
        lastSeen = Date()
        let state = SaveState(
            zone: zone, kills: killsInZone, glimmer: glimmer, shards: shards,
            shardPerks: shardPerks, stats: stats, best: best, runBest: runBest,
            team: team, gear: gear, postmaster: postmaster, subclass: subclass,
            superEnergy: superEnergy, lastSeen: lastSeen
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    @discardableResult
    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let s = try? JSONDecoder().decode(SaveState.self, from: data) else { return false }
        zone = s.zone
        killsInZone = s.kills
        glimmer = s.glimmer
        shards = s.shards
        shardPerks = s.shardPerks
        stats = s.stats
        best = s.best
        runBest = Swift.max(s.runBest, s.zone)
        team = s.team.count == GameData.guardians.count ? s.team : GameData.guardians.map { _ in UnitState() }
        gear = s.gear
        postmaster = s.postmaster
        subclass = s.subclass
        superEnergy = s.superEnergy
        lastSeen = s.lastSeen
        spawn()
        addLog("Welcome back, Guardian. Sector <\(zone)>, \(area.name).")
        applyOfflineProgress()
        return true
    }

    func applyOfflineProgress() {
        let elapsed = Swift.min(Date().timeIntervalSince(lastSeen), 4 * 3600)
        guard elapsed > 60 else { return }
        let dps = fireteamDPS
        guard dps > 0 else { return }
        let perKill = enemyMaxHP(zone, boss: false)
        let kills = Swift.min(dps * elapsed / perKill, 1e6)
        let gain = kills * glimmerReward(zone, boss: false)
        guard gain >= 1 else { return }
        glimmer += gain
        addLog("Postmaster held <\(Fmt.n(gain)) glimmer> from \(Fmt.duration(elapsed)) of fireteam ops.")
        showToast("+\(Fmt.n(gain)) glimmer while away")
    }

    func wipeSave() {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
        zone = 1; killsInZone = 0; glimmer = 0; shards = 0; shardPerks = [:]
        stats = Stats(); best = 1; runBest = 1
        team = GameData.guardians.map { _ in UnitState() }
        gear = [:]; postmaster = []; subclass = .solar; superEnergy = 0
        momentum = 0
        buffs = []; cooldowns = ["grenade": 0, "melee": 0, "class": 0]
        log = []
        spawn()
        showToast("Save deleted")
    }
}
