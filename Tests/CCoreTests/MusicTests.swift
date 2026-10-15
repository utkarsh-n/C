import Testing
@testable import CCore

@Suite("Musical C and C sharp")
struct MusicTests {
    @Test func tuningReferenceAndOctaveConvention() {
        #expect(MusicalPitch(pitchClass: .a).frequency == 440)
        let c = MusicalPitch(pitchClass: .c)
        #expect(c.midiNumber == 60)
        #expect(abs(c.frequency - 261.6255653005986) < 0.0000001)
        #expect(abs(MusicalPitch(pitchClass: .c, octave: 5).frequency / c.frequency - 2) < 0.0000001)
    }

    @Test func semitoneAndCents() {
        let c = MusicalPitch(pitchClass: .c)
        let sharp = MusicalPitch(pitchClass: .cSharp)
        #expect(abs(sharp.frequency / c.frequency - 1.0594630943592953) < 0.0000001)
        #expect(abs((MusicSignal.centsBetween(lower: c.frequency, upper: sharp.frequency) ?? 0) - 100) < 0.0000001)
        #expect(abs(MusicalPitch(pitchClass: .c, cents: 100).frequency - sharp.frequency) < 0.0000001)
        #expect(MusicSignal.centsBetween(lower: 0, upper: 440) == nil)
    }

    @Test func scalesReachTheNextTonic() {
        #expect(MusicScale.cMajor.notes(octave: 4).map(\.midiNumber) == [60, 62, 64, 65, 67, 69, 71, 72])
        #expect(MusicScale.cSharpMinor.notes(octave: 4).map(\.midiNumber) == [61, 63, 64, 66, 68, 69, 71, 73])
        #expect(MusicScale.cSharpMinor.pitchClasses.map(\.sharpName) == ["C♯", "D♯", "E", "F♯", "G♯", "A", "B", "C♯"])
        #expect(MusicScale.cMajor.notes(octave: 6).last?.octave == 6)
    }

    @Test func invalidInputsRemainBounded() {
        #expect(MusicalPitch(pitchClass: .c, octave: -8, cents: .nan).octave == 2)
        #expect(MusicalPitch(pitchClass: .b, octave: 90, cents: 9_000).cents == 100)
        #expect(MusicSignal.samples(frequency: 30_000, sampleRate: 48_000).isEmpty)
        #expect(MusicSignal.samples(frequency: .infinity).isEmpty)
        #expect(MusicSignal.samples(frequency: 440, sampleRate: .nan).isEmpty)
        #expect(MusicSignal.samples(frequency: 440, duration: -1).isEmpty)
    }

    @Test func envelopeAndSamplesHaveSilentBoundariesAndBoundedGain() {
        #expect(MusicSignal.envelope(time: 0, duration: 0.6) == 0)
        #expect(MusicSignal.envelope(time: 0.6, duration: 0.6) == 0)
        #expect(MusicSignal.envelope(time: 0.3, duration: 0.6) == 1)
        let data = MusicSignal.samples(frequency: 440, duration: 20, amplitude: 20)
        #expect(data.count == 38_400)
        #expect(data.first == 0)
        #expect(data.last == 0)
        #expect(data.allSatisfy { $0.isFinite && abs($0) <= Float(MusicSignal.maximumAmplitude) })
        #expect(data.contains { abs($0) > 0.1 })
        let silent = MusicSignal.samples(frequency: 440, amplitude: .nan)
        #expect(silent.allSatisfy { $0 == 0 })
    }
}
