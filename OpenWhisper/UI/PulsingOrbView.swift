import SwiftUI

/// The flow bar's listening indicator: a glowing orb that breathes and swells with your voice.
struct PulsingOrb: View {
    enum Style {
        /// Hot-pink orb; swells and sends out ripples with the mic level (0…1).
        case recording(level: CGFloat)
        /// Cyan orb breathing slowly while the transcript is worked out.
        case transcribing
    }

    let style: Style

    /// Resting diameter of the sphere, before breathing and voice swell.
    static let diameter: CGFloat = 24

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            orb(at: context.date.timeIntervalSinceReferenceDate)
        }
        // Voice swell is animated separately so it eases between level samples instead of jumping.
        .scaleEffect(1 + level * 0.3)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private var level: CGFloat {
        switch style {
        case .recording(let level): min(max(level, 0), 1)
        case .transcribing: 0
        }
    }

    private var isTranscribing: Bool {
        if case .transcribing = style { return true }
        return false
    }

    // MARK: - Orb

    private func orb(at t: TimeInterval) -> some View {
        let (core, halo, deep) = palette
        // Slow breath while transcribing, a quicker heartbeat while listening.
        let breath = CGFloat(sin(t * (isTranscribing ? 2.4 : 4.2)) * 0.5 + 0.5)
        let glow = isTranscribing ? 0.35 + breath * 0.35 : 0.4 + level * 0.6

        return ZStack {
            // Soft haze behind everything so the orb lights up the area around it.
            RadialGradient(colors: [halo.opacity(0.25 + glow * 0.25), deep.opacity(0.1), .clear],
                           center: .center, startRadius: 2, endRadius: 44)

            ripples(at: t, color: halo)

            Circle()
                .fill(RadialGradient(colors: [core, halo, deep],
                                     center: UnitPoint(x: 0.38, y: 0.32),
                                     startRadius: 0,
                                     endRadius: Self.diameter * 0.75))
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .frame(width: Self.diameter, height: Self.diameter)
                .scaleEffect(0.92 + breath * 0.1)
                // Outer radii stay under ~16pt so the bloom fades out before the canvas edge clips it.
                .shadow(color: halo, radius: 3)
                .shadow(color: halo.opacity(0.5 + glow * 0.4), radius: 7 + glow * 5)
                .shadow(color: deep.opacity(0.3 + glow * 0.3), radius: 12 + glow * 4)
        }
    }

    /// Rings that drift out from the sphere and fade; louder speech makes them brighter.
    private func ripples(at t: TimeInterval, color: Color) -> some View {
        let period = isTranscribing ? 2.4 : 1.4
        let strength = isTranscribing ? 0.35 : 0.3 + level * 0.7
        return ZStack {
            ForEach(0..<2, id: \.self) { i in
                let phase = CGFloat((t / period + Double(i) / 2).truncatingRemainder(dividingBy: 1))
                Circle()
                    .stroke(color, lineWidth: 1.5 - phase)
                    .frame(width: Self.diameter, height: Self.diameter)
                    // Grows out to ~64pt, inside the 96pt canvas.
                    .scaleEffect(1 + phase * 1.6)
                    .opacity(Double(1 - phase) * strength)
            }
        }
    }

    private var palette: (core: Color, halo: Color, deep: Color) {
        switch style {
        case .transcribing:
            (Color(red: 0.88, green: 1.0, blue: 1.0),   // white-hot cyan
             Color(red: 0.0, green: 0.85, blue: 1.0),   // electric cyan
             Color(red: 0.35, green: 0.2, blue: 0.9))   // indigo
        case .recording:
            (Color(red: 1.0, green: 0.9, blue: 0.97),   // white-hot pink
             Color(red: 1.0, green: 0.15, blue: 0.65),  // hot magenta
             Color(red: 0.5, green: 0.1, blue: 0.9))    // violet
        }
    }
}
