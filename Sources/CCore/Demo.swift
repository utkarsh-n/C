import Foundation

public enum CDemoChapter: String, CaseIterable, Identifiable, Sendable {
    case integrals, code, sound
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var firstStep: CDemoStep {
        switch self {
        case .integrals: .constant
        case .code: .types
        case .sound: .semitone
        }
    }
}

public enum CDemoStep: String, CaseIterable, Identifiable, Sendable {
    case constant, anchor, area, types, aliases, loops, semitone, octave, scale
    public var id: String { rawValue }
    public var index: Int { Self.allCases.firstIndex(of: self)! }
    public var chapter: CDemoChapter {
        switch self {
        case .constant, .anchor, .area: .integrals
        case .types, .aliases, .loops: .code
        case .semitone, .octave, .scale: .sound
        }
    }
    public var title: String {
        switch self {
        case .constant: "Why integrals have +C"
        case .anchor: "One point chooses a curve"
        case .area: "Turn area into an algorithm"
        case .types: "When division loses a fraction"
        case .aliases: "Follow a pointer, then a reference"
        case .loops: "Watch a loop add three values"
        case .semitone: "Hear the step from C to C♯"
        case .octave: "Double a frequency"
        case .scale: "Play the shape of C major"
        }
    }
    public var duration: Double {
        switch self {
        case .constant: 12
        case .anchor: 10
        case .area: 16
        case .types: 16
        case .aliases: 20
        case .loops: 18
        case .semitone: 12
        case .octave: 15
        case .scale: 12
        }
    }
}

/// One elapsed-time owner drives visuals and discrete modeled events.
/// Audio is scheduled by the sound panel only at accepted phase changes.
public struct CDemoPlayback: Equatable, Sendable {
    public private(set) var step: CDemoStep = .constant
    public private(set) var elapsed: Double = 0
    public private(set) var isPlaying = false
    public private(set) var hasFinished = false
    public var progress: Double { min(1, max(0, elapsed / step.duration)) }

    public init() {}

    public mutating func play() {
        if hasFinished { select(.constant) }
        isPlaying = true
    }
    public mutating func pause() { isPlaying = false }
    public mutating func select(_ step: CDemoStep) {
        self.step = step
        elapsed = 0
        isPlaying = false
        hasFinished = false
    }
    public mutating func seek(to progress: Double) {
        guard progress.isFinite else { return }
        elapsed = min(1, max(0, progress)) * step.duration
        isPlaying = false
        hasFinished = false
    }
    public mutating func replay() {
        elapsed = 0
        hasFinished = false
        isPlaying = true
    }
    public mutating func advance(by seconds: Double) {
        guard isPlaying, seconds.isFinite, seconds > 0 else { return }
        var remaining = seconds
        while remaining > 0, isPlaying {
            let available = step.duration - elapsed
            if remaining < available {
                elapsed += remaining
                remaining = 0
            } else {
                remaining -= available
                if step == .scale {
                    elapsed = step.duration
                    isPlaying = false
                    hasFinished = true
                } else {
                    step = CDemoStep.allCases[step.index + 1]
                    elapsed = 0
                }
            }
        }
    }
}
