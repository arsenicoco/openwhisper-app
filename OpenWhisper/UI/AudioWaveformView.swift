import SwiftUI

private let teal = Color(red: 0.08, green: 0.72, blue: 0.65)

/// Vertical equalizer bars that ride the mic level — sized to sit inside the orb.
struct VoiceBars: View {
    let level: Float

    private let barWidth: CGFloat = 3
    private let barCount = 4
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 22
    /// Per-bar height weighting so the middle bars run taller.
    private let multipliers: [CGFloat] = [0.55, 1.0, 0.8, 0.45]

    @State private var heights: [CGFloat] = [4, 4, 4, 4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(teal)
                    .frame(width: barWidth, height: heights[index])
            }
        }
        .frame(height: maxHeight)
        .onChange(of: level) { _, newLevel in
            updateBars(newLevel)
        }
        .onAppear {
            updateBars(level)
        }
    }

    private func updateBars(_ inputLevel: Float) {
        let normalized = CGFloat(min(max(inputLevel * 8, 0), 1.0))

        for i in 0..<barCount {
            let stagger = Double(i) * 0.06
            let target = minHeight + (maxHeight - minHeight) * normalized * multipliers[i]
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55).delay(stagger)) {
                heights[i] = target
            }
        }
    }
}

/// Soft ring around the orb that expands with the mic level.
struct LevelHalo: View {
    let level: Float
    let size: CGFloat
    let color: Color

    private var normalized: CGFloat {
        CGFloat(min(max(level * 8, 0), 1.0))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 1.5)
                .frame(width: size + 4, height: size + 4)
                .scaleEffect(1 + normalized * 0.16)
                .opacity(0.5 + Double(normalized) * 0.5)

            Circle()
                .fill(color.opacity(0.12))
                .frame(width: size + 4, height: size + 4)
                .scaleEffect(1 + normalized * 0.22)
                .blur(radius: 6)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: normalized)
    }
}

/// Arc that spins continuously — used while transcribing.
struct RotatingArc: View {
    let size: CGFloat
    let color: Color

    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

/// Ring that fills as the model downloads (indeterminate sweep when progress is unknown).
struct ModelLoadRing: View {
    let progress: Double
    let size: CGFloat
    let color: Color

    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 2)

            if progress > 0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: progress)
            } else {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(angle))
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            angle = 360
                        }
                    }
            }
        }
        .frame(width: size, height: size)
    }
}

struct BouncingDots: View {
    private let dotSize: CGFloat = 5
    private let dotCount = 3

    @State private var activeIndex = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(teal.opacity(index == activeIndex ? 1.0 : 0.4))
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: index == activeIndex ? -4 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: activeIndex)
            }
        }
        .onAppear { startLoop() }
    }

    private func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            activeIndex = (activeIndex + 1) % dotCount
        }
    }
}
