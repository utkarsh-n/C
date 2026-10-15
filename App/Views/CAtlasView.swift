import SwiftUI
import CCore

struct CAtlasView: View {
    @Binding var selection: CTab
    @State private var showDemo = ProcessInfo.processInfo.arguments.contains("--demo")
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("C").font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        Text("ONE LETTER. MANY WORLDS.")
                            .font(.system(.caption, design: .monospaced)).tracking(1.7)
                            .foregroundStyle(InstrumentPalette.secondaryInk)
                    }
                    Spacer()
                    Text("FIELD GUIDE\n01 / 03").font(.system(.caption2, design: .monospaced))
                        .multilineTextAlignment(.trailing).foregroundStyle(InstrumentPalette.secondaryInk)
                        .padding(.top, 8).accessibilityHidden(true)
                }
                CIdentityInstrument()
                Text("A constant. A language. A note.")
                    .font(.system(.title2, design: .serif)).italic()
                    .foregroundStyle(InstrumentPalette.displayInk)
                Text("Move a curve. Follow a pointer. Hear a semitone. Explore what C means by changing it.")
                    .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                Button { showDemo = true } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "play.circle.fill").font(.largeTitle)
                            .foregroundStyle(InstrumentPalette.actionCyan)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Play the C demo").font(.system(.headline, design: .rounded))
                            Text("+C → code → C♯ · 9 scenes you can control")
                                .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption)
                    }.padding(16).frame(maxWidth: .infinity, minHeight: 64)
                }.buttonStyle(.glass).accessibilityIdentifier("atlas-demo")
                CSectionLabel(number: "01—03", title: "Choose an instrument")
                VStack(spacing: 12) {
                    route("∫", index: "01", title: "The constant of possibility",
                          detail: "Integrals, + C, and area written in C", tag: "+ C", accent: InstrumentPalette.actionCyan, tab: .calculus)
                    route("{ }", index: "02", title: "The language of memory",
                          detail: "C, pointers, and the world of C#", tag: "C / C#", accent: InstrumentPalette.actionAmber, tab: .language)
                    route("♯", index: "03", title: "The shape of a note",
                          detail: "Play C. Raise it to C♯. Find the ratio.", tag: "C → C♯", accent: InstrumentPalette.spectrum, tab: .music)
                }
                LabNote(title: "Connections, with care", text: "These Cs share a symbol, not a hidden physical law. The mathematics is calculus, the programs model language semantics, and the sound follows twelve-tone equal temperament. Each instrument makes its assumptions visible.")
                Button { selection = .notes } label: {
                    HStack {
                        Label("Keep a field notebook", systemImage: "note.text")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }.font(.subheadline).padding(16).frame(minHeight: 52)
                }.buttonStyle(.glass).accessibilityIdentifier("atlas-notes")
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background { InstrumentDesignBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityIdentifier("atlas-screen")
            .fullScreenCover(isPresented: $showDemo) {
                CDemoView { chapter in
                    selection = switch chapter {
                    case .integrals: .calculus
                    case .code: .language
                    case .sound: .music
                    }
                }
            }
    }

    private func route(_ glyph: String, index: String, title: String, detail: String,
                       tag: String, accent: Color, tab: CTab) -> some View {
        Button {
            selection = tab
        } label: {
            HStack(alignment: .center, spacing: 16) {
                Text(glyph).font(.system(size: 30, weight: .light, design: .serif))
                    .foregroundStyle(accent).frame(width: 48, height: 62)
                    .background(.black.opacity(0.25), in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(index)  /  \(tag)").font(.system(.caption2, design: .monospaced))
                        .tracking(1).foregroundStyle(accent)
                    Text(title).font(.system(.headline, design: .rounded))
                        .foregroundStyle(InstrumentPalette.displayInk)
                    Text(detail).font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(accent)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(InstrumentPalette.content, in: .rect(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10)))
                .contentShape(.rect(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityIdentifier("atlas-\(tab.rawValue)")
    }
}

private struct CIdentityInstrument: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, 350.0)
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.18),
                                                       Color(red: 0.035, green: 0.05, blue: 0.065)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.7), radius: 16, y: 12)
                Circle().stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.02), .black, .white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                Circle().inset(by: d * 0.045).fill(InstrumentPalette.canvas)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for i in 0..<72 {
                        let a = Double(i) * .pi / 36 - .pi / 2
                        let r0 = d * (i % 6 == 0 ? 0.415 : 0.435)
                        let r1 = d * 0.455
                        var p = Path()
                        p.move(to: CGPoint(x: center.x + cos(a) * r0, y: center.y + sin(a) * r0))
                        p.addLine(to: CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1))
                        let color = i < 24 ? InstrumentPalette.actionCyan : i < 48 ? InstrumentPalette.actionAmber : InstrumentPalette.spectrum
                        context.stroke(p, with: .color(color.opacity(i % 6 == 0 ? 0.85 : 0.25)), lineWidth: i % 6 == 0 ? 1.4 : 0.7)
                    }
                    var wave = Path()
                    for x in 0...140 {
                        let px = d * 0.23 + Double(x) / 140 * d * 0.54
                        let py = d * 0.70 + sin(Double(x) / 140 * .pi * 4) * d * 0.025
                        if x == 0 { wave.move(to: CGPoint(x: px, y: py)) }
                        else { wave.addLine(to: CGPoint(x: px, y: py)) }
                    }
                    context.stroke(wave, with: .color(InstrumentPalette.spectrum.opacity(0.7)), lineWidth: 1.2)
                }
                if !reduceTransparency {
                    Circle().fill(.clear).frame(width: d * 0.72, height: d * 0.72)
                        .glassEffect(.clear, in: .circle).opacity(0.48)
                }
                VStack(spacing: 0) {
                    Text("C").font(.system(size: d * 0.36, weight: .light, design: .rounded))
                        .foregroundStyle(InstrumentPalette.displayInk)
                    Text("CALCULUS · CODE · SOUND")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.2).foregroundStyle(InstrumentPalette.secondaryInk)
                }.offset(y: -d * 0.025)
            }.frame(width: d, height: d).frame(maxWidth: .infinity)
        }.frame(height: 350)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("C, calculus, code, and sound")
    }
}
