import SwiftUI

/// The flow bar's orb: a soft-edged disc of flat colour wedges that sweep around like a pinwheel.
/// At rest it sits small and grey; while listening it turns full colour and swells with your voice.
struct PulsingOrb: View {
    enum Style {
        /// Small monochrome disc with a few slow wedges.
        case idle
        /// Green-led palette; wedges widen and the disc swells with the mic level (0…1).
        case recording(level: CGFloat)
        /// Blue-led palette while the transcript is worked out.
        case transcribing
    }

    let style: Style

    static let idleDiameter: CGFloat = 16
    static let diameter: CGFloat = 28

    var body: some View {
        // Idle runs at a lower frame rate; its wedges barely move.
        TimelineView(.animation(minimumInterval: isIdle ? 1 / 15 : 1 / 30)) { context in
            disc(at: context.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: size, height: size)
        // Voice swell is animated separately so it eases between level samples instead of jumping.
        .scaleEffect(1 + level * 0.25)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private var size: CGFloat { isIdle ? Self.idleDiameter : Self.diameter }

    private var level: CGFloat {
        switch style {
        case .recording(let level): min(max(level, 0), 1)
        case .idle, .transcribing: 0
        }
    }

    private var isIdle: Bool {
        if case .idle = style { return true }
        return false
    }

    // MARK: - Disc

    /// One flat wedge fanning out from a pivot that drifts around the centre.
    private struct Blade {
        /// Index into the palette's wedge colours; nil cuts a see-through slice.
        let color: Int?
        /// Radians per second; negative turns the other way.
        let speed: Double
        let phase: Double
        /// Angular width in radians.
        let width: Double
    }

    private static let blades: [Blade] = [
        Blade(color: 0, speed: 0.7, phase: 0, width: 2.2),
        Blade(color: 1, speed: -0.5, phase: 2.0, width: 1.7),
        Blade(color: 2, speed: 0.4, phase: 4.0, width: 1.5),
        Blade(color: 3, speed: 1.1, phase: 1.0, width: 1.2),
        Blade(color: 4, speed: -0.8, phase: 3.0, width: 1.0),
        Blade(color: nil, speed: 1.4, phase: 5.0, width: 0.4),
    ]

    private func disc(at t: TimeInterval) -> some View {
        let (base, wedges) = palette
        // Idle keeps just two slow wedges; the colour states use them all.
        let blades = isIdle ? Array(Self.blades.prefix(2)) : Self.blades
        let pace = isIdle ? 0.25 : 1.0
        let spread = 1 + Double(level) * 0.4
        // Gentle breathing on top of the voice swell.
        let breath = 0.96 + 0.04 * sin(t * (isIdle ? 1.2 : 3.0))

        return Canvas { context, canvas in
            let centre = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let radius = canvas.width / 2
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: canvas)), with: .color(base))

            for blade in blades {
                let angle = blade.phase + t * blade.speed * pace
                // Pivots sit well off-centre so wedges read as sweeping planes rather than pie slices.
                let pivot = CGPoint(x: centre.x + cos(angle * 0.6 + blade.phase) * radius * 0.35,
                                    y: centre.y + sin(angle * 0.6 + blade.phase) * radius * 0.35)
                let width = blade.width * spread * (1 + 0.3 * sin(t * blade.speed * pace * 1.7 + blade.phase))

                var wedge = Path()
                wedge.move(to: pivot)
                wedge.addArc(center: pivot, radius: radius * 2,
                             startAngle: .radians(angle), endAngle: .radians(angle + width),
                             clockwise: false)
                wedge.closeSubpath()

                if let color = blade.color {
                    context.fill(wedge, with: .color(wedges[color % wedges.count]))
                } else {
                    var cut = context
                    cut.blendMode = .destinationOut
                    cut.fill(wedge, with: .color(.black))
                }
            }
        }
        // Softens the seams between wedges without losing their shape.
        .blur(radius: size * 0.07)
        // Feathers the rim so the disc has no hard outline.
        .mask(RadialGradient(stops: [.init(color: .black, location: 0.4),
                                     .init(color: .clear, location: 1)],
                             center: .center, startRadius: 0, endRadius: size / 2))
        .scaleEffect(breath)
    }

    private var palette: (base: Color, wedges: [Color]) {
        switch style {
        case .idle:
            // Mid-grey base so the disc reads on both light and dark desktops.
            (Color(white: 0.6),
             [Color(white: 0.3), Color(white: 0.95)])
        case .recording:
            (Color(red: 0.05, green: 0.62, blue: 0.2),       // leaf green
             [Color(red: 0.0, green: 0.3, blue: 0.06),       // dark green
              Color(red: 0.8, green: 0.93, blue: 0.2),       // lime
              Color(red: 0.75, green: 0.48, blue: 0.1),      // ochre
              Color(red: 1.0, green: 0.5, blue: 0.8),        // pink
              Color(red: 0.1, green: 0.7, blue: 1.0)])       // sky blue
        case .transcribing:
            (Color(red: 0.15, green: 0.45, blue: 1.0),       // cobalt
             [Color(red: 0.05, green: 0.12, blue: 0.45),     // navy
              Color(red: 0.3, green: 0.9, blue: 1.0),        // cyan
              Color(red: 0.7, green: 0.55, blue: 1.0),       // lilac
              Color(red: 0.5, green: 1.0, blue: 0.8),        // mint
              Color(red: 0.9, green: 0.95, blue: 1.0)])      // ice
        }
    }
}
