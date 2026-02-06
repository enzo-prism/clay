import Foundation
import SwiftUI

@MainActor
final class SpriteClock: ObservableObject {
    @Published private(set) var tick: Int = 0
    let fps: Double = 12
    private var timer: Timer?
    private var startTime: TimeInterval

    init() {
        startTime = Date().timeIntervalSinceReferenceDate
    }

    var time: TimeInterval {
        startTime + (Double(tick) / fps)
    }

    func start() {
        if timer != nil {
            return
        }
        let now = Date().timeIntervalSinceReferenceDate
        startTime = now - (Double(tick) / fps)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tick &+= 1
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
