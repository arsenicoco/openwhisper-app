import SwiftUI

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
