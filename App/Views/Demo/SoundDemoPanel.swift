import SwiftUI
import AVFoundation
import CCore

/// The transport supplies the clock. The frequency display is a requested pitch;
/// ToneEngine separately reports the short note that has actually been scheduled.
struct SoundDemoPanel: View {
    let step: CDemoStep
    let progress: Double
    let isPlaying: Bool
    let onInteraction: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var audio = ToneEngine()
    @State private var manualPitch: MusicalPitch?
    @State private var manualKeyboardOctave = 4

    private var boundedProgress: Double { progress.isFinite ? min(1, max(0, progress)) : 0 }
    private var phaseCount: Int {
        switch step {
        case .semitone: 2
        case .octave: 3
        case .scale: 8
        default: 1
        }
    }
    private var phaseIndex: Int { min(phaseCount - 1, Int(boundedProgress * Double(phaseCount))) }
    private var guidedPitch: MusicalPitch {
        switch step {
        case .semitone:
            MusicalPitch(pitchClass: phaseIndex == 0 ? .c : .cSharp)
        case .octave:
            MusicalPitch(pitchClass: .c, octave: phaseIndex == 1 ? 5 : 4, cents: phaseIndex == 2 ? 100 : 0)
        case .scale:
            MusicScale.cMajor.notes(octave: 4)[phaseIndex]
        default:
            MusicalPitch(pitchClass: .c)
        }
    }
    private var pitch: MusicalPitch { manualPitch ?? guidedPitch }
    private var keyboardOctave: Int { manualPitch == nil ? guidedPitch.octave : manualKeyboardOctave }
    private var phaseTitles: [String] {
        switch step {
        case .semitone: ["C4", "C♯4"]
        case .octave: ["C4", "C5", "C4 +100¢"]
        case .scale: ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]
        default: ["C4"]
        }
    }
    private var explanation: String {
        switch step {
        case .semitone:
            "C♯ is one semitone above C. Its frequency is multiplied by 2¹ᐟ¹² ≈ 1.05946: 261.63 → 277.18 Hz. Equal steps in pitch use equal ratios."
        case .octave:
            "C5 vibrates twice as fast as C4: 523.25 Hz. Return to C4 and add 100 cents to reach 277.18 Hz, the same pitch as undetuned C♯4."
        case .scale:
            "Follow C · D · E · F · G · A · B · C. The steps are W W H W W W H, where W is two semitones and H is one. The last C is one octave higher."
        default:
            "An octave doubles frequency. A semitone multiplies it by 2¹ᐟ¹²."
        }
    }
    private var octaveBinding: Binding<Int> {
        Binding(get: { pitch.octave }, set: { value in
            manualKeyboardOctave = value
            select(MusicalPitch(pitchClass: pitch.pitchClass, octave: value, cents: pitch.cents), hear: false)
        })
    }
    private var centsBinding: Binding<Double> {
        Binding(get: { pitch.cents }, set: { value in
            select(MusicalPitch(pitchClass: pitch.pitchClass, octave: pitch.octave, cents: value), hear: false)
        })
    }

    var body: some View {
        VStack(spacing: 16) {
            InstrumentContentPanel {
                VStack(alignment: .leading, spacing: 16) {
                    pitchReadout
                    DemoSineTrace(pitch: pitch, sweep: boundedProgress, showsSweep: isPlaying && !reduceMotion)
                    sequenceStrip
                    Text(explanation)
                        .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            InstrumentContentPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Take the keyboard").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                    Text("Tap a key to pause the demo and hear your own pitch.")
                        .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    ScrollView(.horizontal) {
                        DemoSoundKeyboard(selected: pitch, octave: keyboardOctave) { note in
                            select(MusicalPitch(pitchClass: note, octave: keyboardOctave, cents: pitch.cents), hear: true)
                        }.padding(.vertical, 4)
                    }
                    InstrumentParameterStepper("Octave", value: octaveBinding, in: 2...6, unit: "",
                                               onAcceptedChange: { _ in CFeedback.selection() })
                        .accessibilityIdentifier("demo.sound.octave")
                    CSlider(title: "Detune selected pitch", value: centsBinding, range: -100...100, step: 1,
                            formatted: "\(pitch.cents >= 0 ? "+" : "")\(Int(pitch.cents)) cents")
                        .accessibilityIdentifier("demo.sound.cents")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { hearButton; stopButton }
                        VStack(spacing: 12) { hearButton; stopButton }
                    }
                    resetButton
                    Text(audio.status)
                        .font(.caption).foregroundStyle(audio.isPlaying ? InstrumentPalette.actionAmber : InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("demo.sound.status")
                    Text("Short sine tones · A4 = 440 Hz · 12-tone equal temperament. Turn Silent Mode off and use a comfortable volume. The waveform is modeled, not microphone input or an audio meter.")
                        .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { playGuidedPhase() }
        .onChange(of: phaseIndex) { _, _ in playGuidedPhase() }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                manualPitch = nil
                manualKeyboardOctave = 4
                playGuidedPhase()
            } else if manualPitch == nil, audio.isPlaying {
                // A key intentionally pauses the transport while playing one manual note.
                audio.stop(reason: "Paused · press Play or tap a key")
            }
        }
        .onDisappear { audio.stop(reason: "Ready · press Play or tap a key") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { halt(reason: "Paused in background · press Play to resume") }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).receive(on: RunLoop.main)) { notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            halt(reason: "Audio interrupted · press Play to resume")
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main)) { notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            halt(reason: "Audio device disconnected · press Play to resume")
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange).receive(on: RunLoop.main)) { _ in
            if audio.isPlaying { halt(reason: "Audio route changed · press Play to resume") }
        }
    }

    private var pitchReadout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(manualPitch == nil ? "FOLLOWING THE DEMO" : "YOUR SELECTED PITCH")
                .font(.system(.caption2, design: .monospaced)).tracking(1.4)
                .foregroundStyle(InstrumentPalette.secondaryInk)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 14) { noteName; frequency }
                VStack(alignment: .leading, spacing: 8) { noteName; frequency }
            }
            Text("MIDI \(pitch.midiNumber) · \(Int(pitch.cents)) cents · period \(pitch.periodMilliseconds.formatted(.number.precision(.fractionLength(3)))) ms")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pitch.pitchClass.spokenName), octave \(pitch.octave), \(Int(pitch.cents)) cents")
        .accessibilityValue("\(pitch.frequency.formatted(.number.precision(.fractionLength(2)))) hertz")
        .accessibilityIdentifier("demo.sound.pitch")
    }
    private var noteName: some View {
        Text(pitch.displayName)
            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            .foregroundStyle(InstrumentPalette.displayInk)
            .accessibilityIdentifier("demo.sound.note")
    }
    private var frequency: some View {
        Text("\(pitch.frequency.formatted(.number.precision(.fractionLength(2)))) Hz")
            .font(.system(.title2, design: .rounded, weight: .medium)).monospacedDigit()
            .foregroundStyle(InstrumentPalette.actionCyan)
            .accessibilityIdentifier("demo.sound.frequency")
    }
    private var sequenceStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(phaseTitles.enumerated()), id: \.offset) { index, title in
                    let sequencePitch = pitchForSequence(index)
                    let selected = manualPitch.map { $0 == sequencePitch } ?? (index == phaseIndex)
                    Button {
                        select(sequencePitch, hear: true)
                    } label: {
                        VStack(spacing: 4) {
                            Text(title).font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Image(systemName: selected ? "arrowtriangle.up.fill" : "music.note")
                                .font(.caption2)
                        }.foregroundStyle(selected ? InstrumentPalette.actionCyan : InstrumentPalette.secondaryInk)
                            .frame(minWidth: 54, minHeight: 54)
                            .padding(.horizontal, 6)
                            .background(.white.opacity(selected ? 0.09 : 0.025), in: .rect(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1)))
                    }.buttonStyle(.plain)
                        .instrumentControlOwnsTouches(identifier: "demo.sound.sequence.\(index)")
                        .accessibilityLabel("Hear \(title)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("demo.sound.sequence.\(index)")
                }
            }
        }
    }
    private var hearButton: some View {
        LabAction(title: "Hear \(pitch.displayName)", symbol: "speaker.wave.2.fill", accent: InstrumentPalette.actionAmber) {
            select(pitch, hear: true)
        }.accessibilityIdentifier("demo.sound.hear")
    }
    private var stopButton: some View {
        LabAction(title: "Stop sound", symbol: "stop.fill") {
            onInteraction()
            audio.stop(reason: "Stopped · press Play or tap a key")
        }.disabled(!audio.isPlaying)
            .accessibilityIdentifier("demo.sound.stop")
    }
    private var resetButton: some View {
        LabAction(title: "Reset tuning", symbol: "arrow.counterclockwise") {
            select(MusicalPitch(pitchClass: pitch.pitchClass, octave: pitch.octave), hear: false)
            CFeedback.selection()
        }.accessibilityIdentifier("demo.sound.reset")
    }
    private func select(_ selected: MusicalPitch, hear: Bool) {
        manualPitch = selected
        manualKeyboardOctave = selected.octave
        onInteraction()
        audio.stop(reason: "Pitch selected · tap Hear")
        if hear, scenePhase == .active {
            CFeedback.event()
            audio.play(selected)
        }
    }
    private func playGuidedPhase() {
        guard isPlaying, manualPitch == nil, scenePhase == .active else { return }
        audio.play(guidedPitch)
    }
    private func halt(reason: String) {
        onInteraction()
        audio.stop(reason: reason)
    }
    private func pitchForSequence(_ index: Int) -> MusicalPitch {
        switch step {
        case .semitone: MusicalPitch(pitchClass: index == 0 ? .c : .cSharp)
        case .octave: MusicalPitch(pitchClass: .c, octave: index == 1 ? 5 : 4, cents: index == 2 ? 100 : 0)
        case .scale: MusicScale.cMajor.notes(octave: 4)[index]
        default: MusicalPitch(pitchClass: .c)
        }
    }
}

