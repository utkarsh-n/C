import SwiftUI
import AVFoundation
import CCore

struct MusicLabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var pitchClass: PitchClass = .c
    @State private var octave = 4
    @State private var cents = 0.0
    @State private var scale: MusicScale = .cMajor
    @State private var audio = ToneEngine()

    private var pitch: MusicalPitch { MusicalPitch(pitchClass: pitchClass, octave: octave, cents: cents) }
    private var cPitch: MusicalPitch { MusicalPitch(pitchClass: .c, octave: octave) }
    private var sharpPitch: MusicalPitch { MusicalPitch(pitchClass: .cSharp, octave: octave) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LabHeader(eyebrow: "03 / Music", title: "C notes", subtitle: "One letter, many pitches. Hear C, raise it to C♯, and see what a semitone changes.")
                PitchWheel(pitch: pitch)
                InstrumentParameterStepper("Octave", value: $octave, in: 2...6, unit: "",
                                           onAcceptedChange: { _ in CFeedback.selection() })
                    .accessibilityIdentifier("music.octave")
                playbackControls
                keyboardPanel
                tuningPanel
                MusicWaveform(pitch: pitch)
                comparePanel
                scalePanel
                LabNote(title: "Pitch is a frequency ratio", text: "This lab uses 12-tone equal temperament (12-TET), with A4 = 440 Hz. An octave doubles the frequency. Twelve equal multiplicative steps make an octave; they are not equal additions of hertz.", equation: "f = 440 × 2^((m − 69)/12 + cents/1200)")
                LabNote(title: "C♯ and D♭", text: "On this equal-tempered keyboard, C♯ and D♭ share one pitch. Their names describe different musical roles: a raised C or a lowered D. Other tuning systems can distinguish these pitches. Middle C is called C4 here (MIDI 60); some instruments use another octave-label convention.")
                LabNote(title: "What you hear", text: "Each tap plays a short, synthesized sine wave with a smooth attack and release. It is a pitch demonstration, not a recorded piano. The waveform is a static mathematical model, not microphone input or a live audio meter. The silent switch and system volume apply. Leaving this tab or backgrounding stops playback.")
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(InstrumentDesignBackground())
        .navigationTitle("C notes")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { audio.stop(reason: "Ready · tap a key to hear it") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { audio.stop(reason: "Paused · tap a key to resume") }
        }
        .onChange(of: octave) { _, _ in audio.stop(reason: "Octave changed · tap to hear it") }
        .onChange(of: cents) { _, _ in audio.stop(reason: "Tuning changed · tap to hear it") }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).receive(on: RunLoop.main)) { audio.interruption($0) }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main)) { audio.routeChanged($0) }
        .onReceive(NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange).receive(on: RunLoop.main)) { _ in
            if audio.isPlaying { audio.stop(reason: "Audio route changed · tap to resume") }
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { playAction; stopAction }
                VStack(spacing: 12) { playAction; stopAction }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: audio.isPlaying ? "waveform" : "speaker")
                    .foregroundStyle(audio.isPlaying ? InstrumentPalette.actionAmber : InstrumentPalette.secondaryInk)
                Text(audio.status).font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("music.playbackStatus")
        }
    }

    private var playAction: some View {
        LabAction(title: "Hear \(pitch.displayName)", symbol: "play.fill", accent: InstrumentPalette.actionAmber) {
            CFeedback.event()
            audio.play(pitch)
        }.accessibilityIdentifier("music.playNote")
    }

    private var stopAction: some View {
        LabAction(title: "Stop", symbol: "stop.fill") { audio.stop() }
            .disabled(!audio.isPlaying)
            .accessibilityIdentifier("music.stop")
    }

    private var keyboardPanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("One octave · tap any key").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                ScrollView(.horizontal) {
                    MusicKeyboard(selected: pitchClass, octave: octave) { note in
                        pitchClass = note
                        CFeedback.selection()
                        audio.play(MusicalPitch(pitchClass: note, octave: octave, cents: cents))
                    }
                    .padding(.vertical, 4)
                }
                Text("White keys: C D E F G A B. Black keys: the intervening sharps and flats.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tuningPanel: some View {
        InstrumentContentPanel {
            VStack(spacing: 12) {
                CSlider(title: "Detune selected pitch", value: $cents, range: -100...100, step: 1,
                        formatted: "\(cents >= 0 ? "+" : "")\(Int(cents)) cents")
                HStack {
                    Text("100 cents = 1 semitone").font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    Spacer()
                    Button("Reset tuning") { cents = 0; CFeedback.selection() }
                        .font(.subheadline).foregroundStyle(InstrumentPalette.actionCyan)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("music.resetTuning")
                }
            }
        }
    }

    private var comparePanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("C → C♯: one semitone").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                HStack(alignment: .firstTextBaseline) {
                    InstrumentMetricReadout("C\(octave)", value: cPitch.frequency.formatted(.number.precision(.fractionLength(2))), unit: "Hz")
                    Spacer()
                    InstrumentMetricReadout("C♯\(octave)", value: sharpPitch.frequency.formatted(.number.precision(.fractionLength(2))), unit: "Hz", color: InstrumentPalette.spectrum)
                }
                Text("×1.05946 frequency · +5.946% · +100 cents")
                    .font(.system(.callout, design: .monospaced)).foregroundStyle(InstrumentPalette.actionCyan)
                    .fixedSize(horizontal: false, vertical: true)
                LabAction(title: "Hear C then C♯", symbol: "arrow.right", accent: InstrumentPalette.spectrum) {
                    CFeedback.event()
                    audio.compare(octave: octave)
                }.accessibilityIdentifier("music.compare")
                Text("Comparison uses exact 12-TET pitches, without the detune control.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    private var scalePanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Build a scale").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                    Spacer()
                    Picker("Scale", selection: $scale) {
                        ForEach(MusicScale.allCases) { item in Text(item.title).tag(item) }
                    }.pickerStyle(.menu).tint(InstrumentPalette.actionCyan)
                        .accessibilityIdentifier("music.scale")
                }
                Text(scale.spelling).font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(InstrumentPalette.displayInk).fixedSize(horizontal: false, vertical: true)
                Text("\(scale.intervalPattern)\nW = whole step (2 semitones) · H = half step (1)")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                LabAction(title: "Hear \(scale.title)", symbol: "music.note.list") {
                    CFeedback.event()
                    audio.playScale(scale, octave: min(octave, 5), cents: cents)
                }.accessibilityIdentifier("music.playScale")
                Text("Starts in octave \(min(octave, 5)) and ends one octave higher. Uses the selected detuning.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }
}

