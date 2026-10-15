import SwiftUI
import CCore

struct NotesView: View {
    let store: NotebookStore
    @State private var personal = false
    @State private var query = ""
    @State private var topic: NoteTopic?
    @State private var draft: PersonalNote?
    @State private var pendingDelete: PersonalNote?

    private var reference: [FieldNote] {
        CFieldGuide.notes.filter { (topic == nil || $0.topic == topic) && $0.matches(query) }
    }
    private var personalNotes: [PersonalNote] {
        store.notes.filter {
            (topic == nil || $0.topic == topic) &&
            (query.isEmpty || "\($0.title) \($0.body)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                LabHeader(eyebrow: "Field notebook", title: "Keep the connection.",
                          subtitle: "A pocket reference, and a place for what you discover.")
                Picker("Notebook collection", selection: $personal) {
                    Text("Reference").tag(false)
                    Text("My notebook").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("notes-collection")
                HStack {
                    Menu {
                        Button("All topics") { topic = nil }
                        ForEach(NoteTopic.allCases) { item in
                            Button(item.rawValue) { topic = item }
                        }
                    } label: {
                        Label(topic?.rawValue ?? "All topics", systemImage: "line.3.horizontal.decrease")
                            .font(.subheadline).frame(minHeight: 44)
                    }.buttonStyle(.glass)
                    Spacer()
                    Text("\(personal ? personalNotes.count : reference.count) NOTES")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                }
                if let warning = store.storageWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.subheadline).foregroundStyle(InstrumentPalette.actionAmber)
                }
                if personal {
                    LabAction(title: "Write a note", symbol: "square.and.pencil") {
                        draft = PersonalNote(title: "", body: "", topic: topic ?? .connections)
                    }.accessibilityIdentifier("notes-new").disabled(store.storageWarning != nil)
                    if personalNotes.isEmpty {
                        ContentUnavailableView(query.isEmpty ? "Your first observation" : "No matching notes",
                                               systemImage: "note.text", description: Text(query.isEmpty ? "Try a lab, then record what changed and why." : "Try another search or topic."))
                    }
                    ForEach(personalNotes) { note in personalCard(note) }
                } else {
                    if reference.isEmpty { ContentUnavailableView.search(text: query) }
                    ForEach(reference) { note in referenceCard(note) }
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background { InstrumentDesignBackground() }
            .navigationTitle("Notes").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "C, pointers, cents, constants…")
            .sheet(item: $draft) { note in NoteEditor(store: store, initial: note) }
            .confirmationDialog("Delete this note?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                if let note = pendingDelete {
                    Button("Delete \(note.title)", role: .destructive) { store.delete(note.id); pendingDelete = nil }
                }
            }
            .accessibilityIdentifier("notes-screen")
    }

    private func referenceCard(_ note: FieldNote) -> some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(note.topic.rawValue.uppercased()).font(.system(.caption2, design: .monospaced))
                    .tracking(1.5).foregroundStyle(accent(note.topic))
                Text(note.title).font(.system(.headline, design: .rounded))
                    .foregroundStyle(InstrumentPalette.displayInk)
                Text(note.equation).font(.system(.callout, design: .monospaced))
                    .foregroundStyle(accent(note.topic)).textSelection(.enabled)
                Text(note.body).font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Link(destination: note.sourceURL) {
                        Label(note.sourceTitle, systemImage: "arrow.up.right")
                            .font(.caption).frame(minHeight: 44)
                    }.tint(InstrumentPalette.secondaryInk)
                    Spacer()
                    ShareLink(item: note.shareText) {
                        Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                    }.accessibilityLabel("Share \(note.title)")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func personalCard(_ note: PersonalNote) -> some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(note.topic.rawValue.uppercased()).foregroundStyle(accent(note.topic))
                    Spacer()
                    Text(note.updated, style: .date).foregroundStyle(InstrumentPalette.secondaryInk)
                }.font(.system(.caption2, design: .monospaced))
                Text(note.title).font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                Text(note.body).font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .textSelection(.enabled)
                HStack {
                    Button("Edit", systemImage: "pencil") { draft = note }
                        .frame(minHeight: 44).accessibilityLabel("Edit \(note.title)")
                    Spacer()
                    ShareLink(item: note.shareText) {
                        Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                    }.accessibilityLabel("Share \(note.title)")
                    Button(role: .destructive) { pendingDelete = note } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }.accessibilityLabel("Delete \(note.title)")
                }.font(.subheadline).tint(InstrumentPalette.actionCyan)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func accent(_ topic: NoteTopic) -> Color {
        switch topic {
        case .calculus, .connections: InstrumentPalette.actionCyan
        case .c, .cSharp: InstrumentPalette.actionAmber
        case .music: InstrumentPalette.spectrum
        }
    }
}

private struct NoteEditor: View {
    let store: NotebookStore
    let initial: PersonalNote
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var text: String
    @State private var topic: NoteTopic
    init(store: NotebookStore, initial: PersonalNote) {
        self.store = store
        self.initial = initial
        _title = State(initialValue: initial.title)
        _text = State(initialValue: initial.body)
        _topic = State(initialValue: initial.topic)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title).accessibilityIdentifier("note-title")
                Picker("Topic", selection: $topic) {
                    ForEach(NoteTopic.allCases) { Text($0.rawValue).tag($0) }
                }
                Section("What changed? What did you learn?") {
                    TextEditor(text: $text).frame(minHeight: 220)
                        .accessibilityLabel("Note body").accessibilityIdentifier("note-body")
                }
                Section {
                    Text("Saved on this device. Use Share on a note to keep a copy elsewhere.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle(initial.title.isEmpty ? "New note" : "Edit note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.save(PersonalNote(id: initial.id, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                                    body: text.trimmingCharacters(in: .whitespacesAndNewlines), topic: topic))
                            if store.storageWarning == nil { CFeedback.event(); dismiss() }
                        }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("note-save")
                    }
                }
        }.tint(InstrumentPalette.actionCyan).preferredColorScheme(.dark)
    }
}
