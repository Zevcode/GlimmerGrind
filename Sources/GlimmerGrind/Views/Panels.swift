import SwiftUI

// MARK: - Fireteam

struct FireteamPanel: View {
    let game: Game

    private var ownedCount: Int { game.team.filter { $0.level > 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Fireteam", tag: "\(ownedCount) / 12")

            HStack(spacing: 2) {
                buyChip("×1", .one)
                buyChip("×10", .ten)
                buyChip("×100", .hundred)
                buyChip("MAX", .max)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) { Pal.rail.frame(height: 1) }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(GameData.guardians.enumerated()), id: \.offset) { index, def in
                        GuardianRow(game: game, index: index, def: def)
                    }
                }
            }
        }
        .panel()
    }

    private func buyChip(_ label: String, _ amount: BuyAmount) -> some View {
        let selected = game.buyAmount == amount
        return Button { game.buyAmount = amount } label: {
            Text(label)
                .font(.data(10))
                .tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(selected ? Pal.solar : Pal.plate)
                .foregroundStyle(selected ? Color(hex: 0x12060A) : Pal.ash)
        }
        .buttonStyle(.plain)
    }
}

struct GuardianRow: View {
    let game: Game
    let index: Int
    let def: GameData.GuardianDef

    private var unit: UnitState { game.team[index] }
    private var count: Int { game.buyCount(index) }
    private var cost: Double { game.unitCost(index, count: count) }
    private var affordable: Bool { game.glimmer >= cost }

    var body: some View {
        VStack(spacing: 0) {
            Button { game.buy(index) } label: {
                HStack(spacing: 9) {
                    ClassGlyphView(glyph: def.glyph)
                        .frame(width: 34, height: 34)
                        .padding(7)
                        .background(Chamfer(cut: 7).fill(Pal.plate))
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(def.name)
                                .font(.display(12.5, .semibold))
                                .foregroundStyle(unit.level > 0 ? Pal.bone : Pal.dim)
                            if unit.level > 0 {
                                Text("Lv \(unit.level)" + (unit.upgrades > 0 ? " ✦\(unit.upgrades)" : ""))
                                    .font(.data(10))
                                    .foregroundStyle(Pal.solar)
                            }
                        }
                        Text(unit.level > 0 ? "\(Fmt.n(game.unitDPS(index))) dps" : def.role)
                            .font(.data(9.5))
                            .foregroundStyle(Pal.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Fmt.n(cost))
                            .font(.display(11.5, .semibold))
                            .foregroundStyle(affordable ? Pal.ok : Pal.glimmer)
                            .monospacedDigit()
                        Text("×\(count)").hudLabel()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(affordable || unit.level > 0 ? 1 : 0.55)

            if let threshold = game.upgradeThreshold(index), unit.level > 0 {
                let reached = unit.level >= threshold
                let enabled = game.canUpgrade(index)
                HStack {
                    Button { game.upgrade(index) } label: {
                        Text(reached
                             ? "✦ DOUBLE DPS · \(Fmt.n(game.upgradeCost(index)))"
                             : "Unlocks at Lv \(threshold)")
                            .font(.data(9.5))
                            .tracking(0.6)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(enabled ? Pal.solar.opacity(0.13) : Pal.dim.opacity(0.12))
                            .foregroundStyle(enabled ? Pal.solar : Pal.dim)
                            .overlay(Rectangle().stroke(
                                enabled ? Pal.solar.opacity(0.3) : Pal.dim.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    Spacer()
                }
                .padding(.leading, 53)
                .padding(.bottom, 9)
            }

            Pal.rail.opacity(0.5).frame(height: 1)
        }
    }
}

// MARK: - Gear

struct GearPanel: View {
    let game: Game
    @Binding var sheet: ActiveSheet?

    private var equippedCount: Int {
        GameData.SlotKind.allCases.filter { game.gear[$0] != nil }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Loadout", tag: "\(equippedCount) / 8 equipped")

            HStack(spacing: 12) {
                Text("\(game.light)")
                    .font(.display(34, .bold))
                    .foregroundStyle(Pal.gold)
                    .monospacedDigit()
                    .shadow(color: Pal.gold.opacity(0.3), radius: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Light Level").hudLabel()
                    Text(String(format: "×%.2f damage", game.lightMult))
                        .font(.display(12, .semibold))
                        .foregroundStyle(Pal.solar)
                }
                Spacer()
            }
            .padding(12)
            .overlay(alignment: .bottom) { Pal.rail.frame(height: 1) }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)],
                      spacing: 1) {
                ForEach(GameData.SlotKind.allCases, id: \.self) { slot in
                    SlotTile(game: game, slot: slot, sheet: $sheet)
                }
            }
            .background(Pal.rail)
            .overlay(alignment: .bottom) { Pal.rail.frame(height: 1) }

            HStack(spacing: 6) {
                Text("Postmaster")
                    .font(.display(10.5, .bold))
                    .tracking(2)
                    .textCase(.uppercase)
                Text("\(game.postmaster.count) held")
                    .font(.data(9.5))
                    .foregroundStyle(Pal.dim)
                Spacer()
                Button { game.dismantleAll() } label: {
                    Text("Dismantle All")
                        .font(.data(9))
                        .tracking(0.8)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Pal.plate)
                        .foregroundStyle(Pal.ash)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) { Pal.rail.frame(height: 1) }

            if game.postmaster.isEmpty {
                VStack(spacing: 4) {
                    Text("No engrams held.")
                    Text("Enemies drop loot · bosses always do.")
                }
                .font(.data(10))
                .tracking(1)
                .foregroundStyle(Pal.dim)
                .multilineTextAlignment(.center)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(game.postmaster) { item in
                            DropRow(game: game, item: item, sheet: $sheet)
                        }
                    }
                }
            }
        }
        .panel()
    }
}

