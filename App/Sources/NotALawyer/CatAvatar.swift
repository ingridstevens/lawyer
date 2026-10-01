import SwiftUI

/// The user's avatar: a round, kawaii cat face, drawn in code so it's crisp at any size.
struct CatAvatar: View {
    enum Fur: String, Codable, CaseIterable, Identifiable {
        case shiro, mike, kuro, chatora, sabi
        var id: Self { self }

        /// Japanese cat-colour names, with what they mean.
        var name: String {
            switch self {
            case .shiro: "Shiro (white)"
            case .mike: "Mike (calico)"
            case .kuro: "Kuro (black)"
            case .chatora: "Chatora (ginger)"
            case .sabi: "Sabi (tortoiseshell)"
            }
        }

        var base: Color {
            switch self {
            case .shiro, .mike: Color(red: 1, green: 0.99, blue: 0.97)
            case .kuro: Color(red: 0.2, green: 0.2, blue: 0.24)
            case .chatora: Color(red: 0.98, green: 0.72, blue: 0.42)
            case .sabi: Color(red: 0.36, green: 0.28, blue: 0.24)
            }
        }

        var line: Color { self == .kuro || self == .sabi ? Color(red: 0.12, green: 0.1, blue: 0.12) : Color(red: 0.25, green: 0.2, blue: 0.22) }
        var backdrop: Color {
            switch self {
            case .shiro: Color(red: 0.86, green: 0.91, blue: 1)
            case .mike: Color(red: 1, green: 0.9, blue: 0.86)
            case .kuro: Color(red: 0.93, green: 0.88, blue: 1)
            case .chatora: Color(red: 1, green: 0.95, blue: 0.8)
            case .sabi: Color(red: 0.9, green: 0.96, blue: 0.88)
            }
        }
    }

    var fur: Fur = .mike
    var size: CGFloat = 40

