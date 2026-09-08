import SwiftUI

enum ActiveSheet: Identifiable {
    case item(Item, fromPostmaster: Bool)
    case subclass
    case resetLight
    case record

    var id: String {
        switch self {
        case .item(let i, let p): return "item-\(i.id)-\(p)"
        case .subclass: return "subclass"
        case .resetLight: return "reset"
        case .record: return "record"
        }
    }
}

enum SidePanel: String, CaseIterable { case fireteam = "Fireteam", gear = "Gear" }

struct RootView: View {
    @State private var game = Game()
    @State private var sheet: ActiveSheet?
    @State private var sidePanel: SidePanel = .fireteam
    @State private var lastTick = Date()
    @State private var lastSave = Date()

    @Environment(\.scenePhase) private var scenePhase

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var factionColor: Color {
        Color(hex: game.enemy?.area.hex ?? game.area.hex)
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 1100

            VStack(spacing: 10) {
                TopBar(game: game, sheet: $sheet, compact: compact)

                if compact {
                    VStack(spacing: 10) {
                        CombatView(game: game, compact: true)
                            .frame(minHeight: 380)

                        Picker("", selection: $sidePanel) {
                            ForEach(SidePanel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Group {
                            switch sidePanel {
                            case .fireteam: FireteamPanel(game: game)
                            case .gear: GearPanel(game: game, sheet: $sheet)
                            }
                        }
                        .frame(minHeight: 320)
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        FireteamPanel(game: game).frame(width: 296)
                        CombatView(game: game, compact: false)
                        GearPanel(game: game, sheet: $sheet).frame(width: 322)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: 1560)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background {
            ZStack {
                Pal.void
                RadialGradient(
                    colors: [factionColor.opacity(0.11), .clear],
                    center: .init(x: 0.5, y: -0.1), startRadius: 0, endRadius: 900
                )
                RadialGradient(
                    colors: [Pal.ember.opacity(0.07), .clear],
                    center: .init(x: 0.5, y: 1.1), startRadius: 0, endRadius: 800
                )
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.2), value: factionColor)
        }
        .foregroundStyle(Pal.bone)
        .tint(Pal.solar)
        .overlay(alignment: .bottom) {
            if let toast = game.toast {
                Text(toast)
                    .font(.display(12.5, .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(Chamfer().fill(Pal.plate))
                    .overlay(Chamfer().stroke(Pal.solar, lineWidth: 1))
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: game.toast)
        .sheet(item: $sheet) { active in
            SheetHost(game: game, active: active, sheet: $sheet)
        }
        .onReceive(ticker) { now in
            let dt = min(now.timeIntervalSince(lastTick), 0.5)
            lastTick = now
            game.tick(dt)
            if now.timeIntervalSince(lastSave) > 10 {
                lastSave = now
                game.save()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                lastTick = Date()
                game.applyOfflineProgress()
            case .background, .inactive:
                game.save()
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    let game: Game
    @Binding var sheet: ActiveSheet?
    var compact: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                crest
                readouts
                if !compact { Spacer(minLength: 8); actions }
            }
            if compact {
                HStack { Spacer(); actions }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .panel()
    }

    private var crest: some View {
        HStack(spacing: 10) {
            ZStack {
                EngramShape(inset: 0).fill(Pal.bone.opacity(0.25))
                EngramShape(inset: 1).fill(Pal.gold)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 0) {
                Text("Glimmer Grind")
                    .font(.display(16, .bold))
                    .tracking(2.2)
                    .textCase(.uppercase)
                Text("Idle Vanguard Ops")
                    .font(.data(9))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Pal.bone.opacity(0.62))
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 26)
        .padding(.vertical, 9)
        .background {
            LinearGradient(
                colors: [Pal.ember, Color(hex: 0x5E2410), .clear],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    private var readouts: some View {
        HStack(spacing: 0) {
            readout(Fmt.n(game.glimmer), "Glimmer", Pal.glimmer)
            readout(Fmt.n(game.fireteamDPS), "Fireteam DPS", Pal.solar)
            if !compact { readout(Fmt.n(game.clickDamage), "Per Shot", Pal.bone) }
            readout("\(game.light)", "Light", Pal.gold)
            readout("\(game.shards)", "Shards", Pal.shard)
        }
    }

    private func readout(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.display(17, .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).hudLabel()
        }
        .frame(minWidth: compact ? 62 : 92, alignment: .leading)
        .padding(.horizontal, compact ? 10 : 18)
        .padding(.vertical, 8)
        .overlay(alignment: .leading) { Pal.rail.opacity(0.7).frame(width: 1) }
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button("Subclass") { sheet = .subclass }
                .buttonStyle(HudButtonStyle(ghost: true))
            Button(game.pendingShards > 0 ? "Reset Light +\(game.pendingShards)" : "Reset Light") {
                sheet = .resetLight
            }
            .buttonStyle(HudButtonStyle(hot: game.pendingShards > 0, ghost: game.pendingShards == 0))
            Button("Record") { sheet = .record }
                .buttonStyle(HudButtonStyle(ghost: true))
        }
        .padding(.horizontal, 10)
    }
}