struct SlotTile: View {
    let game: Game
    let slot: GameData.SlotKind
    @Binding var sheet: ActiveSheet?

    var body: some View {
        let item = game.gear[slot]
        Button {
            if let item { sheet = .item(item, fromPostmaster: false) }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(slot.label).hudLabel()
                Text(item?.name ?? "Empty")
                    .font(.display(11.5, .semibold))
                    .foregroundStyle(item.map { Color(hex: $0.rarityDef.hex) } ?? Pal.dim)
                    .lineLimit(1)
                Text(item.map { "\($0.power) · \($0.type)" } ?? "—")
                    .font(.data(10))
                    .foregroundStyle(Pal.ash)
            }
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(Pal.hull)
            .overlay(alignment: .leading) {
                (item.map { Color(hex: $0.rarityDef.hex) } ?? .clear).frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DropRow: View {
    let game: Game
    let item: Item
    @Binding var sheet: ActiveSheet?

    var body: some View {
        let current = game.gear[item.slot]
        let delta = item.power - (current?.power ?? 0)

        Button { sheet = .item(item, fromPostmaster: true) } label: {
            HStack(spacing: 9) {
                EngramView(rarity: item.rarity, size: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.display(11.5, .semibold))
                        .foregroundStyle(Color(hex: item.rarityDef.hex))
                        .lineLimit(1)
                    Text("\(item.slot.label) · \(item.rarityDef.name)")
                        .font(.data(9))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Pal.dim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(item.power)")
                        .font(.display(13, .semibold))
                        .monospacedDigit()
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.data(9.5))
                        .foregroundStyle(delta > 0 ? Pal.ok : Pal.dim)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Pal.hull)
            .overlay(alignment: .leading) { Color(hex: item.rarityDef.hex).frame(width: 2) }
            .overlay(alignment: .bottom) { Pal.rail.opacity(0.5).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared header

struct PanelHeader: View {
    let title: String
    var tag: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.display(11.5, .bold))
                .tracking(2.2)
                .textCase(.uppercase)
            Spacer()
            if let tag {
                Text(tag)
                    .font(.data(9.5))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Pal.dim)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(LinearGradient(colors: [Pal.plate, .clear], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { Pal.rail.frame(height: 1) }
    }
}
