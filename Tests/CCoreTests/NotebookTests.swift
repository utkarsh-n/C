import Foundation
import Testing
@testable import CCore

@Test func savedNotesPreserveUnicodeAndIdentity() throws {
    let note = PersonalNote(title: "C♯ → C", body: "∫ 2x dx = x² + C\n*p = 9;", topic: .connections)
    let data = try JSONEncoder().encode([note])
    let result = try JSONDecoder().decode([PersonalNote].self, from: data)
    #expect(result == [note])
    #expect(result[0].shareText.contains("∫ 2x"))
}
