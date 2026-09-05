import AppKit

/// Tuning values in screen points and seconds. Keep the interaction policy out
/// of the integrator so changing the feel doesn't change the physics code.
enum QuickAccessMotionStyle {
    static let screenInset: CGFloat = 16
    static let flickProjectionTime: TimeInterval = 0.18
    static let maximumReleaseSpeed: CGFloat = 2_400
    static let releasePause: TimeInterval = 0.1
    static let minimumDragSampleTime: TimeInterval = 0.001

    // A unit-mass spring: acceleration = stiffness * displacement - damping * velocity.
    static let stiffness: CGFloat = 320
    static let damping: CGFloat = 32
    static let frameInterval: TimeInterval = 1 / 120
    static let maximumFrameTime: TimeInterval = 1 / 30
    static let integrationSubsteps = 4
    static let settledDistance: CGFloat = 0.5
    static let settledSpeed: CGFloat = 4

    static let entranceOffset: CGFloat = 20
    static let fadeInDuration: TimeInterval = 0.3
    static let evictionMargin: CGFloat = 40
    static let evictionDuration: TimeInterval = 0.38
    static let fadeOutDuration: TimeInterval = 0.2
}

/// Floating-point state is independent of AppKit's pixel-rounded window frame.
/// Retargeting changes only the destination; current position and velocity survive.
struct QuickAccessSpring {
    var position: CGPoint
    var velocity: CGPoint = .zero
    var target: CGPoint

    var isSettled: Bool {
        hypot(position.x - target.x, position.y - target.y) < QuickAccessMotionStyle.settledDistance
            && hypot(velocity.x, velocity.y) < QuickAccessMotionStyle.settledSpeed
    }

    mutating func advance(elapsed: TimeInterval) {
        let dt = min(max(0, elapsed), QuickAccessMotionStyle.maximumFrameTime)
            / Double(QuickAccessMotionStyle.integrationSubsteps)
        for _ in 0..<QuickAccessMotionStyle.integrationSubsteps {
            velocity.x += acceleration(displacement: target.x - position.x, velocity: velocity.x) * dt
            velocity.y += acceleration(displacement: target.y - position.y, velocity: velocity.y) * dt
            position.x += velocity.x * dt
            position.y += velocity.y * dt
        }
    }

    private func acceleration(displacement: CGFloat, velocity: CGFloat) -> CGFloat {
        QuickAccessMotionStyle.stiffness * displacement - QuickAccessMotionStyle.damping * velocity
    }
}
