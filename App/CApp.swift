import SwiftUI

enum CTab: String, CaseIterable {
    case atlas, calculus, language, music, notes
}

@main struct CApp: App {
    var body: some Scene {
        WindowGroup {
            CRootView().preferredColorScheme(.dark)
        }
    }
}

struct CRootView: View {
    @State private var selection: CTab = {
        let value = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--lab=") }
        return value.flatMap { CTab(rawValue: String($0.dropFirst(6))) } ?? .atlas
    }()
    @State private var notebook: NotebookStore = {
        guard ProcessInfo.processInfo.environment["C_UI_TESTING"] == "1",
              let defaults = UserDefaults(suiteName: "com.utkarsh.c.ui-testing") else { return NotebookStore() }
        if ProcessInfo.processInfo.arguments.contains("--reset-notebook") {
            defaults.removePersistentDomain(forName: "com.utkarsh.c.ui-testing")
        }
        return NotebookStore(defaults: defaults)
    }()
    var body: some View {
        TabView(selection: $selection) {
            Tab("Explore", systemImage: "circle.hexagongrid", value: CTab.atlas) {
                NavigationStack { CAtlasView(selection: $selection) }
            }
            Tab("Integrals", systemImage: "function", value: CTab.calculus) {
                NavigationStack { CalculusLabView() }
            }
            Tab("Code", systemImage: "chevron.left.forwardslash.chevron.right", value: CTab.language) {
                NavigationStack { LanguageLabView() }
            }
            Tab("Sound", systemImage: "pianokeys", value: CTab.music) {
                NavigationStack { MusicLabView() }
            }
            Tab("Notes", systemImage: "note.text", value: CTab.notes) {
                NavigationStack { NotesView(store: notebook) }
            }
        }.tint(InstrumentPalette.actionCyan)
            .onChange(of: selection) { _, _ in CFeedback.selection() }
    }
}