private struct PitchWheel: View {
    let pitch: MusicalPitch
    @ScaledMetric(relativeTo: .largeTitle) private var noteSize = 62.0

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                let diameter = min(geometry.size.width, 310)
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().stroke(LinearGradient(colors: [.white.opacity(0.3), .black, .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.4))
                        .shadow(color: .black.opacity(0.65), radius: 16, y: 10)
                    InstrumentLensSurface(diameter: diameter) {
                        PitchWheelFace(selected: pitch.pitchClass)
                    } readout: {
                        VStack(spacing: 6) {
                            Text("SELECTED PITCH").font(.system(.caption2, design: .monospaced)).tracking(1.5)
                                .foregroundStyle(InstrumentPalette.secondaryInk)
                            Text(pitch.displayName).font(.system(size: noteSize, weight: .light, design: .rounded))
                                .monospacedDigit().foregroundStyle(InstrumentPalette.displayInk)
                                .lineLimit(1).minimumScaleFactor(0.45)
                                .accessibilityIdentifier("music.pitch")
                            Text("\(pitch.frequency.formatted(.number.precision(.fractionLength(2)))) Hz")
                                .font(.system(.title3, design: .rounded)).monospacedDigit().foregroundStyle(InstrumentPalette.actionCyan)
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .accessibilityIdentifier("music.frequency")
                            Text("MIDI \(pitch.midiNumber)").font(.system(.caption, design: .monospaced))
                                .foregroundStyle(InstrumentPalette.secondaryInk)
                        }.frame(width: diameter * 0.56)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Selected pitch \(pitch.pitchClass.spokenName), octave \(pitch.octave), \(Int(pitch.cents)) cents detuning")
                            .accessibilityValue("\(pitch.frequency.formatted(.number.precision(.fractionLength(2)))) hertz, MIDI \(pitch.midiNumber)")
                            .accessibilityIdentifier("music.selectedPitch")
                    }
                }.frame(width: diameter, height: diameter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(height: 310)
            Text("12 pitch classes · A4 reference = 440 Hz").font(.system(.caption, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk)
        }
    }
}

