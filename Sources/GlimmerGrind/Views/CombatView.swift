import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

/// Crits get a nudge in the hand on iPhone; silent everywhere else.
enum Haptics {
    static func crit() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        #endif
    }
}

struct CombatView: View {
    let game: Game
    var compact: Bool

    private var faction: Color { Color(hex: game.enemy?.area.hex ?? game.area.hex) }

    var body: some View {
        VStack(spacing: 10) {
            zoneBar
            viewport
            abilityBar
            ticker
        }
    }

    // MARK: - Zone bar

    private var zoneBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(game.zone)")
                    .font(.display(19, .bold))
                    .monospacedDigit()
                Text("Sector").hudLabel()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(game.area.name)
                    .font(.display(13, .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                Text("\(game.area.faction.rawValue) — \(game.area.sub)")
                    .font(.data(10))
                    .foregroundStyle(Pal.ash)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            creditChip
            pips
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .panel()
        .overlay(alignment: .leading) {
            faction.frame(width: 3)
                .animation(.easeInOut(duration: 1.2), value: faction)
        }
    }

    /// Says plainly whether this kill will move the front line.
    private var creditChip: some View {
        let on = game.engaged
        return Text(on ? "ENGAGED" : "IDLE · NO ADVANCE")
            .font(.data(9))
            .tracking(1.4)
            .foregroundStyle(on ? Pal.solar : Pal.dim)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay(Rectangle().stroke(on ? Pal.solar.opacity(0.5) : Pal.rail, lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: on)
    }

    private var pips: some View {
        HStack(spacing: 3) {
            if game.isBossZone {
                Text("BOSS")
                    .font(.data(9))
                    .tracking(1.6)
                    .foregroundStyle(Pal.bad)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(Rectangle().stroke(Pal.bad.opacity(0.55), lineWidth: 1))
            } else {
                ForEach(0..<10, id: \.self) { i in
                    Rectangle()
                        .fill(i < game.killsInZone ? Pal.solar : Pal.rail)
                        .frame(width: 11, height: 5)
                }
            }
        }
    }

    // MARK: - Viewport

    private var viewport: some View {
        GeometryReader { geo in
            ZStack {
                // faction wash + ember floor + vignette
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x1B1719), Pal.hull],
                                   startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [faction.opacity(0.20), .clear],
                                   center: .init(x: 0.5, y: 0.44),
                                   startRadius: 0, endRadius: geo.size.width * 0.55)
                    RadialGradient(colors: [Pal.ember.opacity(0.09), .clear],
                                   center: .init(x: 0.5, y: 1.18),
                                   startRadius: 0, endRadius: geo.size.width * 0.7)
                    if let flash = game.flashColor {
                        RadialGradient(colors: [Color(hex: flash).opacity(0.5), .clear],
                                       center: .center, startRadius: 0, endRadius: geo.size.width * 0.6)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 1.2), value: faction)
                .animation(.easeOut(duration: 0.5), value: game.flashColor)

                if let enemy = game.enemy {
                    VStack(spacing: 14) {
                        Spacer(minLength: 0)

                        VStack(spacing: 9) {
                            ZStack {
                                FactionGlyph(faction: enemy.area.faction)
                                    .foregroundStyle(faction)
                                    .shadow(color: faction.opacity(0.55), radius: 28)
                                    .allowsHitTesting(false)
                                reticle(sigil: compact ? 120 : 176)
                            }
                            .frame(width: compact ? 120 : 176, height: compact ? 120 : 176)

                            Text(enemy.rank)
                                .font(.data(9.5))
                                .tracking(2.8)
                                .textCase(.uppercase)
                                .foregroundStyle(Pal.dim)

                            Text(enemy.name)
                                .font(.display(enemy.isBoss ? 24 : 20, .semibold))
                                .tracking(1)
                                .foregroundStyle(enemy.isBoss ? Pal.bad : Pal.bone)
                                .multilineTextAlignment(.center)
                        }
                        .allowsHitTesting(false)
                        .scaleEffect(1 - game.hitPulse * 0.025)
                        .offset(y: game.hitPulse * 2)

                        Spacer(minLength: 0)

                        healthBar(enemy)
                            .frame(maxWidth: 560)
                            .allowsHitTesting(false)
                    }
                    .padding(18)
                }

                // damage numbers
                ForEach(game.popups) { popup in
                    PopupView(popup: popup)
                }
                .allowsHitTesting(false)

                // reticle brackets
                bracket(.topLeading); bracket(.topTrailing)
                bracket(.bottomLeading); bracket(.bottomTrailing)
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                let before = game.stats.kills
                game.fire(at: (location.x - geo.size.width / 2, location.y - geo.size.height * 0.42))
                if game.stats.kills > before { Haptics.crit() } else { Haptics.tap() }
            }
        }
        .frame(minHeight: compact ? 260 : 230)
        .frame(maxHeight: .infinity)
        .panel()
        .overlay(alignment: .top) { buffStrip }
        #if os(macOS)
        .onHover { inside in
            if inside { NSCursor.crosshair.push() } else { NSCursor.pop() }
        }
        #endif
    }

    /// Super and class-ability multipliers run on a timer you otherwise
    /// could not see. Floated over the scene so it costs no layout height.
    private var buffStrip: some View {
        HStack(spacing: 6) {
            ForEach(game.buffs) { buff in
                HStack(spacing: 6) {
                    Text(buff.name)
                        .font(.display(10, .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                    Text("×\(String(format: "%.1f", buff.value))")
                        .font(.data(9.5))
                        .foregroundStyle(Pal.gold)
                    Text("\(Int(ceil(buff.remaining)))s")
                        .font(.data(9.5))
                        .foregroundStyle(Pal.ash)
                        .monospacedDigit()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Pal.void.opacity(0.72))
                .overlay(Rectangle().stroke(Pal.solar.opacity(0.5), lineWidth: 1))
            }
        }
        .padding(.top, 42)
        .allowsHitTesting(false)
    }

    /// The weak point. Drifts model-side; this only draws and taps it.
    private func reticle(sigil size: CGFloat) -> some View {
        let radius = size / 2
        let dx = game.weakPoint.x * radius
        let dy = game.weakPoint.y * radius
        return Button {
            game.fire(at: (Double(dx), Double(dy)), precision: true)
            Haptics.crit()
        } label: {
            ZStack {
                Circle().fill(Pal.gold.opacity(0.16))
                Circle().stroke(Pal.gold, lineWidth: 1.5)
                Circle().fill(Pal.gold).frame(width: 4, height: 4)
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(Pal.gold)
                        .frame(width: 1, height: 5)
                        .offset(y: -17)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
            }
            .frame(width: 30, height: 30)
            .frame(width: 46, height: 46)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: dx, y: dy)
        .animation(.linear(duration: 0.05), value: game.weakPoint)
    }

    /// Sustained fire, and how fast it is bleeding away.
    private var momentumMeter: some View {
        HStack(spacing: 8) {
            Text("Momentum").hudLabel()
            HStack(spacing: 2) {
                ForEach(0..<GameData.momentumCap, id: \.self) { i in
                    Rectangle()
                        .fill(i < game.momentum ? Pal.solar : Pal.rail)
                        .frame(height: 5)
                }
            }
            Text("×\(String(format: "%.1f", 1 + GameData.momentumPerStack * Double(game.momentum)))")
                .font(.data(10))
                .monospacedDigit()
                .foregroundStyle(game.momentum > 0 ? Pal.gold : Pal.dim)
        }
        .animation(.easeOut(duration: 0.15), value: game.momentum)
    }

    private func bracket(_ corner: Alignment) -> some View {
        BracketShape(corner: corner)
            .stroke(Pal.solar.opacity(0.55), lineWidth: 1)
            .frame(width: 26, height: 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner)
            .padding(9)
            .allowsHitTesting(false)
    }

    private func healthBar(_ enemy: Enemy) -> some View {
        VStack(spacing: 4) {
            if let champ = enemy.champion {
                HStack(spacing: 8) {
                    Text(champ.label)
                        .font(.data(9))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: champ.hex))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(Rectangle().stroke(Color(hex: champ.hex).opacity(0.6), lineWidth: 1))
                    Text(enemy.shielded
                         ? "Shielded — break with \(champ.breakerLabel) or Super"
                         : "Shield down · \(Int(ceil(enemy.shieldTimer)))s")
                        .font(.data(10))
                        .foregroundStyle(enemy.shielded ? Pal.ash : Pal.gold)
                    Spacer()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Pal.plate
                        Rectangle()
                            .fill(Color(hex: champ.hex).opacity(enemy.shielded ? 1 : 0.5))
                            .frame(width: enemy.shielded
                                   ? geo.size.width
                                   : geo.size.width * max(0, enemy.shieldTimer / GameData.shieldBreakWindow))
                    }
                }
                .frame(height: 5)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Pal.plate
                    LinearGradient(
                        colors: enemy.isBoss
                            ? [Color(hex: 0x6E1B18), Pal.bad]
                            : [faction.opacity(0.42), faction],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * max(0, enemy.hp) / enemy.maxHP)
                }
                .overlay(Rectangle().stroke(Pal.rail, lineWidth: 1))
            }
            .frame(height: 13)

            HStack {
                Text("\(Fmt.n(max(0, enemy.hp))) / \(Fmt.n(enemy.maxHP))")
                    .font(.data(10.5))
                    .foregroundStyle(Pal.ash)
                    .monospacedDigit()
                Spacer()
                if enemy.isBoss {
                    Text(String(format: "⏱ %.1fs", max(0, enemy.timer)))
                        .font(.data(10.5))
                        .foregroundStyle(enemy.timer < 8 ? Pal.bad : Pal.warn)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Abilities

    private var abilityBar: some View {
        let columns = compact
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

        return VStack(spacing: 6) {
            momentumMeter
            LazyVGrid(columns: columns, spacing: 6) {
                AbilityButton(
                    title: game.sub.grenade, key: "Q",
                    detail: "\(Fmt.n(game.grenadeDamage)) burst",
                    progress: cooldownProgress(.grenade),
                    remaining: game.cooldownRemaining(.grenade),
                    ready: game.canUse(.grenade),
                    breaksShield: game.breaksShield(.grenade)
                ) { game.use(.grenade) }
                .keyboardShortcut("q", modifiers: [])

                AbilityButton(
                    title: game.sub.melee, key: "E",
                    detail: "\(Fmt.n(game.meleeDamage)) burst",
                    progress: cooldownProgress(.melee),
                    remaining: game.cooldownRemaining(.melee),
                    ready: game.canUse(.melee),
                    breaksShield: game.breaksShield(.melee)
                ) { game.use(.melee) }
                .keyboardShortcut("e", modifiers: [])

                AbilityButton(
                    title: game.sub.classAbility, key: "C",
                    detail: "2.2× weapon · 14s",
                    progress: cooldownProgress(.classAbility),
                    remaining: game.cooldownRemaining(.classAbility),
                    ready: game.canUse(.classAbility),
                    breaksShield: game.breaksShield(.classAbility)
                ) { game.use(.classAbility) }
                .keyboardShortcut("c", modifiers: [])

                AbilityButton(
                    title: "Fire", key: "Space",
                    detail: "\(Fmt.n(game.clickDamage)) · \(Int(game.critChance * 100))% crit",
                    progress: 0, remaining: 0, ready: true, breaksShield: false
                ) { game.fire() }
                .keyboardShortcut(.space, modifiers: [])
            }

            SuperButton(game: game)
                .keyboardShortcut("r", modifiers: [])
        }
    }

    private func cooldownProgress(_ ability: Game.Ability) -> Double {
        let length = game.cooldownLength(ability)
        guard length > 0 else { return 0 }
        return game.cooldownRemaining(ability) / length
    }

    // MARK: - Ticker

    private var ticker: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(game.log.prefix(3).enumerated()), id: \.element.id) { index, entry in
                LogLine(entry: entry, primary: index == 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .panel()
        .clipped()
    }
}

// MARK: - Pieces

struct BracketShape: Shape {
    let corner: Alignment

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch corner {
        case .topLeading:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .topTrailing:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomLeading:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        default:
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        return p
    }
}

struct PopupView: View {
    let popup: Popup
    @State private var rise = false

    private var color: Color {
        switch popup.kind {
        case .hit: return Pal.bone
        case .crit: return Pal.gold
        case .ability: return Pal.arc
        case .precision: return Pal.gold
        }
    }

    private var size: CGFloat {
        switch popup.kind {
        case .hit: return 16
        case .crit: return 23
        case .ability: return 19
        case .precision: return 27
        }
    }

    var body: some View {
        Text(popup.kind == .precision ? "◎ \(popup.text)" : popup.text)
            .font(.display(size, .bold))
            .foregroundStyle(color)
            .monospacedDigit()
            .shadow(color: .black.opacity(0.7), radius: 6, y: 2)
            .offset(x: popup.x, y: popup.y + (rise ? -78 : 6))
            .opacity(rise ? 0 : 1)
            .scaleEffect(rise ? 0.96 : 0.85)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { rise = true }
            }
    }
}

