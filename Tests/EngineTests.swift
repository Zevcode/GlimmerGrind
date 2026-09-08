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
