import SwiftUI

/// Faction sigils, drawn as paths in a normalised 100×100 field.
/// Abstract geometry rather than any real emblem — each faction gets a
/// silhouette you can read at 20pt in the roster and at 130pt in the viewport.
struct GlyphShape: Shape {
    let faction: Faction
    var filled: Bool = false

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 100
        let ox = rect.minX + (rect.width - 100 * s) / 2
        let oy = rect.minY + (rect.height - 100 * s) / 2
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + x * s, y: oy + y * s)
        }
        func poly(_ p: inout Path, _ points: [(Double, Double)]) {
            guard let first = points.first else { return }
            p.move(to: pt(first.0, first.1))
            for c in points.dropFirst() { p.addLine(to: pt(c.0, c.1)) }
            p.closeSubpath()
        }
        func line(_ p: inout Path, _ a: (Double, Double), _ b: (Double, Double)) {
            p.move(to: pt(a.0, a.1))
            p.addLine(to: pt(b.0, b.1))
        }

        var p = Path()

        switch (faction, filled) {

        case (.fallen, false):
            poly(&p, [(50, 6), (82, 30), (82, 70), (50, 94), (18, 70), (18, 30)])
            line(&p, (50, 22), (50, 78))
            line(&p, (50, 22), (34, 40))
            line(&p, (50, 22), (66, 40))
            line(&p, (50, 78), (30, 62))
            line(&p, (50, 78), (70, 62))
        case (.fallen, true):
            poly(&p, [(50, 34), (60, 50), (50, 66), (40, 50)])

        case (.cabal, false):
            poly(&p, [(22, 14), (78, 14), (92, 36), (78, 58), (22, 58), (8, 36)])
            poly(&p, [(30, 62), (70, 62), (80, 86), (20, 86)])
        case (.cabal, true):
            p.addEllipse(in: CGRect(x: pt(41, 27).x, y: pt(41, 27).y, width: 18 * s, height: 18 * s))

        case (.hive, false):
            poly(&p, [(50, 4), (92, 50), (50, 96), (8, 50)])
            poly(&p, [(50, 24), (74, 50), (50, 76), (26, 50)])
            line(&p, (50, 40), (50, 60))
            line(&p, (40, 50), (60, 50))
        case (.hive, true):
            poly(&p, [(50, 38), (61, 50), (50, 62), (39, 50)])

        case (.vex, false):
            poly(&p, [(50, 8), (86, 29), (86, 71), (50, 92), (14, 71), (14, 29)])
            p.addEllipse(in: CGRect(x: pt(30, 30).x, y: pt(30, 30).y, width: 40 * s, height: 40 * s))
            line(&p, (50, 8), (50, 29))
            line(&p, (50, 71), (50, 92))
            line(&p, (14, 29), (32, 40))
            line(&p, (86, 29), (68, 40))
        case (.vex, true):
            p.addEllipse(in: CGRect(x: pt(43, 43).x, y: pt(43, 43).y, width: 14 * s, height: 14 * s))

        case (.taken, false):
            // Eight-point star: the spikes now grow out of the diamond instead
            // of hovering beside it.
            poly(&p, [(50, 4), (64, 34), (94, 50), (64, 66),
                      (50, 96), (36, 66), (6, 50), (36, 34)])
        case (.taken, true):
            poly(&p, [(50, 30), (63, 50), (50, 70), (37, 50)])

        case (.scorn, false):
            // Barbed and asymmetric, but a single closed silhouette — the old
            // version drew two strokes that never touched the body.
            poly(&p, [(50, 4), (62, 26), (84, 30), (72, 50),
                      (80, 76), (58, 70), (50, 96), (42, 70),
                      (20, 76), (28, 50), (16, 30), (38, 26)])
            line(&p, (50, 30), (50, 66))
        case (.scorn, true):
            poly(&p, [(50, 34), (59, 52), (50, 68), (41, 52)])
        }

        return p
    }
}

struct FactionGlyph: View {
    let faction: Faction
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            GlyphShape(faction: faction)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            GlyphShape(faction: faction, filled: true)
                .fill()
        }
    }
}

/// Fireteam roster marks — one silhouette per Guardian archetype.
struct ClassGlyphView: View {
    let glyph: GameData.ClassGlyph

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                shape(outer: true).fill(Pal.solar.opacity(0.3))
                shape(outer: false).fill(Pal.solar)
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func shape(outer: Bool) -> some Shape {
        ClassMark(glyph: glyph, outer: outer)
    }
}

struct ClassMark: Shape {
    let glyph: GameData.ClassGlyph
    let outer: Bool

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        func poly(_ points: [(Double, Double)]) -> Path {
            var p = Path()
            guard let f = points.first else { return p }
            p.move(to: pt(f.0, f.1))
            for c in points.dropFirst() { p.addLine(to: pt(c.0, c.1)) }
            p.closeSubpath()
            return p
        }

        switch glyph {
        case .titan:
            return outer
                ? poly([(12, 2), (21, 7), (21, 13), (12, 22), (3, 13), (3, 7)])
                : poly([(12, 5), (18, 8.5), (18, 13), (12, 19), (6, 13), (6, 8.5)])
        case .hunter:
            return outer ? poly([(12, 2), (22, 20), (2, 20)]) : poly([(12, 7), (18, 18), (6, 18)])
        case .warlock:
            return outer
                ? poly([(12, 2), (22, 12), (12, 22), (2, 12)])
                : poly([(12, 6), (18, 12), (12, 18), (6, 12)])
        case .shell:
            if outer {
                return poly([(12, 3), (20, 8), (20, 16), (12, 21), (4, 16), (4, 8)])
            } else {
                var p = Path()
                p.addEllipse(in: CGRect(x: pt(8.5, 8.5).x, y: pt(8.5, 8.5).y, width: 7 * s, height: 7 * s))
                return p
            }
        }
    }
}

/// Engram — the loot polyhedron, tinted by rarity.
struct EngramView: View {
    let rarity: Int
    var size: CGFloat = 26

    var body: some View {
        let color = Color(hex: GameData.rarities[rarity].hex)
        ZStack {
            EngramShape(inset: 0).fill(color.opacity(0.22))
            EngramShape(inset: 1).fill(color.opacity(0.55))
            EngramShape(inset: 2).fill(color)
        }
        .frame(width: size, height: size)
    }
}

struct EngramShape: Shape {
    /// 0 = outer hull, 1 = mid facet, 2 = core
    let inset: Int

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        let points: [(Double, Double)]
        switch inset {
        case 0: points = [(12, 2), (21, 7.5), (21, 16.5), (12, 22), (3, 16.5), (3, 7.5)]
        case 1: points = [(12, 5), (18, 8.7), (18, 15.3), (12, 19), (6, 15.3), (6, 8.7)]
        default: points = [(12, 8.6), (15, 10.5), (15, 13.8), (12, 15.6), (9, 13.8), (9, 10.5)]
        }
        var p = Path()
        p.move(to: pt(points[0].0, points[0].1))
        for c in points.dropFirst() { p.addLine(to: pt(c.0, c.1)) }
        p.closeSubpath()
        return p
    }
}
