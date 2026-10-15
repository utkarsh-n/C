import SwiftUI
import CCore

struct CDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback = CDemoPlayback()
    @State private var replayGeneration = 0
    let openLab: (CDemoChapter) -> Void

    private var accent: Color {
        switch playback.step.chapter {
        case .integrals: InstrumentPalette.actionCyan
        case .code: InstrumentPalette.actionAmber
        case .sound: InstrumentPalette.spectrum
        }
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header.id("demo-top")
                    chapters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(playback.step.index + 1) / 9  ·  \(playback.step.chapter.title.uppercased())")
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(accent)
                        Text(playback.step.title)
                            .font(.system(.title, design: .rounded, weight: .semibold))
                            .foregroundStyle(InstrumentPalette.displayInk)
                            .accessibilityIdentifier("demo.title")
                        Text("Play to watch. Touch a control to take over.")
                            .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    }
                    panel.id("\(playback.step.rawValue)-\(replayGeneration)")
                    if playback.hasFinished {
                        LabNote(title: "You played all three worlds", text: "A constant changes height, a pointer changes shared memory, and a semitone changes frequency. Keep exploring each instrument with your own values.")
                            .accessibilityIdentifier("demo.complete")
                    }
                    LabAction(title: "Explore the \(playback.step.chapter.title) lab", symbol: "arrow.up.right", accent: accent) {
                        playback.pause()
                        openLab(playback.step.chapter)
                        dismiss()
                    }.accessibilityIdentifier("demo.openLab")
                    Text("Modeled calculus and language examples. Sound uses A4 = 440 Hz and equal temperament; turn Silent Mode off to hear it.")
                        .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(20).frame(maxWidth: 660).frame(maxWidth: .infinity)
            }
            .onChange(of: playback.step) { _, _ in
                reader.scrollTo("demo-top", anchor: .top)
            }
        }
        .background { InstrumentDesignBackground() }
        .safeAreaInset(edge: .bottom, spacing: 0) { transport }
        .task {
            if ProcessInfo.processInfo.environment["C_UI_TESTING"] != "1" { playback.play() }
        }
        .task(id: playback.isPlaying) {
            guard playback.isPlaying else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            while playback.isPlaying, !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 50)) }
                catch { return }
                guard scenePhase == .active, !Task.isCancelled else { playback.pause(); return }
                let now = clock.now
                let interval = previous.duration(to: now).components
                previous = now
                // Long stalls pause the transport instead of skipping audible/visible events.
                let seconds = Double(interval.seconds) + Double(interval.attoseconds) / 1e18
                guard seconds < 1 else { playback.pause(); return }
                playback.advance(by: seconds)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { playback.pause() }
        }
        .onDisappear { playback.pause() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("C · PLAYABLE DEMO")
                    .font(.system(.caption, design: .monospaced)).tracking(1.2)
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                Text("From +C to C♯")
                    .font(.system(.title3, design: .serif)).italic()
                    .foregroundStyle(InstrumentPalette.displayInk)
            }
            Spacer()
            Button {
                playback.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
            }.buttonStyle(.glass).accessibilityLabel("Close demo")
                .accessibilityIdentifier("demo.close")
        }
    }

    private var chapters: some View {
        HStack(spacing: 8) {
            ForEach(CDemoChapter.allCases) { chapter in
                Button { choose(chapter.firstStep) } label: {
                    VStack(spacing: 8) {
                        Text(chapter.title).font(.system(.subheadline, design: .rounded, weight: .medium))
                        HStack(spacing: 4) {
                            ForEach(CDemoStep.allCases.filter { $0.chapter == chapter }) { step in
                                Capsule().fill(step.index < playback.step.index ? accent.opacity(0.55) : step == playback.step ? accent : Color.white.opacity(0.10))
                                    .frame(height: 3)
                            }
                        }.accessibilityHidden(true)
                    }.foregroundStyle(chapter == playback.step.chapter ? accent : InstrumentPalette.secondaryInk)
                        .padding(12).frame(maxWidth: .infinity, minHeight: 52)
                        .background(InstrumentPalette.content, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(chapter == playback.step.chapter ? accent.opacity(0.45) : .white.opacity(0.08)))
                }.buttonStyle(.plain).accessibilityLabel("\(chapter.title) chapter")
                    .accessibilityAddTraits(chapter == playback.step.chapter ? .isSelected : [])
                    .accessibilityIdentifier("demo.chapter.\(chapter.rawValue)")
            }
        }
    }

    @ViewBuilder private var panel: some View {
        switch playback.step.chapter {
        case .integrals:
            CalculusDemoPanel(step: playback.step, progress: playback.progress, isPlaying: playback.isPlaying, onInteraction: pause)
        case .code:
            CodeDemoPanel(step: playback.step, progress: playback.progress, isPlaying: playback.isPlaying, onInteraction: pause)
        case .sound:
            SoundDemoPanel(step: playback.step, progress: playback.progress, isPlaying: playback.isPlaying, onInteraction: pause)
        }
    }

    private var transport: some View {
        VStack(spacing: 8) {
            HStack {
                Text(playback.hasFinished ? "DEMO COMPLETE" : playback.isPlaying ? "PLAYING" : "PAUSED · YOUR TURN")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(accent)
                Spacer()
                Text("\(Int(playback.progress * 100))%")
                    .font(.system(.caption2, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(InstrumentPalette.secondaryInk)
            }
            Slider(value: Binding(get: { playback.progress }, set: { playback.seek(to: $0) }), in: 0...1, onEditingChanged: { editing in
                if editing { playback.pause(); replayGeneration += 1 }
            }).tint(accent).accessibilityLabel("Scene progress")
                .instrumentControlOwnsTouches(identifier: "demo.progress")
                .accessibilityIdentifier("demo.progress")
            HStack(spacing: 10) {
                transportButton("Previous scene", symbol: "backward.end", id: "demo.previous", disabled: playback.step == .constant) {
                    choose(CDemoStep.allCases[max(0, playback.step.index - 1)])
                }
                Button {
                    if playback.isPlaying { playback.pause() }
                    else {
                        if playback.hasFinished { replayGeneration += 1 }
                        playback.play()
                    }
                    CFeedback.selection()
                } label: {
                    Label(playback.isPlaying ? "Pause" : playback.hasFinished ? "Play again" : "Play", systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }.buttonStyle(.glassProminent).tint(accent)
                    .instrumentControlOwnsTouches(identifier: "demo.play")
                    .accessibilityIdentifier("demo.play")
                transportButton("Replay scene", symbol: "arrow.counterclockwise", id: "demo.replay") {
                    replayGeneration += 1
                    playback.replay()
                    CFeedback.selection()
                }
                transportButton("Next scene", symbol: "forward.end", id: "demo.next", disabled: playback.step == .scale) {
                    choose(CDemoStep.allCases[min(8, playback.step.index + 1)])
                }
            }
        }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
            .frame(maxWidth: 700).frame(maxWidth: .infinity)
            .background(InstrumentPalette.canvas.opacity(0.98))
    }

    private func transportButton(_ label: String, symbol: String, id: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(minWidth: 44, minHeight: 48)
        }.buttonStyle(.glass).accessibilityLabel(label)
            .disabled(disabled).instrumentControlOwnsTouches(identifier: id)
            .accessibilityIdentifier(id)
    }
    private func pause() { playback.pause() }
    private func choose(_ step: CDemoStep) {
        playback.select(step)
        replayGeneration += 1
        CFeedback.selection()
    }
}