    var body: some View {
        Canvas { ctx, canvas in
            let s = min(canvas.width, canvas.height)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }

            // Backdrop.
            ctx.fill(Path(ellipseIn: r(0, 0, 1, 1)), with: .color(fur.backdrop))

            // Ears, with rounded tips, then their pink insides.
            for flip in [false, true] {
                func fx(_ x: CGFloat) -> CGFloat { flip ? 1 - x : x }
                var ear = Path()
                ear.move(to: p(fx(0.17), 0.52))
                ear.addQuadCurve(to: p(fx(0.25), 0.17), control: p(fx(0.15), 0.3))
                ear.addQuadCurve(to: p(fx(0.47), 0.36), control: p(fx(0.3), 0.14))
                ear.closeSubpath()
                ctx.fill(ear, with: .color(fur == .mike ? (flip ? Color(red: 0.22, green: 0.2, blue: 0.22) : Color(red: 0.96, green: 0.6, blue: 0.3)) : fur.base))
                var inner = Path()
                inner.move(to: p(fx(0.23), 0.44))
                inner.addQuadCurve(to: p(fx(0.27), 0.25), control: p(fx(0.22), 0.32))
                inner.addQuadCurve(to: p(fx(0.39), 0.37), control: p(fx(0.31), 0.25))
                inner.closeSubpath()
                ctx.fill(inner, with: .color(Color(red: 1, green: 0.7, blue: 0.75)))
            }

            // Head.
            let head = Path(ellipseIn: r(0.13, 0.3, 0.74, 0.6))
            ctx.fill(head, with: .color(fur.base))

            // Patches, clipped to the head.
            ctx.drawLayer { layer in
                layer.clip(to: head)
                switch fur {
                case .mike:
                    layer.fill(Path(ellipseIn: r(0.08, 0.24, 0.38, 0.32)), with: .color(Color(red: 0.96, green: 0.6, blue: 0.3)))
                    layer.fill(Path(ellipseIn: r(0.58, 0.26, 0.36, 0.28)), with: .color(Color(red: 0.22, green: 0.2, blue: 0.22)))
                case .chatora:
                    for i in 0..<3 {
                        let y = 0.33 + CGFloat(i) * 0.05
                        layer.fill(Path(roundedRect: r(0.44, y, 0.12, 0.025), cornerRadius: 0.012 * s),
                                   with: .color(Color(red: 0.9, green: 0.55, blue: 0.25)))
                    }
                case .sabi:
                    layer.fill(Path(ellipseIn: r(0.5, 0.28, 0.4, 0.34)), with: .color(Color(red: 0.8, green: 0.5, blue: 0.25)))
                    layer.fill(Path(ellipseIn: r(0.12, 0.6, 0.3, 0.25)), with: .color(Color(red: 0.7, green: 0.42, blue: 0.2)))
                default:
                    break
                }
            }

            // Big, shiny eyes.
            let eyeColor = fur == .kuro ? Color(red: 0.98, green: 0.82, blue: 0.3) : fur.line
            for x in [0.315, 0.595] as [CGFloat] {
                ctx.fill(Path(ellipseIn: r(x, 0.515, 0.09, 0.115)), with: .color(eyeColor))
                if fur == .kuro { ctx.fill(Path(ellipseIn: r(x + 0.032, 0.53, 0.026, 0.085)), with: .color(fur.line)) }
                ctx.fill(Path(ellipseIn: r(x + 0.014, 0.53, 0.036, 0.036)), with: .color(.white))
                ctx.fill(Path(ellipseIn: r(x + 0.055, 0.59, 0.016, 0.016)), with: .color(.white))
            }

            // Blush.
            for x in [0.22, 0.66] as [CGFloat] {
                ctx.fill(Path(ellipseIn: r(x, 0.64, 0.12, 0.06)), with: .color(Color(red: 1, green: 0.55, blue: 0.62).opacity(0.55)))
            }

            // Nose and ω mouth.
            var nose = Path()
            nose.move(to: p(0.48, 0.64)); nose.addLine(to: p(0.52, 0.64)); nose.addLine(to: p(0.5, 0.665)); nose.closeSubpath()
            ctx.fill(nose, with: .color(Color(red: 0.95, green: 0.45, blue: 0.55)))
            var mouth = Path()
            mouth.move(to: p(0.44, 0.675))
            mouth.addQuadCurve(to: p(0.5, 0.675), control: p(0.47, 0.715))
            mouth.addQuadCurve(to: p(0.56, 0.675), control: p(0.53, 0.715))
            ctx.stroke(mouth, with: .color(fur.line), style: StrokeStyle(lineWidth: max(1, 0.018 * s), lineCap: .round))

            // Whiskers.
            if s >= 28 {
                for (y1, y2) in [(0.62, 0.6), (0.66, 0.67)] as [(CGFloat, CGFloat)] {
                    for flip in [false, true] {
                        var w = Path()
                        w.move(to: p(flip ? 0.8 : 0.2, y1)); w.addLine(to: p(flip ? 0.95 : 0.05, y2))
                        ctx.stroke(w, with: .color(fur.line.opacity(0.5)), lineWidth: max(0.6, 0.01 * s))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Cat avatar, \(fur.name)")
    }
}

/// Pick a cat.
struct CatPicker: View {
    @Binding var fur: CatAvatar.Fur

    var body: some View {
        HStack(spacing: 12) {
            ForEach(CatAvatar.Fur.allCases) { option in
                Button { fur = option } label: {
                    CatAvatar(fur: option, size: 52)
                        .overlay(Circle().stroke(fur == option ? Theme.stamp : .clear, lineWidth: 3).padding(-3))
                }
                .buttonStyle(.plain)
                .help(option.name)
                .accessibilityAddTraits(fur == option ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HStack { ForEach(CatAvatar.Fur.allCases) { CatAvatar(fur: $0, size: 120) } }.padding()
}
