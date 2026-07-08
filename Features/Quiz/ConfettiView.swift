import SwiftUI

/// Pure-SwiftUI confetti burst (`Canvas`/`TimelineView`, per SPEC §7.4) — no
/// third-party particle library. Particle count scales with `intensity`
/// (0...1, the score fraction) so a perfect score gets extra flourish.
struct ConfettiView: View {
    let intensity: Double

    @State private var startDate = Date()
    @State private var isPaused = false

    private static let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    private let particles: [Particle]
    private let maxDuration: Double

    private struct Particle {
        let xFraction: Double
        let delay: Double
        let duration: Double
        let rotationSpeed: Double
        let color: Color
        let size: CGFloat
    }

    init(intensity: Double) {
        self.intensity = intensity
        var generator = SystemRandomNumberGenerator()
        let count = Int(30 + intensity.clamped(to: 0...1) * 60)
        particles = (0..<count).map { _ in
            Particle(
                xFraction: Double.random(in: 0...1, using: &generator),
                delay: Double.random(in: 0...0.3, using: &generator),
                duration: Double.random(in: 1.0...1.6, using: &generator),
                rotationSpeed: Double.random(in: 180...540, using: &generator),
                color: Self.colors.randomElement(using: &generator) ?? .yellow,
                size: CGFloat.random(in: 6...11, using: &generator)
            )
        }
        maxDuration = (particles.map { $0.delay + $0.duration }.max() ?? 1.6)
    }

    var body: some View {
        TimelineView(.animation(paused: isPaused)) { context in
            Canvas { canvasContext, size in
                let elapsed = context.date.timeIntervalSince(startDate)
                for particle in particles {
                    let localElapsed = elapsed - particle.delay
                    guard localElapsed > 0, localElapsed < particle.duration else { continue }
                    let progress = localElapsed / particle.duration
                    let x = particle.xFraction * size.width
                    let y = progress * size.height
                    let opacity = progress > 0.8 ? (1 - progress) / 0.2 : 1
                    let rect = CGRect(x: -particle.size / 2, y: -particle.size / 2, width: particle.size, height: particle.size)

                    canvasContext.drawLayer { layer in
                        layer.translateBy(x: x, y: y)
                        layer.rotate(by: .degrees(particle.rotationSpeed * localElapsed))
                        layer.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(particle.color.opacity(opacity)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .task {
            startDate = Date()
            try? await Task.sleep(for: .seconds(maxDuration + 0.1))
            isPaused = true
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
