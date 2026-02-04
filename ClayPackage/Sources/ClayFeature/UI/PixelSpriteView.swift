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

    var body: some View {
        let sprite = PixelAssetCatalog.shared.sprite(for: spriteId)
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let offset = bobOffset(time: time)
            let image = frameImage(sprite: sprite, time: time)
            PixelIconView(image: image, size: size, tint: tint)
                .offset(y: offset)
        }
        .frame(width: size, height: size)
    }

    private func frameImage(sprite: PixelSpriteDefinition?, time: Double) -> NSImage? {
        guard let sprite else { return nil }
        let fps = max(1.0, sprite.fps)
        let useIdle = !isActive
        if useIdle, let sheet = sprite.idleSheet {
            let frameCount = PixelAssetCatalog.shared.frameCount(for: sheet)
            let index = frameCount > 0 ? Int((time * max(1.0, fps * 0.6)).rounded(.down)) % frameCount : 0
            return PixelAssetCatalog.shared.frameImage(from: sheet, frameIndex: index)
        }
        if let sheet = sprite.sheet {
            let frameCount = PixelAssetCatalog.shared.frameCount(for: sheet)
            let index = frameCount > 0 ? Int((time * fps).rounded(.down)) % frameCount : 0
            return PixelAssetCatalog.shared.frameImage(from: sheet, frameIndex: index)
        }
        guard !sprite.frames.isEmpty else { return nil }
        let frameIndex = Int((time * fps).rounded(.down)) % sprite.frames.count
        return PixelAssetCatalog.shared.image(for: sprite.frames[frameIndex])
    }

    private func bobOffset(time: Double) -> CGFloat {
        guard isActive, !reduceMotion else { return 0 }
        let phase = (time / bobPeriod) * 2.0 * Double.pi
        return CGFloat(sin(phase)) * bobAmplitude
    }
}
