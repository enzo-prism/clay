import SwiftUI
import AppKit

struct KenneyIconView: View {
    let path: String?
    let size: CGFloat
    let tint: Color?
    
    init(path: String?, size: CGFloat, tint: Color? = nil) {
        self.path = path
        self.size = size
        self.tint = tint
    }
    
    var body: some View {
        if let path, let image = KenneyAssetCatalog.shared.image(for: path, template: tint != nil) {
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
