// Headless tests for the game engine.
//
// Model/ has no SwiftUI dependency, so the whole simulation runs in a CLI.
// Run with ./run-tests.sh — exits non-zero on any failure.
//
// Note: these use an explicit `check` rather than `assert`, because assert is
// compiled out under -O and would silently pass everything.

import Foundation

var passed = 0
var failed = 0

func check(_ label: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition {
        passed += 1
        print("  ✓ \(label)")
    } else {
        failed += 1
        let d = detail()
        print("  ✗ \(label)" + (d.isEmpty ? "" : " — \(d)"))
    }
}

func section(_ name: String) { print("\n\(name)") }

@MainActor
func stocked(_ units: Int = 5, glimmer: Double = 1e9) -> Game {
    let g = Game()
    g.wipeSave()
    g.glimmer = glimmer
    g.buyAmount = .hundred
    for i in 0..<units { g.buy(i) }
    return g
}

@MainActor
func runTests() {

    section("Progression curve")
    do {
        let g = stocked(0)
        let h1 = g.enemyMaxHP(1, boss: false)
        let h50 = g.enemyMaxHP(50, boss: false)
        let h100 = g.enemyMaxHP(100, boss: false)
        check("HP climbs monotonically", h1 < h50 && h50 < h100, "\(h1) / \(h50) / \(h100)")
        check("bosses are tougher than trash",
              g.enemyMaxHP(20, boss: true) > g.enemyMaxHP(20, boss: false))
        check("glimmer scales with sector",
              g.glimmerReward(40, boss: false) > g.glimmerReward(10, boss: false))
        check("no shards below sector 100", g.shardsFor(99) == 0)
        check("shards accrue past 100", g.shardsFor(150) > g.shardsFor(120))
    }

    section("Participation gates progression")
    do {
        let idle = stocked()
        let start = idle.zone
        idle.glimmer = 0
        for _ in 0..<1200 { idle.tick(0.05) }   // 60s untouched
        check("idle does not advance the sector", idle.zone == start,
              "reached \(idle.zone)")
        check("idle still earns glimmer", idle.glimmer > 0, "\(Fmt.n(idle.glimmer))")
        check("idle still kills", idle.stats.kills > 0, "\(Int(idle.stats.kills))")

        let auto = stocked()
        auto.subclass = .arc                     // +2 auto-shots per second
        let autoStart = auto.zone
        for _ in 0..<1200 { auto.tick(0.05) }
        check("auto-shots fire", auto.stats.clicks > 0, "\(Int(auto.stats.clicks))")
        check("auto-shots do not advance the sector", auto.zone == autoStart,
              "reached \(auto.zone)")

        let active = stocked()
        let activeStart = active.zone
        for _ in 0..<400 { active.fire(); active.tick(0.05) }
        check("manual fire advances", active.zone > activeStart,
              "reached \(active.zone)")

        let assist = stocked(6)
        let before = assist.killsInZone
        assist.fire()                            // tag, let the fireteam finish
        for _ in 0..<60 { assist.tick(0.05) }
        check("a tagged kill counts even if the team finishes it",
              assist.killsInZone > before || assist.zone > 1)

        let abil = stocked()
        let abilBefore = abil.killsInZone
        abil.use(.grenade)
        for _ in 0..<20 { abil.tick(0.05) }
        check("abilities count as participation",
              abil.killsInZone > abilBefore || abil.zone > 1)
    }

    section("Precision and momentum")
    do {
        let g = stocked()
        // A drifting weak point must never leave the sigil.
        var moved = false
        let origin = g.weakPoint
        var maxRadius = 0.0
        for _ in 0..<1000 {
            g.tick(0.05)
            let r = (g.weakPoint.x * g.weakPoint.x + g.weakPoint.y * g.weakPoint.y).squareRoot()
            maxRadius = Swift.max(maxRadius, r)
            if g.weakPoint != origin { moved = true }
        }
        check("weak point drifts", moved)
        check("weak point stays on the sigil", maxRadius <= 0.801,
              String(format: "reached %.3f", maxRadius))

        // Isolate the multiplier: pin momentum at cap so it cannot skew the ramp.
        func meanDamage(precision: Bool) -> Double {
            let t = stocked()
            t.zone = 60
            t.spawn()
            t.enemy?.champion = nil
            t.enemy?.shielded = false
            t.momentum = GameData.momentumCap
            let before = t.stats.damage
            for _ in 0..<400 { t.momentum = GameData.momentumCap; t.fire(precision: precision) }
            return (t.stats.damage - before) / 400
        }
        let ratio = meanDamage(precision: true) / meanDamage(precision: false)
        check("precision multiplier is a real bonus", ratio > 1.5,
              String(format: "%.2fx", ratio))

        let m = stocked()
        m.momentum = 0
        for _ in 0..<3 { m.fire() }
        check("momentum builds on hits", m.momentum >= 3, "\(m.momentum)")
        for _ in 0..<50 { m.fire() }
        check("momentum caps", m.momentum == GameData.momentumCap, "\(m.momentum)")
        let boosted = m.clickDamage
        for _ in 0..<200 { m.tick(0.05) }   // 10s without firing
        check("momentum decays when you stop", m.momentum == 0, "\(m.momentum)")
        check("decayed momentum lowers damage", m.clickDamage < boosted)

        let auto = stocked()
        auto.momentum = 0
        for _ in 0..<5 { auto.fire(manual: false) }
        check("auto-shots build no momentum", auto.momentum == 0, "\(auto.momentum)")
    }

    section("Champions")
    do {
        let early = stocked()
        var earlyChampions = 0
        for _ in 0..<400 { early.zone = 3; early.spawn(); if early.enemy?.champion != nil { earlyChampions += 1 } }
        check("no champions before sector 8", earlyChampions == 0, "\(earlyChampions) seen")

        let late = stocked()
        var lateChampions = 0
        for _ in 0..<600 { late.zone = 12; late.spawn(); if late.enemy?.champion != nil { lateChampions += 1 } }
        check("champions appear past sector 8", lateChampions > 0, "\(lateChampions) in 600")

        let boss = stocked()
        boss.zone = 20; boss.spawn()
        check("bosses below 25 are not champions", boss.enemy?.champion == nil)
        boss.zone = 25; boss.spawn()
        check("bosses from 25 are champions", boss.enemy?.champion != nil)

        // Shield blunts damage until the right ability lands.
        func shieldedGame(_ kind: GameData.ChampionKind) -> Game {
            let g = stocked()
            g.zone = 12
            g.spawn()
            g.enemy?.champion = kind
            g.enemy?.shielded = true
            g.enemy?.hp = 1e18
            g.enemy?.maxHP = 1e18
            return g
        }

        let sh = shieldedGame(.overload)
        let hpBefore = sh.enemy!.hp
        sh.fire()
        let shieldedHit = hpBefore - sh.enemy!.hp
        sh.enemy?.shielded = false
        sh.enemy?.shieldTimer = 8
        let hpMid = sh.enemy!.hp
        sh.fire()
        let brokenHit = hpMid - sh.enemy!.hp
        check("a held shield blunts damage", brokenHit > shieldedHit * 5,
              String(format: "%.0f vs %.0f", shieldedHit, brokenHit))

        let wrong = shieldedGame(.overload)
        wrong.use(.melee)                       // Overload does not yield to melee
        check("the wrong ability does not break the shield", wrong.enemy?.shielded == true)

        let right = shieldedGame(.overload)
        right.use(.grenade)                     // Overload yields to grenades
        check("the matching ability breaks the shield", right.enemy?.shielded == false)

        let unstoppable = shieldedGame(.unstoppable)
        unstoppable.use(.melee)
        check("Unstoppable yields to melee", unstoppable.enemy?.shielded == false)

        let barrier = shieldedGame(.barrier)
        barrier.use(.classAbility)
        check("Barrier yields to the class ability", barrier.enemy?.shielded == false)

        var superBreaksAll = true
        for kind in GameData.ChampionKind.allCases {
            let g = shieldedGame(kind)
            g.superEnergy = 100
            g.use(.superAbility)
            if g.enemy?.shielded != false { superBreaksAll = false }
        }
        check("Super breaks every champion kind", superBreaksAll)

        // The shield re-forms when the window closes.
        let reform = shieldedGame(.overload)
        reform.use(.grenade)
        for _ in 0..<Int(GameData.shieldBreakWindow / 0.05) + 10 { reform.tick(0.05) }
        check("the shield re-forms after the window", reform.enemy?.shielded == true)
    }

    section("Weakened")
    do {
        let g = stocked()
        g.zone = 40
        g.spawn()
        g.enemy?.champion = nil
        g.enemy?.hp = 1e18
        g.enemy?.maxHP = 1e18
        g.momentum = GameData.momentumCap

        var plain = 0.0
        for _ in 0..<200 { g.momentum = GameData.momentumCap
            let b = g.enemy!.hp; g.fire(); plain += b - g.enemy!.hp }

        g.enemy?.weakened = GameData.weakenedDuration
        var weak = 0.0
        for _ in 0..<200 { g.momentum = GameData.momentumCap
            let b = g.enemy!.hp; g.fire(); weak += b - g.enemy!.hp }

        check("Weakened raises damage taken", weak > plain * 1.1,
              String(format: "%.0f vs %.0f", plain, weak))
        for _ in 0..<Int(GameData.weakenedDuration / 0.05) + 10 { g.tick(0.05) }
        check("Weakened expires", (g.enemy?.weakened ?? 0) == 0)
    }

    section("Fireteam")
    do {
        let g = stocked(0, glimmer: 1e6)
        check("no DPS before hiring", g.fireteamDPS == 0)
        g.buyAmount = .ten
        g.buy(0)
        check("hiring produces DPS", g.fireteamDPS > 0, "\(Fmt.n(g.fireteamDPS))")
        let before = g.fireteamDPS
        g.glimmer = 1e12
        g.buy(0)
        check("more levels means more DPS", g.fireteamDPS > before)
        check("cost rises with level", g.unitCost(0, count: 1) > GameData.guardians[0].cost)
    }

    section("Loot")
    do {
        let g = stocked(0)
        var seen = Set<Int>()
        var malformed = 0
        for _ in 0..<6000 {
            let item = g.rollItem(zone: 50, boss: true, luck: 0.5)
            seen.insert(item.rarity)
            if item.power <= 0 || item.perks.count != GameData.rarities[item.rarity].perkCount {
                malformed += 1
            }
        }
        check("every rarity is reachable", seen.count == GameData.rarities.count,
              "saw \(seen.count)")
        check("no malformed rolls", malformed == 0, "\(malformed) bad")

        let dmgBefore = g.clickDamage
        for slot in GameData.SlotKind.allCases {
            g.equip(Item(slot: slot, type: "T", name: "T", rarity: 3, power: 600, perks: []))
        }
        check("Light is the average of equipped power", g.light == 600, "got \(g.light)")
        check("Light raises damage", g.clickDamage > dmgBefore)
    }

    section("Abilities")
    do {
        let g = stocked()
        check("super starts locked", !g.canUse(.superAbility))
        g.superEnergy = 100
        check("super unlocks when charged", g.canUse(.superAbility))
        g.use(.superAbility)
        // The cast zeroes the bar, but the kill it lands immediately feeds some
        // back — so assert it can no longer be cast, not that it reads zero.
        check("super spends its energy", !g.canUse(.superAbility) && g.superEnergy < 100,
              "left at \(g.superEnergy)")
        check("super leaves a buff", !g.buffs.isEmpty)
        g.use(.grenade)
        check("grenade goes on cooldown", g.cooldownRemaining(.grenade) > 0)
        check("grenade is locked while cooling", !g.canUse(.grenade))
        for _ in 0..<400 { g.tick(0.05) }
        check("cooldowns expire", g.cooldownRemaining(.grenade) == 0)
        check("buffs expire", g.buffs.isEmpty)
    }

    section("Prestige")
    do {
        let g = stocked()
        g.zone = 150
        g.runBest = 150
        g.best = 150          // normally set by advance(); we jumped the sector
        let gain = g.pendingShards
        check("reset is worth shards at 150", gain > 0, "\(gain)")
        g.resetLight()
        check("shards are banked", g.shards == gain)
        check("fireteam is disbanded", g.team.allSatisfy { $0.level == 0 })
        check("gear is vaulted", g.gear.isEmpty)
        check("run restarts", g.zone < 150)
        check("lifetime best survives", g.best >= 150)
    }

    section("Persistence")
    do {
        let g = stocked()
        g.zone = 42
        g.glimmer = 12345
        g.shards = 7
        g.save()

        let reloaded = Game()
        check("sector round-trips", reloaded.zone == 42, "got \(reloaded.zone)")
        check("glimmer round-trips", reloaded.glimmer >= 12345, "got \(reloaded.glimmer)")
        check("shards round-trip", reloaded.shards == 7, "got \(reloaded.shards)")
        reloaded.wipeSave()
        check("wipe clears the save", Game().zone == 1)

        // Combat state is session-only; letting it into SaveState would break
        // every existing save on disk.
        let probe = SaveState(zone: 1, kills: 0, glimmer: 0, shards: 0, shardPerks: [:],
                              stats: Stats(), best: 1, runBest: 1, team: [], gear: [:],
                              postmaster: [], subclass: .solar, superEnergy: 0, lastSeen: Date())
        let json = String(data: try! JSONEncoder().encode(probe), encoding: .utf8) ?? ""
        let leaked = ["champion", "shielded", "weakPoint", "momentum", "weakened"]
            .filter { json.contains($0) }
        check("no combat state leaked into the save format", leaked.isEmpty,
              "leaked \(leaked)")
    }

    print("\n\(passed) passed, \(failed) failed")
    exit(failed == 0 ? 0 : 1)
}

@main
struct EngineTests {
    static func main() {
        MainActor.assumeIsolated { runTests() }
    }
}
