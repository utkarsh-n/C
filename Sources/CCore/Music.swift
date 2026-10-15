import Foundation

/// The twelve pitch classes used by this lab's 12-tone equal-temperament model.
public enum PitchClass: Int, CaseIterable, Sendable, Identifiable {
    case c, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    public var id: Int { rawValue }
    public var sharpName: String {
        ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][rawValue]
    }
    public var flatName: String {
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][rawValue]
    }
    public var isAccidental: Bool { sharpName != flatName }
    public var spokenName: String {
        ["C", "C sharp, or D flat", "D", "D sharp, or E flat", "E", "F",
         "F sharp, or G flat", "G", "G sharp, or A flat", "A", "A sharp, or B flat", "B"][rawValue]
    }
}

/// Scientific pitch notation: middle C is C4, MIDI number 60.
/// Octave and detuning are bounded to the app's deliberately small teaching range.
public struct MusicalPitch: Equatable, Sendable {
    public let pitchClass: PitchClass
    public let octave: Int
    public let cents: Double

    public init(pitchClass: PitchClass, octave: Int = 4, cents: Double = 0) {
        self.pitchClass = pitchClass
        self.octave = min(6, max(2, octave))
        self.cents = cents.isFinite ? min(100, max(-100, cents)) : 0
    }

    public var midiNumber: Int { 12 * (octave + 1) + pitchClass.rawValue }
    public var frequency: Double { MusicSignal.frequency(midiNumber: midiNumber, cents: cents) }
    public var displayName: String { "\(pitchClass.sharpName)\(octave)" }
    public var periodMilliseconds: Double { 1_000 / frequency }
}

public enum MusicScale: String, CaseIterable, Sendable, Identifiable {
    case cMajor, cSharpMinor
    public var id: String { rawValue }
    public var title: String { self == .cMajor ? "C major" : "C♯ natural minor" }
    public var intervalPattern: String { self == .cMajor ? "W W H W W W H" : "W H W W H W W" }
    public var spelling: String { self == .cMajor ? "C · D · E · F · G · A · B · C" : "C♯ · D♯ · E · F♯ · G♯ · A · B · C♯" }
    public var pitchClasses: [PitchClass] {
        self == .cMajor ? [.c, .d, .e, .f, .g, .a, .b, .c] : [.cSharp, .dSharp, .e, .fSharp, .gSharp, .a, .b, .cSharp]
    }

    /// Root octaves 2...5 allow the final tonic to remain in the lab's 2...6 range.
    public func notes(octave: Int, cents: Double = 0) -> [MusicalPitch] {
        let rootOctave = min(5, max(2, octave))
        return pitchClasses.enumerated().map { index, pitch in
            MusicalPitch(pitchClass: pitch, octave: rootOctave + (index == 7 ? 1 : 0), cents: cents)
        }
    }
}

public enum MusicSignal {
    public static let referenceFrequency = 440.0
    public static let referenceMIDINumber = 69
    public static let maximumAmplitude = 0.12
    public static let maximumNoteDuration = 0.8

    public static func frequency(midiNumber: Int, cents: Double = 0) -> Double {
        let boundedNote = min(127, max(0, midiNumber))
        let boundedCents = cents.isFinite ? min(100, max(-100, cents)) : 0
        return referenceFrequency * pow(2, Double(boundedNote - referenceMIDINumber) / 12 + boundedCents / 1_200)
    }

    public static func ratio(semitones: Double) -> Double {
        guard semitones.isFinite else { return 1 }
        return pow(2, min(120, max(-120, semitones)) / 12)
    }

    public static func centsBetween(lower: Double, upper: Double) -> Double? {
        guard lower.isFinite, upper.isFinite, lower > 0, upper > 0 else { return nil }
        return 1_200 * log2(upper / lower)
    }

    /// A mathematical trace, rather than microphone input or live output PCM.
    public static func sineSample(frequency: Double, time: Double) -> Double {
        guard frequency.isFinite, time.isFinite, frequency > 0 else { return 0 }
        return sin(2 * .pi * frequency * time)
    }

    /// Raised-cosine attack and release make a finite note start and finish at zero.
    public static func envelope(time: Double, duration: Double, attack: Double = 0.012, release: Double = 0.045) -> Double {
        guard time.isFinite, duration.isFinite, duration > 0, time > 0, time < duration else { return 0 }
        let attackTime = attack.isFinite ? min(duration / 2, max(0.001, attack)) : 0.012
        let releaseTime = release.isFinite ? min(duration / 2, max(0.001, release)) : 0.045
        let attackLevel = time < attackTime ? 0.5 - 0.5 * cos(.pi * time / attackTime) : 1
        let releaseLevel = time > duration - releaseTime ? 0.5 - 0.5 * cos(.pi * (duration - time) / releaseTime) : 1
        return min(attackLevel, releaseLevel)
    }

    /// Finite mono PCM for AVAudioPlayerNode. Invalid inputs return silence/no data;
    /// duration, sample rate, Nyquist frequency and amplitude have explicit bounds.
    public static func samples(frequency: Double, sampleRate: Double = 48_000, duration: Double = 0.6, amplitude: Double = maximumAmplitude) -> [Float] {
        guard sampleRate.isFinite, sampleRate >= 8_000, sampleRate <= 192_000,
              duration.isFinite, duration > 0, frequency.isFinite, frequency > 0,
              frequency < sampleRate / 2 else { return [] }
        let boundedDuration = min(maximumNoteDuration, duration)
        let count = max(2, Int((boundedDuration * sampleRate).rounded(.down)))
        let gain = amplitude.isFinite ? min(maximumAmplitude, max(0, amplitude)) : 0
        let exactDuration = Double(count - 1) / sampleRate
        return (0..<count).map { index in
            let time = Double(index) / sampleRate
            return Float(gain * envelope(time: time, duration: exactDuration) * sineSample(frequency: frequency, time: time))
        }
    }
}