private struct PitchWheelFace: View {
    let selected: PitchClass
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.41
            for note in PitchClass.allCases {
                let angle = Double(note.rawValue) * .pi / 6 - .pi / 2
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                let label = Text(note.sharpName).font(.system(size: 11, weight: note == selected ? .bold : .regular, design: .monospaced))
                    .foregroundColor(note == selected ? InstrumentPalette.actionCyan : InstrumentPalette.secondaryInk)
                context.draw(label, at: point)
                let markRadius = radius * 0.82
                let mark = CGPoint(x: center.x + cos(angle) * markRadius, y: center.y + sin(angle) * markRadius)
                context.fill(Path(ellipseIn: CGRect(x: mark.x - 2, y: mark.y - 2, width: 4, height: 4)), with: .color(note == selected ? InstrumentPalette.actionCyan : .white.opacity(0.16)))
            }
        }
    }
}

private struct MusicKeyboard: View {
    let selected: PitchClass
    let octave: Int
    let onNote: (PitchClass) -> Void
    private let naturals: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
    private let accidentals: [(PitchClass, CGFloat)] = [(.cSharp, 1), (.dSharp, 2), (.fSharp, 4), (.gSharp, 5), (.aSharp, 6)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 3) {
                ForEach(naturals) { note in
                    Button { onNote(note) } label: {
                        VStack {
                            Spacer(minLength: 80)
                            Text(note.sharpName).font(.system(.body, design: .rounded, weight: .semibold)).foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.17))
                        }
                        .padding(.bottom, 12).frame(width: 48, height: 144)
                        .background(selected == note ? InstrumentPalette.actionCyan : Color(red: 0.78, green: 0.86, blue: 0.88), in: .rect(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.3)))
                        .contentShape(.rect)
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(note.spokenName), octave \(octave)")
                        .accessibilityHint("Plays a short synthesized note")
                        .accessibilityAddTraits(selected == note ? .isSelected : [])
                        .accessibilitySortPriority(Double(12 - note.rawValue))
                        .accessibilityIdentifier("music.key.\(note.rawValue)")
                }
            }
            ForEach(accidentals, id: \.0) { note, boundary in
                Button { onNote(note) } label: {
                    VStack(spacing: 3) {
                        Spacer(minLength: 20)
                        Text(note.sharpName).font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text(note.flatName).font(.system(size: 11, design: .rounded))
                    }
                    .foregroundStyle(selected == note ? InstrumentPalette.canvas : InstrumentPalette.displayInk)
                    .padding(.bottom, 10).frame(width: 44, height: 88)
                    .background(selected == note ? InstrumentPalette.spectrum : Color(red: 0.03, green: 0.05, blue: 0.07), in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.25)))
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 3)
                    .contentShape(.rect)
                }.buttonStyle(.plain)
                    .offset(x: boundary * 51 - 23.5)
                    .accessibilityLabel("\(note.spokenName), octave \(octave)")
                    .accessibilityHint("Plays a short synthesized note")
                    .accessibilityAddTraits(selected == note ? .isSelected : [])
                    .accessibilitySortPriority(Double(12 - note.rawValue))
                    .accessibilityIdentifier("music.key.\(note.rawValue)")
            }
        }.frame(width: 354, height: 144)
    }
}

private struct MusicWaveform: View {
    let pitch: MusicalPitch
    var body: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Static sine model · 3 periods").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                Canvas { context, size in
                    var axis = Path()
                    axis.move(to: CGPoint(x: 0, y: size.height / 2))
                    axis.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    context.stroke(axis, with: .color(.white.opacity(0.16)), lineWidth: 1)
                    var wave = Path()
                    let duration = 3 / pitch.frequency
                    for index in 0...360 {
                        let fraction = Double(index) / 360
                        let value = MusicSignal.sineSample(frequency: pitch.frequency, time: fraction * duration)
                        let point = CGPoint(x: fraction * size.width, y: size.height / 2 - value * size.height * 0.38)
                        if index == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
                    }
                    context.stroke(wave, with: .color(InstrumentPalette.wave), lineWidth: 2)
                }
                .frame(height: 94)
                .accessibilityHidden(true)
                HStack {
                    Text("0 ms")
                    Spacer()
                    Text("\((3_000 / pitch.frequency).formatted(.number.precision(.fractionLength(2)))) ms")
                }.font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
                Text("One period = \(pitch.periodMilliseconds.formatted(.number.precision(.fractionLength(3)))) ms. Normalized amplitude ±1.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
