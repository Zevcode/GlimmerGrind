import SwiftUI

enum ActiveSheet: Identifiable {
    case item(Item, fromPostmaster: Bool)
    case subclass
    case resetLight
    case record
    case bounties

    var id: String {
        switch self {
        case .item(let i, let p): return "item-\(i.id)-\(p)"
        case .subclass: return "subclass"
        case .resetLight: return "reset"
        case .record: return "record"
        case .bounties: return "bounties"
        }
    }
}

/// The roster and the loadout are menus. They slide over the game rather than
/// permanently occupying two thirds of the window.
enum Drawer: String, Identifiable, CaseIterable {
    case fireteam, gear
    var id: String { rawValue }
    var title: String { self == .fireteam ? "Fireteam" : "Loadout" }
    var key: String { self == .fireteam ? "F" : "I" }
    var edge: Edge { self == .fireteam ? .leading : .trailing }
    var width: CGFloat { self == .fireteam ? 330 : 350 }
}

struct RootView: View {
    @State private var game = Game()
    @State private var sheet: ActiveSheet?
    @State private var drawer: Drawer?
    @State private var lastTick = Date()
    @State private var lastSave = Date()

    @Environment(\.scenePhase) private var scenePhase

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var factionColor: Color {
        Color(hex: game.enemy?.area.hex ?? game.area.hex)
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 900

            VStack(spacing: 10) {
                TopBar(game: game, sheet: $sheet, drawer: $drawer, compact: compact)
                    .fixedSize(horizontal: false, vertical: true)
                CombatView(game: game, compact: compact)
                    .layoutPriority(1)
            }
            .padding(10)
            .frame(maxWidth: 1560)
            .overlay {
                if let open = drawer {
                    ZStack(alignment: open.edge == .leading ? .leading : .trailing) {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture { drawer = nil }

                        Group {
                            switch open {
                            case .fireteam: FireteamPanel(game: game)
                            case .gear: GearPanel(game: game, sheet: $sheet)
                            }
                        }
                        .frame(width: min(open.width, geo.size.width - 40))
                        .padding(.vertical, 10)
                        .padding(open.edge == .leading ? .leading : .trailing, 10)
                        .transition(.move(edge: open.edge))
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: drawer)
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
        .onKeyPress(.escape) { drawer = nil; return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "fFiI")) { press in
            let c = press.characters.lowercased()
            if c == "f" { drawer = drawer == .fireteam ? nil : .fireteam }
            if c == "i" { drawer = drawer == .gear ? nil : .gear }
            return .handled
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
    @Binding var drawer: Drawer?
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
            ForEach(Drawer.allCases) { d in
                Button("\(d.title) · \(d.key)") { drawer = (drawer == d ? nil : d) }
                    .buttonStyle(HudButtonStyle(hot: drawer == d, ghost: drawer != d))
                    .overlay(alignment: .topTrailing) {
                        if d == .gear && !game.postmaster.isEmpty {
                            Circle().fill(Pal.gold).frame(width: 7, height: 7).offset(x: 2, y: -2)
                        }
                    }
            }
            Button("Bounties") { sheet = .bounties }
                .buttonStyle(HudButtonStyle(ghost: true))
                .overlay(alignment: .topTrailing) {
                    if game.claimableBounties > 0 {
                        Circle().fill(Pal.ok).frame(width: 7, height: 7).offset(x: 2, y: -2)
                    }
                }
            if game.pendingShards > 0 {
                Button("Reset +\(game.pendingShards)") { sheet = .resetLight }
                    .buttonStyle(HudButtonStyle(hot: true))
            }
            Menu {
                Button("Subclass") { sheet = .subclass }
                Button("Reset Light") { sheet = .resetLight }
                Button("Vanguard Record") { sheet = .record }
            } label: {
                Text("More")
                    .font(.display(11, .semibold)).tracking(1.3).textCase(.uppercase)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Chamfer().stroke(Pal.rail, lineWidth: 1))
        }
        .padding(.horizontal, 10)
    }
}
