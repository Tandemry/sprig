import AppKit
import SprigCore
import SwiftUI
import UniformTypeIdentifiers

enum Destination: String, CaseIterable, Identifiable {
  case home = "Home"
  case boards = "Boards"
  case library = "Library"
  case search = "Search"
  var id: Self { self }
}
enum WorkspaceTool: String, CaseIterable {
  case select = "Select"
  case pan = "Pan"
  case connect = "Connect"
}
enum CreateKind: String, Identifiable {
  case folder = "New folder"
  case board = "New board"
  case rename = "Rename board"
  var id: Self { self }
}
@MainActor @Observable final class AppStore {
  private var history: WorkspaceHistory
  private let file: WorkspaceFile
  private var savingBlocked = false
  private var writer: WorkspaceWriter?
  private var saveRevision = 0
  var isSaving = false
  var operationError: String?
  var searchFocusRequest = 0
  var destination: Destination = .home
  var boardID = "conformity"
  var folderID: String?
  var collapsedFolders: Set<String> = []
  var showingTrash = false
  var editingID: String?
  var editorSession = UUID().uuidString
  var sourceMode = false
  var dragPositions: [String: CGPoint] = [:]
  var selectedConnectionID: String?
  var selection: String?
  var tool: WorkspaceTool = .select
  var listMode = false
  var zoom: CGFloat = 1
  var pan = CGSize.zero
  var canvasSize = CGSize(width: 1470, height: 830)
  // Preserve existing world coordinates without making the header a canvas boundary.
  var boardCamera: BoardCamera {
    BoardCamera(zoom: zoom, pan: pan, origin: CGPoint(x: 0, y: 213))
  }
  var query = ""
  var form: CreateKind?
  var error: String?
  var message: String?
  var workspace: Workspace { history.current }
  var canUndo: Bool { history.canUndo }
  var canRedo: Bool { history.canRedo }
  var board: Board? { workspace.boards.first { $0.id == boardID } ?? workspace.boards.first }
  var notes: [Note] { board.map { workspace.activeNotes(on: $0.id) } ?? [] }
  var editingNote: Note? { workspace.notes.first { $0.id == editingID && $0.deletedAt == nil } }
  var activeNotes: [Note] { workspace.notes.filter { $0.deletedAt == nil } }
  var recentNotes: [Note] { Array(activeNotes.sorted { $0.updatedAt > $1.updatedAt }.prefix(5)) }
  var saveStatus: String { error != nil ? "Not saved" : isSaving ? "Saving…" : "Saved locally" }
  var libraryBoards: [Board] {
    let ids = workspace.folderIDs(includingDescendantsOf: folderID)
    return workspace.boards.filter { ids.contains($0.folderId) }
  }
  var libraryNotes: [Note] {
    let ids = Set(libraryBoards.map(\.id))
    return activeNotes.filter { ids.contains($0.boardId) }
  }
  init(preview: Bool = false, url: URL? = nil) {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!.appending(path: "Tandemry/Sprig")
    file = WorkspaceFile(url: url ?? root.appending(path: "workspace.json"))
    if preview {
      history = WorkspaceHistory(.demo())
      savingBlocked = true
      return
    }
    do {
      history = WorkspaceHistory(try file.load() ?? .demo())
      writer = try WorkspaceWriter(file: file)
    } catch {
      history = WorkspaceHistory(.demo())
      savingBlocked = true
      self.error =
        "Your saved workspace could not be read. The original file is preserved. Export recovery data before continuing."
    }
  }
  func change(group: String? = nil, _ update: (inout Workspace) -> Void) {
    var next = workspace
    update(&next)
    guard next != workspace else { return }
    do { try next.validate() } catch {
      operationError = error.localizedDescription
      return
    }
    history.apply(group: group) { $0 = next }
    reconcile()
    save()
  }
  private func save() {
    guard !savingBlocked, let writer else { return }
    saveRevision += 1
    let revision = saveRevision
    isSaving = true
    writer.enqueue(workspace) { [weak self] result in
      Task { @MainActor in
        guard let self, self.saveRevision == revision else { return }
        self.isSaving = false
        switch result {
        case .success: self.error = nil
        case .failure(let error): self.error = error.localizedDescription
        }
      }
    }
  }
  @discardableResult func flush() -> Bool {
    guard !savingBlocked, let writer else { return error == nil }
    saveRevision += 1
    isSaving = false
    do {
      try writer.flush(workspace)
      error = nil
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  private func reconcile() {
    if !workspace.boards.contains(where: { $0.id == boardID }) {
      boardID = workspace.boards.first?.id ?? ""
    }
    if let id = editingID, !activeNotes.contains(where: { $0.id == id }) { closeEditor() }
    if let id = selection, !notes.contains(where: { $0.id == id }) { selection = nil }
    if let id = selectedConnectionID,
      !workspace.connections.contains(where: { c in
        c.id == id && notes.contains(where: { $0.id == c.from })
          && notes.contains(where: { $0.id == c.to })
      })
    {
      selectedConnectionID = nil
    }
    if let id = folderID, !workspace.folders.contains(where: { $0.id == id }) { folderID = nil }
  }
  func undo() {
    history.undo()
    reconcile()
    save()
  }
  func redo() {
    history.redo()
    reconcile()
    save()
  }
  func closeEditor() {
    editingID = nil
    sourceMode = false
  }
  func navigate(_ target: Destination) {
    closeEditor()
    dragPositions = [:]
    selectedConnectionID = nil
    selection = nil
    destination = target
    if target == .search { searchFocusRequest += 1 }
  }
  func openBoard(_ id: String) {
    guard workspace.boards.contains(where: { $0.id == id }) else { return }
    closeEditor()
    boardID = id
    dragPositions = [:]
    selectedConnectionID = nil
    destination = .boards
    selection = nil
    pan = .zero
    zoom = 1
    tool = .select
    showingTrash = false
  }
  func openNote(_ id: String) {
    selectedConnectionID = nil
    guard let note = activeNotes.first(where: { $0.id == id }) else { return }
    if boardID != note.boardId {
      boardID = note.boardId
      pan = .zero
      zoom = 1
    }
    tool = .select
    editorSession = UUID().uuidString
    editingID = id
    sourceMode = false
    selection = id
  }
  func updateNote(_ id: String, group: String? = nil, _ update: (inout Note) -> Void) {
    change(group: group) { workspace in
      guard let i = workspace.notes.firstIndex(where: { $0.id == id }) else { return }
      let before = workspace.notes[i]
      update(&workspace.notes[i])
      if before.title != workspace.notes[i].title || before.markdown != workspace.notes[i].markdown
      {
        workspace.notes[i].updatedAt = Date().timeIntervalSince1970 * 1000
      }
    }
  }
  func editNote(_ update: (inout Note) -> Void) {
    guard let id = editingID else { return }
    updateNote(id, group: "editor-\(editorSession)", update)
  }
  func addNote(_ colour: NoteColour, x: Double? = nil, y: Double? = nil) {
    guard let board else { return }
    let point = boardCamera.worldPoint(
      CGPoint(x: canvasSize.width * 0.45, y: canvasSize.height * 0.4),
      viewportWidth: canvasSize.width)
    let n = Note(
      boardId: board.id, colour: colour,
      x: x ?? point.x - 128 + Double(notes.count % 4) * 18,
      y: y ?? point.y - 80 + Double(notes.count % 4) * 18)
    change { $0.notes.append(n) }
    openNote(n.id)
  }
  func duplicate(_ note: Note) {
    var n = note
    n.id = UUID().uuidString
    n.title += " copy"
    n.x += 35
    n.y += 35
    n.updatedAt = Date().timeIntervalSince1970 * 1000
    change { $0.notes.append(n) }
    openBoard(n.boardId)
    selection = n.id
  }
  func trash(_ id: String) {
    updateNote(id) { $0.deletedAt = Date().timeIntervalSince1970 * 1000 }
    editingID = nil
    selection = nil
  }
  func restore(_ id: String) { updateNote(id) { $0.deletedAt = nil } }
  func selectConnection(_ id: String) {
    guard tool == .connect, let c = workspace.connections.first(where: { $0.id == id }),
      notes.contains(where: { $0.id == c.from })
    else { return }
    selection = nil
    selectedConnectionID = id
  }
  func updateConnection(_ id: String, group: String? = nil, _ update: (inout Connection) -> Void) {
    change(group: group) { workspace in
      guard let i = workspace.connections.firstIndex(where: { $0.id == id }) else { return }
      update(&workspace.connections[i])
    }
  }
  func adjustConnectionTightness(_ id: String, by delta: Double, group: String) {
    guard delta.isFinite else { return }
    updateConnection(id, group: group) {
      guard !$0.rigid else { return }
      $0.tightness = min(1, max(0, $0.tightness + delta))
    }
  }
  func deleteConnection(_ id: String) {
    change { $0.connections.removeAll { $0.id == id } }
    selectedConnectionID = nil
  }
  func connect(_ id: String) {
    selectedConnectionID = nil
    guard notes.contains(where: { $0.id == id }) else { return }
    if let start = selection, !notes.contains(where: { $0.id == start }) { selection = nil }
    if let start = selection, start != id {
      let exists = workspace.connections.contains {
        ($0.from == start && $0.to == id) || ($0.from == id && $0.to == start)
      }
      if !exists {
        change { $0.connections.append(Connection(from: start, to: id)) }
        message = "Notes connected."
      } else {
        message = "These notes are already connected."
      }
      selection = nil
    } else {
      selection = id
    }
  }
  func create(_ kind: CreateKind, name: String, parent: String?) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard parent == nil || workspace.folders.contains(where: { $0.id == parent }) else {
      operationError = "Choose an existing folder."
      return
    }
    switch kind {
    case .folder:
      let f = Folder(name: trimmed, parentId: parent)
      change { $0.folders.append(f) }
      folderID = f.id
      destination = .library
    case .board:
      guard let parent else { return }
      let b = Board(title: trimmed, folderId: parent)
      change { $0.boards.append(b) }
      openBoard(b.id)
    case .rename:
      guard let board else { return }
      change { w in
        if let i = w.boards.firstIndex(where: { $0.id == board.id }) { w.boards[i].title = trimmed }
      }
    }
    form = nil
  }
  func togglePin() {
    guard let board else { return }
    change { w in
      if let i = w.boards.firstIndex(where: { $0.id == board.id }) { w.boards[i].pinned.toggle() }
    }
  }
  func exportNote(_ note: Note) {
    export(
      Data("# \(note.title)\n\n\(note.markdown)".utf8), name: note.title + ".md", type: .plainText)
  }
  func exportBoard() {
    guard let board else { return }
    export(Data(workspace.markdown(for: board).utf8), name: board.title + ".md", type: .plainText)
  }
  func exportBackup() {
    do { export(try workspace.encoded(), name: "sprig-backup.json", type: .json) } catch {
      self.operationError = error.localizedDescription
    }
  }
  func exportRecovery() {
    do { export(try Data(contentsOf: file.url), name: "sprig-recovery.json", type: .json) } catch {
      self.operationError = "Recovery export failed: \(error.localizedDescription)"
    }
  }
  private func export(_ data: Data, name: String, type: UTType) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = name.replacingOccurrences(of: "/", with: "-")
    panel.allowedContentTypes = [type]
    if panel.runModal() == .OK, let url = panel.url {
      do { try data.write(to: url, options: .atomic) } catch {
        self.operationError = error.localizedDescription
      }
    }
  }
  func importBackup() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let incoming = try Workspace.decode(Data(contentsOf: url))
      var next = workspace
      try next.importCopy(incoming)
      change { $0 = next }
      message = "Backup imported into new folders. Existing notes are kept."
    } catch { self.operationError = "Could not import this backup. \(error.localizedDescription)" }
  }
}
