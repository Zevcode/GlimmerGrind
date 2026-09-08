import SwiftUI

struct SheetHost: View {
    let game: Game
    let active: ActiveSheet
    @Binding var sheet: ActiveSheet?

    var body: some View {
        Group {
            switch active {
            case .item(let item, let fromPostmaster):
                ItemSheet(game: game, item: item, fromPostmaster: fromPostmaster, sheet: $sheet)
            case .subclass:
                SubclassSheet(game: game, sheet: $sheet)
            case .resetLight:
                ResetSheet(game: game, sheet: $sheet)
            case .record:
                RecordSheet(game: game, sheet: $sheet)
            case .bounties:
                BountiesSheet(game: game, sheet: $sheet)
            }
        }
        .frame(minWidth: 420, idealWidth: 560, minHeight: 320)
        .background(Pal.hull)
        .foregroundStyle(Pal.bone)
    }
}

struct SheetChromePublic<Content: View, Footer: View>: View {
    let title: String
    @Binding var sheet: ActiveSheet?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.display(15, .bold))
                    .tracking(2.4)
                    .textCase(.uppercase)
                Spacer()
                Button { sheet = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Pal.ash)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(LinearGradient(colors: [Pal.plate, .clear], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { Pal.rail.frame(height: 1) }

            ScrollView {
                content.padding(18)
            }

            footer
        }
    }
}

// MARK: - Item

struct ItemSheet: View {
    let game: Game
    let item: Item
    let fromPostmaster: Bool
    @Binding var sheet: ActiveSheet?

