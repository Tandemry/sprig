import Foundation
import SprigCore
import Testing

@testable import SprigApp

@MainActor private func fixture() throws -> (AppStore, URL) {
  let root = FileManager.default.temporaryDirectory.appending(path: "sprig-store-\(UUID())")
  let file = WorkspaceFile(url: root.appending(path: "workspace.json"))
  try file.save(.demo())
  return (AppStore(url: file.url), root)
}
@Test @MainActor func openingRecentNoteSelectsItsOwningBoard() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openBoard("memory")
  s.destination = .home
  s.openNote("note-0")
  #expect(s.boardID == "conformity")
}
@Test @MainActor func switchingBoardsDismissesPreviousEditor() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openNote("note-0")
  s.openBoard("memory")
  #expect(s.editingID == nil)
}
@Test @MainActor func duplicateFromHomeIsVisibleOnItsBoard() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openBoard("memory")
  s.destination = .home
  s.duplicate(s.workspace.notes[0])
  #expect(s.destination == .boards)
  #expect(s.boardID == "conformity")
  #expect(s.notes.contains { $0.id == s.selection })
}
@Test @MainActor func newNotesStartInLiveEditingMode() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.addNote(.sage)
  #expect(!s.sourceMode)
}
@Test @MainActor func staleCrossBoardSelectionCannotCorruptConnections() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openBoard("memory")
  s.addNote(.sage)
  let memoryID = s.editingID!
  s.openBoard("conformity")
  s.selection = memoryID
  s.connect("note-0")
  #expect(s.workspace.connections.isEmpty)
  try s.workspace.validate()
}
@Test @MainActor func colourAndPositionChangesDoNotReorderRecentNotes() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  let before = s.workspace.notes[5].updatedAt
  s.updateNote("note-5") {
    $0.x = 300
    $0.colour = .rose
  }
  #expect(s.workspace.notes[5].updatedAt == before)
}

@Test @MainActor func navigationClosesEditorAndClearsSelection() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openNote("note-0")
  s.navigate(.search)
  #expect(s.editingID == nil)
  #expect(s.selection == nil)
  #expect(s.searchFocusRequest == 1)
}
@Test @MainActor func undoCreationClosesRemovedEditor() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.addNote(.rose)
  s.undo()
  #expect(s.editingID == nil)
  #expect(s.selection == nil)
  #expect(s.workspace.notes.count == 6)
}
@Test @MainActor func parentLibraryShowsNestedNotes() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.folderID = "psych"
  #expect(s.libraryBoards.count == 2)
  #expect(s.libraryNotes.count == 6)
}
@Test @MainActor func invalidMutationsDoNotReplaceWorkingData() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  let original = s.workspace
  s.change { $0.notes[0].boardId = "missing" }
  #expect(s.workspace == original)
  #expect(s.operationError != nil)
  #expect(s.error == nil)
}
@Test @MainActor func sourceEditsFlushWithoutLosingLatestText() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openNote("note-0")
  for i in 0..<25 { s.editNote { $0.markdown = "Revision \(i)" } }
  #expect(s.flush())
  let disk = try WorkspaceFile(url: root.appending(path: "workspace.json")).load()
  #expect(disk?.notes[0].markdown == "Revision 24")
}

@Test @MainActor func notesCanBePlacedAboveOriginalCanvasOrigin() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.addNote(.butter, x: -50, y: -120)
  let id = s.editingID!
  let note = s.workspace.notes.first { $0.id == id }!
  #expect(note.x == -50)
  #expect(note.y == -120)
  #expect(s.flush())
  let reopened = try WorkspaceFile(url: root.appending(path: "workspace.json")).load()
  #expect(reopened?.notes.first { $0.id == id }?.y == -120)
}

@Test @MainActor func connectingUsesTwoDistinctNotesWithoutOpeningEditor() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openBoard("conformity")
  s.tool = .connect
  s.connect("note-0")
  #expect(s.selection == "note-0")
  #expect(s.editingID == nil)
  s.connect("note-1")
  #expect(s.workspace.connections.count == 1)
  #expect(s.selection == nil)
  #expect(s.editingID == nil)
  s.connect("note-1")
  s.connect("note-0")
  #expect(s.workspace.connections.count == 1)
  s.undo()
  #expect(s.workspace.connections.isEmpty)
  s.redo()
  #expect(s.workspace.connections.count == 1)
}

@Test @MainActor func delayedEditorChangesStayAttachedToTheirOriginalNote() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openNote("note-0")
  let binding = NoteEditor.textBinding(store: s, noteID: "note-0", session: s.editorSession)
  s.openNote("note-1")
  let nextNoteText = s.editingNote!.markdown
  binding.wrappedValue = "Final edit from previous note"
  #expect(
    s.workspace.notes.first { $0.id == "note-0" }?.markdown == "Final edit from previous note")
  #expect(s.editingNote?.markdown == nextNoteText)
}

@Test @MainActor func connectionSelectionStyleDeleteAndUndo() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openBoard("conformity")
  s.tool = .connect
  s.connect("note-0")
  s.connect("note-1")
  let id = s.workspace.connections[0].id
  s.selectConnection(id)
  #expect(s.selectedConnectionID == id && s.selection == nil)
  s.updateConnection(id) {
    $0.colour = .rose
    $0.rigid = true
  }
  #expect(s.flush())
  let saved = try WorkspaceFile(url: root.appending(path: "workspace.json")).load()!
  #expect(saved.connections[0].colour == .rose && saved.connections[0].rigid)
  s.deleteConnection(id)
  #expect(s.selectedConnectionID == nil && s.workspace.connections.isEmpty)
  s.undo()
  #expect(s.workspace.connections[0].colour == .rose && s.workspace.connections[0].rigid)
  s.selectConnection(id)
  s.openBoard("memory")
  #expect(s.selectedConnectionID == nil)
}

@Test @MainActor func heldTightnessAdjustmentIsClampedSavedAndGroupedForUndo() throws {
  let (s, root) = try fixture()
  defer {
    s.flush()
    try? FileManager.default.removeItem(at: root)
  }
  s.openBoard("conformity")
  s.tool = .connect
  s.connect("note-0")
  s.connect("note-1")
  let id = s.workspace.connections[0].id
  for _ in 0..<40 { s.adjustConnectionTightness(id, by: 0.02, group: "one-hold") }
  #expect(s.workspace.connections[0].tightness == 1)
  s.undo()
  #expect(s.workspace.connections[0].tightness == 0.5)
  s.redo()
  #expect(s.workspace.connections[0].tightness == 1)
  for _ in 0..<60 { s.adjustConnectionTightness(id, by: -0.02, group: "second-hold") }
  #expect(s.workspace.connections[0].tightness == 0)
  #expect(s.flush())
  let saved = try WorkspaceFile(url: root.appending(path: "workspace.json")).load()!
  #expect(saved.connections[0].tightness == 0)
}