struct AbilityButton: View {
    let title: String
    let key: String
    let detail: String
    let progress: Double
    let remaining: Double
    let ready: Bool
    var breaksShield: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(key)
                        .font(.data(9))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Pal.plate)
                        .foregroundStyle(Pal.ash)
                    Text(title)
                        .font(.display(11.5, .semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Text(detail)
                    .font(.data(9.5))
                    .foregroundStyle(Pal.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, remaining > 0 ? 26 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background {
                ZStack(alignment: .trailing) {
                    Pal.hull
                    if progress > 0 {
                        GeometryReader { geo in
                            Pal.void.opacity(0.78)
                                .frame(width: geo.size.width * progress)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .overlay(alignment: .trailing) {
                if remaining > 0 {
                    Text("\(Int(ceil(remaining)))")
                        .font(.display(17, .bold))
                        .foregroundStyle(Pal.ash)
                        .monospacedDigit()
                        .padding(.trailing, 9)
                }
            }
            .overlay(Rectangle().stroke(
                breaksShield ? Pal.gold : (ready ? Pal.solar.opacity(0.55) : Pal.rail),
                lineWidth: breaksShield ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!ready)
    }
}

struct SuperButton: View {
    let game: Game
    @State private var pulse = false

    var body: some View {
        let charged = game.superEnergy >= 100

        Button { game.use(.superAbility) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("R")
                        .font(.data(9))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Pal.plate)
                        .foregroundStyle(Pal.ash)
                    Text(game.sub.superName)
                        .font(.display(11.5, .semibold))
                        .tracking(1)
                        .textCase(.uppercase)
                }
                Text(charged ? "Ready — unleash" : "\(Int(game.superEnergy))% charged")
                    .font(.data(9.5))
                    .foregroundStyle(charged ? Pal.gold : Pal.dim)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Pal.plate
                        Pal.solar.frame(width: geo.size.width * game.superEnergy / 100)
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background {
                LinearGradient(colors: [Pal.solar.opacity(0.12), Pal.hull],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .overlay(Rectangle().stroke(charged ? Pal.solar : Pal.rail, lineWidth: 1))
            .shadow(color: charged ? Pal.solar.opacity(pulse ? 0.4 : 0) : .clear, radius: 16)
        }
        .buttonStyle(.plain)
        .disabled(!charged)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Log lines mark emphasis with <angle brackets> so the model stays free of view code.
struct LogLine: View {
    let entry: LogEntry
    let primary: Bool

    var body: some View {
        let parts = entry.text.split(separator: "<", omittingEmptySubsequences: false)
        return HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, chunk in
                if index == 0 {
                    Text(String(chunk))
                } else if let close = chunk.firstIndex(of: ">") {
                    Text(String(chunk[chunk.startIndex..<close]))
                        .foregroundStyle(Pal.solar)
                    Text(String(chunk[chunk.index(after: close)...]))
                } else {
                    Text(String(chunk))
                }
            }
            if entry.count > 1 {
                Text(" ×\(entry.count)")
                    .foregroundStyle(Pal.solar)
            }
        }
        .font(.data(10.5))
        .foregroundStyle(primary ? Pal.bone : Pal.ash)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