private struct DemoSineTrace: View {
    let pitch: MusicalPitch
    let sweep: Double
    let showsSweep: Bool
    private let duration = 0.012

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SINE MODEL · SAME 12 ms WINDOW")
                .font(.system(.caption2, design: .monospaced)).tracking(1)
                .foregroundStyle(InstrumentPalette.secondaryInk)
            Canvas { context, size in
                var grid = Path()
                for division in 0...4 {
                    let x = Double(division) / 4 * size.width
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                grid.move(to: CGPoint(x: 0, y: size.height / 2))
                grid.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(grid, with: .color(.white.opacity(0.12)), lineWidth: 1)
                var wave = Path()
                for sample in 0...400 {
                    let fraction = Double(sample) / 400
                    let value = MusicSignal.sineSample(frequency: pitch.frequency, time: fraction * duration)
                    let point = CGPoint(x: fraction * size.width, y: size.height / 2 - value * size.height * 0.39)
                    if sample == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
                }
                context.stroke(wave, with: .color(InstrumentPalette.wave), lineWidth: 2)
                if showsSweep {
                    let x = sweep * size.width
                    var cursor = Path()
                    cursor.move(to: CGPoint(x: x, y: 0))
                    cursor.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(cursor, with: .color(InstrumentPalette.actionAmber.opacity(0.65)), lineWidth: 1.5)
                }
            }.frame(height: 106).accessibilityHidden(true)
            HStack {
                Text("0 ms")
                Spacer()
                Text("6 ms")
                Spacer()
                Text("12 ms")
            }.font(.system(.caption2, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
            Text("\((pitch.frequency * duration).formatted(.number.precision(.fractionLength(2)))) cycles in 12 ms · normalized amplitude ±1")
                .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
            .accessibilityIdentifier("demo.sound.waveform")
    }
}

private struct DemoSoundKeyboard: View {
    let selected: MusicalPitch
    let octave: Int
    let onNote: (PitchClass) -> Void
    private let naturals: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
    private let accidentals: [(PitchClass, CGFloat)] = [(.cSharp, 1), (.dSharp, 2), (.fSharp, 4), (.gSharp, 5), (.aSharp, 6)]

    private func isSelected(_ note: PitchClass) -> Bool { selected.pitchClass == note && selected.octave == octave }
    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 3) {
                ForEach(naturals) { note in
                    Button { onNote(note) } label: {
                        VStack {
                            Spacer(minLength: 76)
                            Text("\(note.sharpName)\(octave)")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(InstrumentPalette.canvas)
                        }.padding(.bottom, 12).frame(width: 48, height: 140)
                            .background(isSelected(note) ? InstrumentPalette.actionCyan : Color(red: 0.78, green: 0.86, blue: 0.88), in: .rect(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.3)))
                            .contentShape(.rect)
                    }.buttonStyle(.plain)
                        .instrumentControlOwnsTouches(identifier: "demo.sound.key.\(note.rawValue)")
                        .accessibilityLabel("Hear \(note.spokenName), octave \(octave)")
                        .accessibilityHint("Pauses the guided demo and plays a short tone using the selected detuning")
                        .accessibilityAddTraits(isSelected(note) ? .isSelected : [])
                        .accessibilitySortPriority(Double(12 - note.rawValue))
                        .accessibilityIdentifier("demo.sound.key.\(note.rawValue)")
                }
            }
            ForEach(accidentals, id: \.0) { note, boundary in
                Button { onNote(note) } label: {
                    VStack {
                        Spacer(minLength: 26)
                        Text(note.sharpName).font(.system(size: 13, weight: .semibold, design: .rounded))
                    }.foregroundStyle(isSelected(note) ? InstrumentPalette.canvas : InstrumentPalette.displayInk)
                        .padding(.bottom, 10).frame(width: 44, height: 86)
                        .background(isSelected(note) ? InstrumentPalette.spectrum : Color(red: 0.03, green: 0.05, blue: 0.07), in: .rect(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.3)))
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
                        .contentShape(.rect)
                }.buttonStyle(.plain)
                    .offset(x: boundary * 51 - 23.5)
                    .instrumentControlOwnsTouches(identifier: "demo.sound.key.\(note.rawValue)")
                    .accessibilityLabel("Hear \(note.spokenName), octave \(octave)")
                    .accessibilityHint("Pauses the guided demo and plays a short tone using the selected detuning")
                    .accessibilityAddTraits(isSelected(note) ? .isSelected : [])
                    .accessibilitySortPriority(Double(12 - note.rawValue))
                    .accessibilityIdentifier("demo.sound.key.\(note.rawValue)")
            }
        }.frame(width: 354, height: 140)
    }
}
