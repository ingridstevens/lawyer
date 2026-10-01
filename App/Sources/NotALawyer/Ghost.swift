import SwiftUI

/// A little ghost: the sign for a chat that leaves out everything the app knows about you.
struct GhostShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.45))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + h * 0.45), radius: w / 2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Wavy hem.
        let waves = 3
        for i in 0..<waves {
            let x0 = rect.maxX - w * CGFloat(i) / CGFloat(waves)
            let x1 = rect.maxX - w * CGFloat(i + 1) / CGFloat(waves)
            p.addQuadCurve(to: CGPoint(x: (x0 + x1) / 2, y: rect.maxY - h * 0.14), control: CGPoint(x: x0 - w / 12, y: rect.maxY - h * 0.16))
            p.addQuadCurve(to: CGPoint(x: x1, y: rect.maxY), control: CGPoint(x: x1 + w / 12, y: rect.maxY - h * 0.16))
        }
        p.closeSubpath()
        return p
    }
}

struct GhostIcon: View {
    var size: CGFloat = 18
    var filled = true

    var body: some View {
        ZStack {
            if filled {
                GhostShape().fill(.foreground)
            } else {
                GhostShape().stroke(.foreground, lineWidth: max(1.2, size / 12))
            }
            // Eyes.
            HStack(spacing: size * 0.16) {
                Capsule().frame(width: size * 0.13, height: size * 0.2)
                Capsule().frame(width: size * 0.13, height: size * 0.2)
            }
            .foregroundStyle(filled ? Color(nsColor: .windowBackgroundColor) : Color.primary)
            .offset(y: -size * 0.08)
        }
        .frame(width: size * 0.82, height: size)
        .accessibilityHidden(true)
    }
}
