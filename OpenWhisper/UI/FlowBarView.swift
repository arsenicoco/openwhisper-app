import SwiftUI

struct FlowBarView: View {
    @Environment(AppState.self) var appState

    /// Diameter of the clickable/draggable area around the mic.
    static let hitSize: CGFloat = 48
    /// Transparent canvas the mic sits in, leaving room for the neon glow to bloom.
    static let canvasSize: CGFloat = 96

    var body: some View {
        ZStack {
            if isIdle {
                idleContent
                    .opacity(0.75)
                    // Collapses back down from the lit size.
                    .transition(.scale(scale: NeonMic.litSize / NeonMic.offSize).combined(with: .opacity))
            } else {
                // One view for recording and transcribing, so the tube re-colours instead of re-igniting.
                NeonMic(style: appState.recordingState == .transcribing
                        ? .transcribing
                        : .recording(level: normalizedLevel))
                    // Springs up from the resting size.
                    .transition(.scale(scale: NeonMic.offSize / NeonMic.litSize).combined(with: .opacity))
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
                    NeonMic(style: .off)
                }
            }
        } else if !appState.modelLoaded {
            Image(systemName: "mic.slash")
                .font(.system(size: NeonMic.offSize, weight: .light))
                .foregroundStyle(.orange)
                .shadow(color: .black.opacity(0.55), radius: 1.5)
        } else {
            NeonMic(style: .off)
        }
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