    var body: some View {
        SheetChromePublic(title: fromPostmaster ? "Engram Decrypted" : "Equipped", sheet: $sheet) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    EngramView(rarity: item.rarity, size: 58)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.display(19, .bold))
                            .foregroundStyle(Color(hex: item.rarityDef.hex))
                        Text("\(item.rarityDef.name) \(item.type) · \(item.slot.label)")
                            .font(.data(10))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Pal.ash)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(item.power)")
                            .font(.display(27, .bold))
                            .monospacedDigit()
                        Text("Power").hudLabel()
                    }
                }
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) { Pal.rail.frame(height: 1) }

                ForEach(item.perks, id: \.self) { perk in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(perk.name)
                            .font(.display(12.5, .semibold))
                            .frame(width: 150, alignment: .leading)
                        Text("\(perk.negative ? "−" : "+")\(fmtValue(perk.value))% \(perk.desc)")
                            .font(.data(11))
                            .foregroundStyle(Pal.solar)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) { Pal.rail.opacity(0.45).frame(height: 1) }
                }

                if item.canHaveCatalyst {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.hasCatalyst ? "Catalyst complete" : "Catalyst")
                                .font(.data(10)).tracking(1.6).textCase(.uppercase)
                                .foregroundStyle(item.hasCatalyst ? Pal.gold : Pal.dim)
                            Spacer()
                            if !item.hasCatalyst {
                                Text("\(Int(item.catalystProgress)) / \(Int(GameData.catalystThreshold)) kills")
                                    .font(.data(10)).foregroundStyle(Pal.ash).monospacedDigit()
                            }
                        }
                        if let cat = item.catalystPerk {
                            HStack(spacing: 10) {
                                Text("◆ \(cat.name)").font(.display(12.5, .semibold))
                                    .foregroundStyle(Pal.gold)
                                Text("+\(fmtValue(cat.value))% \(cat.desc)")
                                    .font(.data(11)).foregroundStyle(Pal.solar)
                                Spacer()
                            }
                        } else {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Pal.plate
                                    Rectangle().fill(Pal.gold.opacity(0.8))
                                        .frame(width: geo.size.width
                                               * min(1, item.catalystProgress / GameData.catalystThreshold))
                                }
                                .overlay(Rectangle().stroke(Pal.rail, lineWidth: 1))
                            }
                            .frame(height: 6)
                        }
                    }
                    .padding(.top, 4)
                }

                if let current = game.gear[item.slot], current.id != item.id {
                    let delta = item.power - current.power
                    Text("Currently equipped: \(current.name) · \(current.power) power (\(delta > 0 ? "+" : "")\(delta)) · \(current.perks.map(\.name).joined(separator: ", "))")
                        .font(.data(10.5))
                        .foregroundStyle(Pal.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } footer: {
            HStack(spacing: 8) {
                if fromPostmaster {
                    Button("Equip") {
                        game.equip(item)
                        sheet = nil
                    }
                    .buttonStyle(HudButtonStyle(hot: true))
                    .frame(maxWidth: .infinity)

                    Button("Dismantle · +\(Fmt.n(item.rarityDef.shards * Double(game.zone))) glimmer") {
                        game.dismantle(item)
                        sheet = nil
                    }
                    .buttonStyle(HudButtonStyle())
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Close") { sheet = nil }
                        .buttonStyle(HudButtonStyle(ghost: true))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .overlay(alignment: .top) { Pal.rail.frame(height: 1) }
        }
    }

    private func fmtValue(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - Subclass

struct SubclassSheet: View {
    let game: Game
    @Binding var sheet: ActiveSheet?

    var body: some View {
        SheetChromePublic(title: "Subclass", sheet: $sheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reattune your Light. Swapping is free and instant — your abilities and passive change with it.")
                    .font(.body)
                    .foregroundStyle(Pal.ash)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(GameData.Subclass.allCases, id: \.self) { key in
                        let def = GameData.subclasses[key]!
                        let selected = game.subclass == key
                        Button {
                            game.subclass = key
                            game.addLog("Attuned to <\(def.name)> — \(def.passive)")
                            sheet = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Circle()
                                    .fill(Color(hex: def.hex))
                                    .frame(width: 20, height: 20)
                                    .padding(.bottom, 2)
                                Text(def.name)
                                    .font(.display(13.5, .bold))
                                    .tracking(1.5)
                                    .textCase(.uppercase)
                                Text(def.passive)
                                    .font(.data(10))
                                    .foregroundStyle(Pal.ash)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(def.superName) · \(def.grenade)")
                                    .font(.data(10))
                                    .foregroundStyle(Pal.dim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Chamfer().fill(selected ? Pal.plateHi : Pal.plate))
                            .overlay(Chamfer().stroke(
                                selected ? Color(hex: def.hex) : .clear, lineWidth: 1))
                            .contentShape(Chamfer())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } footer: { EmptyView() }
    }
}

// MARK: - Reset Light

struct ResetSheet: View {
    let game: Game
    @Binding var sheet: ActiveSheet?

    var body: some View {
        SheetChromePublic(title: "Reset Light", sheet: $sheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Give your Light back to the Traveler. Fireteam, gear and glimmer are lost; Legendary Shards and everything bought with them are kept forever.")
                    .font(.body)
                    .foregroundStyle(Pal.ash)
                    .fixedSize(horizontal: false, vertical: true)

                StatGrid(pairs: [
                    ("Deepest sector this run", "\(game.runBest)", Pal.bone),
                    ("Shards on reset", "\(game.pendingShards)", Pal.shard),
                    ("Shards banked", "\(game.shards)", Pal.bone),
                    ("Resets", "\(game.stats.resets)", Pal.bone)
                ])

                Text("Shard Upgrades").hudLabel()

                VStack(spacing: 1) {
                    ForEach(GameData.shardPerks, id: \.id) { def in
                        let rank = game.shardRank(def.id)
                        let cost = def.cost(rank)
                        let maxed = rank >= def.max
                        Button { game.buyShardPerk(def) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(def.name)
                                        .font(.display(13, .semibold))
                                    Text(def.desc)
                                        .font(.data(10.5))
                                        .foregroundStyle(Pal.ash)
                                }
                                Spacer()
                                Text("\(rank) / \(def.max)")
                                    .font(.data(10))
                                    .tracking(1)
                                    .foregroundStyle(Pal.dim)
                                Text(maxed ? "MAX" : "\(cost) ◈")
                                    .font(.display(14, .semibold))
                                    .foregroundStyle(Pal.shard)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Pal.hull)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(maxed || game.shards < cost)
                        .opacity(maxed || game.shards < cost ? 0.4 : 1)
                    }
                }
                .background(Pal.rail)
            }
        } footer: {
            HStack(spacing: 8) {
                Button(game.pendingShards > 0
                       ? "Reset for \(game.pendingShards) shards"
                       : "Reach Sector 100 to reset") {
                    game.resetLight()
                    sheet = nil
                }
                .buttonStyle(HudButtonStyle(hot: game.pendingShards > 0))
                .disabled(game.pendingShards == 0)
                .frame(maxWidth: .infinity)

                Button("Keep going") { sheet = nil }
                    .buttonStyle(HudButtonStyle(ghost: true))
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .overlay(alignment: .top) { Pal.rail.frame(height: 1) }
        }
    }
}

// MARK: - Record

struct RecordSheet: View {
    let game: Game
    @Binding var sheet: ActiveSheet?
    @State private var confirmWipe = false

    var body: some View {
        SheetChromePublic(title: "Vanguard Record", sheet: $sheet) {
            VStack(alignment: .leading, spacing: 16) {
                StatGrid(pairs: [
                    ("Deepest sector", "\(game.best)", Pal.bone),
                    ("Enemies killed", Fmt.n(game.stats.kills), Pal.bone),
                    ("Bosses down", Fmt.n(game.stats.bosses), Pal.bone),
                    ("Shots fired", Fmt.n(game.stats.clicks), Pal.bone),
                    ("Engrams decrypted", Fmt.n(game.stats.drops), Pal.bone),
                    ("Total damage", Fmt.n(game.stats.damage), Pal.solar)
                ])

                Text("Progress saves automatically. Idle damage keeps running while the app is closed — the Postmaster holds your glimmer for up to 4 hours.")
                    .font(.body)
                    .foregroundStyle(Pal.ash)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Keys — Space: fire · Q: grenade · E: melee · C: class ability · R: super")
                    .font(.data(10.5))
                    .foregroundStyle(Pal.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            HStack(spacing: 8) {
                Button(confirmWipe ? "Tap again to confirm" : "Delete save") {
                    if confirmWipe {
                        game.wipeSave()
                        sheet = nil
                    } else {
                        confirmWipe = true
                    }
                }
                .buttonStyle(HudButtonStyle(ghost: !confirmWipe))
                .foregroundStyle(confirmWipe ? Pal.bad : Pal.bone)

                Spacer()

                Button("Close") { sheet = nil }
                    .buttonStyle(HudButtonStyle())
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .overlay(alignment: .top) { Pal.rail.frame(height: 1) }
        }
    }
}

// MARK: - Stat grid

struct StatGrid: View {
    let pairs: [(String, String, Color)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)],
                  spacing: 1) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                VStack(alignment: .leading, spacing: 1) {
                    Text(pair.0).hudLabel()
                    Text(pair.1)
                        .font(.display(15, .semibold))
                        .foregroundStyle(pair.2)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Pal.hull)
            }
        }
        .background(Pal.rail)
    }
}


// MARK: - Bounties

struct BountiesSheet: View {
    let game: Game
    @Binding var sheet: ActiveSheet?

    var body: some View {
        SheetChromePublic(title: "Bounties", sheet: $sheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Three at a time. Claim a completed bounty and another is issued.")
                    .font(.body)
                    .foregroundStyle(Pal.ash)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(game.bounties) { bounty in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(bounty.kind.label)
                                .font(.display(13, .semibold))
                            Spacer()
                            Text("\(Int(min(bounty.progress, bounty.target))) / \(Int(bounty.target))")
                                .font(.data(10.5))
                                .monospacedDigit()
                                .foregroundStyle(bounty.complete ? Pal.ok : Pal.ash)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Pal.plate
                                Rectangle()
                                    .fill(bounty.complete ? Pal.ok : Pal.solar)
                                    .frame(width: geo.size.width * bounty.fraction)
                            }
                            .overlay(Rectangle().stroke(Pal.rail, lineWidth: 1))
                        }
                        .frame(height: 6)

                        HStack {
                            Text("+\(Fmt.n(bounty.rewardGlimmer)) glimmer"
                                 + (bounty.rewardShards > 0 ? "  ·  +\(bounty.rewardShards) ◈" : ""))
                                .font(.data(10))
                                .foregroundStyle(bounty.rewardShards > 0 ? Pal.shard : Pal.glimmer)
                            Spacer()
                            if bounty.complete {
                                Button("Claim") { game.claimBounty(bounty.id) }
                                    .buttonStyle(HudButtonStyle(hot: true))
                            }
                        }
                    }
                    .padding(12)
                    .background(Pal.hull)
                    .overlay(Rectangle().stroke(
                        bounty.complete ? Pal.ok.opacity(0.5) : Pal.rail, lineWidth: 1))
                }
            }
        } footer: {
            EmptyView()
        }
    }
}
