import Foundation
import Observation
import CCore

@MainActor @Observable final class NotebookStore {
    private(set) var notes: [PersonalNote] = []
    private(set) var storageWarning: String?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "c.notebook.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do { notes = try JSONDecoder().decode([PersonalNote].self, from: data).sorted { $0.updated > $1.updated } }
            catch { storageWarning = "The saved notebook could not be read. Its original data has been kept." }
        }
    }

    func save(_ note: PersonalNote) {
        var next = notes
        if let i = next.firstIndex(where: { $0.id == note.id }) { next[i] = note }
        else { next.insert(note, at: 0) }
        persist(next)
    }

    func delete(_ id: UUID) { persist(notes.filter { $0.id != id }) }

    private func persist(_ next: [PersonalNote]) {
        guard storageWarning == nil else { return }
        do {
            let sorted = next.sorted { $0.updated > $1.updated }
            defaults.set(try JSONEncoder().encode(sorted), forKey: key)
            notes = sorted
        } catch { storageWarning = "This note could not be saved. Your previous notebook is still available." }
    }
}
