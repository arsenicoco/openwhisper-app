import SwiftUI

struct FlowBarView: View {
    @Environment(AppState.self) var appState

    /// Diameter of the orb — 50% larger than the old 32pt pill.
    static let orbSize: CGFloat = 48
    /// Canvas the orb sits in, leaving room for the audio-reactive halo.
    static let canvasSize: CGFloat = 64

    var body: some View {
        ZStack {
            halo

            orbBackground

            switch appState.recordingState {
            case .idle:
                idleContent
            case .recording:
                recordingContent
            case .transcribing:
                transcribingContent
            }
        }
        .frame(width: Self.canvasSize, height: Self.canvasSize)
        .opacity(isIdle ? 0.45 : 1.0)
        .animation(.spring(duration: 0.3), value: appState.recordingState)
    }

    private var isIdle: Bool {
        appState.recordingState == .idle
    }

    // MARK: - Orb chrome

    private var orbBackground: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(Color.black.opacity(0.35))
            Circle()
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
        .frame(width: Self.orbSize, height: Self.orbSize)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
    }

    /// Ring that breathes with the mic level while recording, and spins while transcribing.
    @ViewBuilder
    private var halo: some View {
        switch appState.recordingState {
        case .idle:
            EmptyView()
        case .recording:
            LevelHalo(level: appState.audioLevel, size: Self.orbSize, color: .red)
        case .transcribing:
            RotatingArc(size: Self.orbSize + 6, color: tealColor)
        }
    }

    // MARK: - Idle

    private var idleContent: some View {
        ZStack {
            if appState.modelLoading {
                ModelLoadRing(progress: appState.modelLoadProgress,
                              size: Self.orbSize - 8,
                              color: tealColor)

                if appState.modelIsDownloading, appState.modelLoadProgress > 0 {
                    Text("\(Int(appState.modelLoadProgress * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else if !appState.modelLoaded {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.orange.opacity(0.85))
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Recording

    private var recordingContent: some View {
        VoiceBars(level: appState.audioLevel)
    }

    // MARK: - Transcribing

    private var transcribingContent: some View {
        BouncingDots()
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
