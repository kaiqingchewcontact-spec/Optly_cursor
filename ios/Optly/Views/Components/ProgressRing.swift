import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var gradient: LinearGradient = LinearGradient(
        colors: [.Optly.indigo, .Optly.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    var trackColor: Color = Color.primary.opacity(0.08)
    var centerTitle: String?
    var centerSubtitle: String?

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        lineWidth: CGFloat = 12,
        gradient: LinearGradient? = nil,
        trackColor: Color = Color.primary.opacity(0.08),
        centerTitle: String? = nil,
        centerSubtitle: String? = nil
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.gradient = gradient ?? LinearGradient(
            colors: [.Optly.indigo, .Optly.teal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        self.trackColor = trackColor
        self.centerTitle = centerTitle
        self.centerSubtitle = centerSubtitle
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let centerTitle {
                VStack(spacing: 2) {
                    Text(centerTitle)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    if let centerSubtitle {
                        Text(centerSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.85)) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.45)) {
                animatedProgress = min(max(newValue, 0), 1)
            }
        }
    }
}

#Preview("Rings") {
    HStack(spacing: 32) {
        ProgressRing(progress: 0.72, lineWidth: 14, centerTitle: "72%", centerSubtitle: "Habit")
            .frame(width: 120, height: 120)

        ProgressRing(
            progress: 0.45,
            lineWidth: 10,
            gradient: LinearGradient(colors: [.Optly.purple, .Optly.orange], startPoint: .leading, endPoint: .trailing),
            centerTitle: "27:00",
            centerSubtitle: "remaining"
        )
        .frame(width: 100, height: 100)
    }
    .padding()
}
