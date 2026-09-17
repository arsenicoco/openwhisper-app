import SwiftUI

/// The flow bar's microphone: a bare glyph at rest that lights up like an 80s neon sign.
struct NeonMic: View {
    enum Style {
        /// Unlit tube — plain glyph, just a soft dark edge so it reads on light backgrounds.
        case off
        /// Hot-pink tube; glow blooms with the mic level (0…1).
        case recording(level: CGFloat)
        /// Cyan tube breathing slowly while the transcript is worked out.
        case transcribing
    }

    let style: Style

    /// Resting glyph: small hairline so it barely sits on screen.
    static let offSize: CGFloat = 12
    /// Lit glyph: over twice the size, with a heavier stroke for the tube.
    static let litSize: CGFloat = 28

    /// When the tube was switched on — drives the ignition flicker.
    @State private var litAt = Date()

    var body: some View {
        switch style {
        case .off:
            Image(systemName: "mic")
                .font(.system(size: Self.offSize, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.6), radius: 1)
                .shadow(color: .black.opacity(0.2), radius: 3)
        case .recording, .transcribing:
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                lit(at: context.date)
            }
            .onAppear { litAt = Date() }
        }
    }

    private var glyph: some View {
        Image(systemName: "mic")
            .font(.system(size: Self.litSize, weight: .medium))
    }

    // MARK: - Lit tube

    private func lit(at date: Date) -> some View {
        let t = date.timeIntervalSince(litAt)
        let glow = intensity(at: t)
        let brightness = flicker(at: t)
        let glitch = glitchOffset(at: t)
        let (core, halo, ghost) = palette
        // Synthwave violet for the outer haze; mixing halo and ghost there turns muddy grey.
        let haze = Color(red: 0.55, green: 0.15, blue: 1.0)
        // Chromatic split widens as the glow gets hotter, and tears apart during a glitch.
        let split = 1.2 + glow * 2.4 + abs(glitch) * 1.5

        return ZStack {
            // Hazy neon wash behind the tube — lifts the whole area when you speak.
            RadialGradient(colors: [halo.opacity(0.3 + glow * 0.3),
                                    haze.opacity(0.14 + glow * 0.16),
                                    .clear],
                           center: .center, startRadius: 2, endRadius: 44)
                .scaleEffect(0.85 + glow * 0.15)

            ZStack {
                glyph.foregroundStyle(ghost).offset(x: -split, y: 0.5).opacity(0.85)
                glyph.foregroundStyle(halo).offset(x: split, y: -0.5).opacity(0.85)
                glyph.foregroundStyle(core)
            }
            .offset(x: glitch)
            .compositingGroup()
            // Outer radii stay under ~16pt so the bloom fades out before the canvas edge clips it.
            .shadow(color: .white.opacity(0.7), radius: 1)
            .shadow(color: halo, radius: 2.5)
            .shadow(color: halo.opacity(0.6 + glow * 0.4), radius: 5 + glow * 4)
            .shadow(color: halo.opacity(0.35 + glow * 0.45), radius: 9 + glow * 6)
            .shadow(color: ghost.opacity(0.2 + glow * 0.3), radius: 12 + glow * 4)
        }
        .mask(Scanlines())
        .opacity(brightness)
    }

    private var palette: (core: Color, halo: Color, ghost: Color) {
        switch style {
        case .transcribing:
            (Color(red: 0.85, green: 1.0, blue: 1.0),   // white-hot cyan
             Color(red: 0.0, green: 0.95, blue: 1.0),   // electric cyan
             Color(red: 0.62, green: 0.25, blue: 1.0))  // violet
        default:
            (Color(red: 1.0, green: 0.86, blue: 0.97),  // white-hot pink
             Color(red: 1.0, green: 0.1, blue: 0.7),    // hot magenta
             Color(red: 0.0, green: 0.9, blue: 1.0))    // cyan
        }
    }

    /// 0…1 glow strength.
    private func intensity(at t: TimeInterval) -> CGFloat {
        switch style {
        case .off: 0
        case .recording(let level): 0.3 + 0.7 * min(max(level, 0), 1)
        case .transcribing: 0.45 + 0.35 * CGFloat(sin(t * 3) * 0.5 + 0.5)
        }
    }

    /// Neon stutter: a burst of flicker as the tube ignites, then an occasional brief dip.
    private func flicker(at t: TimeInterval) -> Double {
        let igniting = t < 0.45
        let bucket = Int(t * (igniting ? 28 : 14))
        let noise = pseudoRandom(bucket)
        if igniting { return noise > 0.45 ? 1 : 0.25 }
        return noise > 0.97 ? 0.6 : 1
    }

    /// Every so often the tube jolts sideways for a frame or two, like a bad VHS tracking line.
    private func glitchOffset(at t: TimeInterval) -> CGFloat {
        let bucket = Int(t * 10)
        guard pseudoRandom(bucket + 7_919) > 0.95 else { return 0 }
        return pseudoRandom(bucket * 31) > 0.5 ? 2.5 : -2.5
    }

    private func pseudoRandom(_ n: Int) -> Double {
        let x = sin(Double(n) * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }
}

/// CRT scanlines used as a mask: every other point-row is dimmed.
private struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white))
                context.fill(Path(CGRect(x: 0, y: y + 1, width: size.width, height: 1)), with: .color(.white.opacity(0.7)))
                y += 2
            }
        }
    }
}
