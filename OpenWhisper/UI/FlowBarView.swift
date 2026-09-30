import SwiftUI

struct FlowBarView: View {
    @Environment(AppState.self) var appState

    /// Diameter of the clickable/draggable area around the mic.
    static let hitSize: CGFloat = 48
    /// Transparent canvas the indicator sits in, leaving room for the orb's glow and ripples.
    static let canvasSize: CGFloat = 96
    /// Resting mic glyph: small hairline so it barely sits on screen.
    static let micSize: CGFloat = 12

    var body: some View {
        ZStack {
            if isIdle {
                idleContent
                    .opacity(0.75)
                    // Collapses back down from the orb's size.
                    .transition(.scale(scale: PulsingOrb.diameter / Self.micSize).combined(with: .opacity))
            } else {
                // One view for recording and transcribing, so the orb re-colours instead of popping in again.
                PulsingOrb(style: appState.recordingState == .transcribing
                           ? .transcribing
                           : .recording(level: normalizedLevel))
                    // Springs up from the resting mic's size.
                    .transition(.scale(scale: Self.micSize / PulsingOrb.diameter).combined(with: .opacity))
            }
        }
        .frame(width: Self.canvasSize, height: Self.canvasSize)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isIdle)
    }

    private var isIdle: Bool {
        appState.recordingState == .idle
    }

    private var normalizedLevel: CGFloat {
        CGFloat(min(max(appState.audioLevel * 8, 0), 1))
    }

    // MARK: - Idle

    @ViewBuilder
    private var idleContent: some View {
        if appState.modelLoading {
            ZStack {
                ModelLoadRing(progress: appState.modelLoadProgress,
                              size: 28,
                              color: tealColor)
                    .shadow(color: .black.opacity(0.35), radius: 2)

                if appState.modelIsDownloading, appState.modelLoadProgress > 0 {
                    Text("\(Int(appState.modelLoadProgress * 100))")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 1.5)
                } else {
                    restingMic
                }
            }
        } else if !appState.modelLoaded {
            Image(systemName: "mic.slash")
                .font(.system(size: Self.micSize, weight: .light))
                .foregroundStyle(.orange)
                .shadow(color: .black.opacity(0.55), radius: 1.5)
        } else {
            restingMic
        }
    }

    /// Plain glyph with a soft dark edge so it reads on light backgrounds.
    private var restingMic: some View {
        Image(systemName: "mic")
            .font(.system(size: Self.micSize, weight: .light))
            .foregroundStyle(.white.opacity(0.9))
            .shadow(color: .black.opacity(0.6), radius: 1)
            .shadow(color: .black.opacity(0.2), radius: 3)
    }

    // MARK: - Helpers

    private var tealColor: Color {
        Color(red: 0.08, green: 0.72, blue: 0.65)
    }
}

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
