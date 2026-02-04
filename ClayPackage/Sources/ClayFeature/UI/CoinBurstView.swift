import SwiftUI
import AppKit

struct CoinBurstView: View {
    let trigger: Int
    let icon: NSImage?
    var color: Color = ClayTheme.accentWarm
    var count: Int = 12
    var maxDistance: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [BurstParticle] = []
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                CoinParticleView(
                    particle: particle,
                    icon: icon,
                    color: color,
                    animate: animate,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
        .onAppear {
            spawn()
        }
        .onChange(of: trigger) { _ in
            spawn()
        }
    }

    private func spawn() {
        particles = (0..<count).map { _ in
            BurstParticle(
                angle: Double.random(in: (-0.85 * Double.pi)...(-0.15 * Double.pi)),
                distance: CGFloat.random(in: maxDistance * 0.6...maxDistance),
                delay: Double.random(in: 0.0...0.12),
                size: CGFloat.random(in: 8...12),
                rotation: Double.random(in: -45...45)
            )
        }
        animate = false
        if reduceMotion {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                particles.removeAll()
            }
            return
        }
        withAnimation(.easeOut(duration: 0.7)) {
            animate = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particles.removeAll()
        }
    }
}

private struct BurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let delay: Double
    let size: CGFloat
    let rotation: Double
}

private struct CoinParticleView: View {
    let particle: BurstParticle
    let icon: NSImage?
    let color: Color
    let animate: Bool
    let reduceMotion: Bool

    var body: some View {
        let offset = CGSize(
            width: CGFloat(cos(particle.angle)) * particle.distance,
            height: CGFloat(sin(particle.angle)) * particle.distance
        )
        let scale = animate ? 0.8 : 0.4
        let opacity = animate ? 0.0 : 1.0
        let animation = reduceMotion ? nil : Animation.easeOut(duration: 0.7).delay(particle.delay)

        Group {
            if let icon {
                PixelIconView(image: icon, size: particle.size, tint: nil)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: particle.size, height: particle.size)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .offset(animate ? offset : .zero)
        .scaleEffect(scale)
        .opacity(opacity)
        .rotationEffect(.degrees(animate ? particle.rotation : 0))
        .animation(animation, value: animate)
    }
}
