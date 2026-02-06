import SwiftUI
import AppKit

struct PixelIconView: View {
    let image: NSImage?
    let size: CGFloat
    let tint: Color?

    init(path: String?, size: CGFloat, tint: Color? = nil) {
        self.image = PixelAssetCatalog.shared.image(for: path)
        self.size = size
        self.tint = tint
    }

    init(image: NSImage?, size: CGFloat, tint: Color? = nil) {
        self.image = image
        self.size = size
        self.tint = tint
    }

    var body: some View {
        if let image {
            if let tint {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(tint)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            }
        } else {
            Rectangle()
                .fill(Color.clear)
                .frame(width: size, height: size)
        }
    }
}

struct PixelSpriteView: View {
    let spriteId: String
    var size: CGFloat = 18
    var tint: Color? = nil
    var isActive: Bool = true
    var bobAmplitude: CGFloat = 1.5
    var bobPeriod: Double = 1.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        let sprite = PixelAssetCatalog.shared.sprite(for: spriteId)
        let useIdle = !isActive
        let frames = PixelAssetCatalog.shared.frames(for: spriteId, idle: useIdle)
        if let first = frames.first {
            let shouldAnimateFrames = !reduceMotion && frames.count > 1
            let shouldBob = isActive && !reduceMotion && bobAmplitude != 0
            if shouldAnimateFrames || shouldBob {
                AnimatedPixelSpriteView(
                    frames: frames,
                    fps: max(1.0, sprite?.fps ?? 1.0),
                    useIdle: useIdle,
                    shouldAnimateFrames: shouldAnimateFrames,
                    shouldBob: shouldBob,
                    bobAmplitude: bobAmplitude,
                    bobPeriod: bobPeriod,
                    size: size,
                    tint: tint
                )
            } else {
                PixelIconView(image: first, size: size, tint: tint)
                    .frame(width: size, height: size)
            }
        } else {
            PixelIconView(image: nil, size: size, tint: tint)
                .frame(width: size, height: size)
        }
    }
}

private struct AnimatedPixelSpriteView: View {
    let frames: [NSImage]
    let fps: Double
    let useIdle: Bool
    let shouldAnimateFrames: Bool
    let shouldBob: Bool
    let bobAmplitude: CGFloat
    let bobPeriod: Double
    let size: CGFloat
    let tint: Color?

    @EnvironmentObject private var spriteClock: SpriteClock

    var body: some View {
        let time = spriteClock.time
        let image = frameImage(time: time)
        let offset = bobOffset(time: time)
        return PixelIconView(image: image, size: size, tint: tint)
            .offset(y: offset)
            .frame(width: size, height: size)
    }

    private func frameImage(time: Double) -> NSImage? {
        guard let first = frames.first else { return nil }
        guard shouldAnimateFrames else { return first }
        let effectiveFps = useIdle ? max(1.0, fps * 0.6) : fps
        let frameIndex = Int((time * effectiveFps).rounded(.down)) % frames.count
        return frames[frameIndex]
    }

    private func bobOffset(time: Double) -> CGFloat {
        guard shouldBob else { return 0 }
        let phase = (time / bobPeriod) * 2.0 * Double.pi
        return CGFloat(sin(phase)) * bobAmplitude
    }
}
