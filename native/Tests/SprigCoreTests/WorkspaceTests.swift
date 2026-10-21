import Foundation
import Testing

@testable import SprigCore

@Test func demoMatchesSharedBackupFormat() throws {
  let w = Workspace.demo()
  try w.validate()
  #expect(w.notes.count == 6)
  #expect(w.path(to: "social").map(\.name) == ["A-levels", "Psychology", "Social psychology"])
  #expect(try Workspace.decode(w.encoded()) == w)
}
@Test func rejectsCyclicAndOrphanData() throws {
  var cycle = Workspace.demo()
  cycle.folders[0].parentId = "social"
  #expect(throws: WorkspaceError.self) { try cycle.validate() }
  var orphan = Workspace.demo()
  orphan.notes[0].boardId = "missing"
  #expect(throws: WorkspaceError.self) { try orphan.validate() }
  var connection = Workspace.demo()
  connection.notes[0].boardId = "memory"
  connection.connections = [Connection(from: "note-0", to: "note-1")]
  #expect(throws: WorkspaceError.self) { try connection.validate() }
}
@Test func importedCopiesKeepExistingWorkAndReconnect() throws {
  var w = Workspace.demo()
  var backup = Workspace.demo()
  backup.connections = [Connection(from: "note-0", to: "note-1")]
  try w.importCopy(backup)
  try w.validate()
  #expect(w.notes.count == 12)
  #expect(w.boards.count == 8)
  #expect(Set(w.notes.map(\.id)).count == 12)
  #expect(w.connections.first?.from != "note-0")
  #expect(w.notes[0].id == "note-0")
}
@Test func sourceMarkdownIsPreservedInExportAndTrashExcluded() throws {
  var w = Workspace.demo()
  w.notes[0].markdown = "**Keep this**\n\n$x^2$"
  w.notes[1].deletedAt = 1
  let output = w.markdown(for: w.boards[0])
  #expect(output.contains("**Keep this**\n\n$x^2$"))
  #expect(!output.contains("## Asch (1951)"))
}
@Test func groupedEditingUndoAndRedo() {
  var h = WorkspaceHistory(.demo())
  h.apply(group: "edit") { $0.notes[0].title = "First" }
  h.apply(group: "edit") { $0.notes[0].title = "Second" }
  h.undo()
  #expect(h.current.notes[0].title == "Types of conformity")
  h.redo()
  #expect(h.current.notes[0].title == "Second")
  h.apply { $0.notes[0].x = 500 }
  #expect(!h.canRedo)
  h.undo()
  #expect(h.current.notes[0].x == 60)
}
@Test func atomicSaveReopensWithoutChangingSource() throws {
  let dir = FileManager.default.temporaryDirectory.appending(path: "sprig-test-\(UUID())")
  defer { try? FileManager.default.removeItem(at: dir) }
  let file = WorkspaceFile(url: dir.appending(path: "workspace.json"))
  var w = Workspace.demo()
  #expect(try file.load() == nil)
  w.notes[0].title = "Saved native note"
  w.notes[0].markdown = "# Exact source\n\n- [x] Keep me"
  try file.save(w)
  #expect(try file.load() == w)
}
@Test func corruptFileIsNotOverwrittenByReading() throws {
  let dir = FileManager.default.temporaryDirectory.appending(path: "sprig-corrupt-\(UUID())")
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: dir) }
  let url = dir.appending(path: "workspace.json")
  let original = Data("original unreadable data".utf8)
  try original.write(to: url)
  #expect(throws: (any Error).self) { try WorkspaceFile(url: url).load() }
  #expect(try Data(contentsOf: url) == original)
}

@Test func parentFolderIncludesNestedCourseMaterial() {
  let w = Workspace.demo()
  #expect(w.folderIDs(includingDescendantsOf: "psych") == ["psych", "social"])
  #expect(w.folderIDs(includingDescendantsOf: "alevels").count == 5)
}
@Test func zoomKeepsWorldPointUnderCursor() {
  var camera = BoardCamera(zoom: 0.8, pan: CGSize(width: 70, height: -50))
  let cursor = CGPoint(x: 400, y: 200)
  let before = camera.worldPoint(cursor, viewportWidth: 1100)
  camera.zoom(to: 1.7, anchor: cursor, viewportWidth: 1100)
  let after = camera.worldPoint(cursor, viewportWidth: 1100)
  #expect(abs(before.x - after.x) < 0.00001)
  #expect(abs(before.y - after.y) < 0.00001)
}
@Test func fitMakesDistantNotesReachable() {
  var w = Workspace.demo()
  w.notes[0].x = 10000
  w.notes[0].y = 8000
  let viewport = CGSize(width: 960, height: 487)
  var camera = BoardCamera()
  camera.fit(notes: w.notes, viewport: viewport)
  let scale = camera.scale(viewportWidth: viewport.width)
  #expect(camera.zoom > 0)
  for n in w.notes {
    #expect(n.x * scale + camera.pan.width >= 0)
    #expect(n.y * scale + camera.pan.height >= 0)
    #expect((n.x + 256) * scale + camera.pan.width <= viewport.width - 140)
    #expect((n.y + 256) * scale + camera.pan.height <= viewport.height - 45)
  }
}
@Test func formatterDoesNotInsertPlaceholderTextAtCaret() {
  let edit = MarkdownFormat.bold.apply(to: "hello", selection: NSRange(location: 5, length: 0))
  #expect(edit.text == "hello****")
  #expect(edit.selection == NSRange(location: 7, length: 0))
}
@Test func formattingMultilineListsAndHeadingsPreservesContent() {
  let text = "first\nsecond\n"
  let result = MarkdownFormat.numbered.apply(
    to: text, selection: NSRange(location: 0, length: (text as NSString).length))
  #expect(result.text == "1. first\n2. second\n")
  let heading = MarkdownFormat.heading.apply(
    to: "an idea", selection: NSRange(location: 3, length: 2))
  #expect(heading.text == "## an idea")
  let unicode = MarkdownFormat.bold.apply(to: "🌿 study", selection: NSRange(location: 0, length: 2))
  #expect(unicode.text == "**🌿** study")
}
@Test func writerRefusesToOverwriteExternalChanges() throws {
  let dir = FileManager.default.temporaryDirectory.appending(path: "sprig-writer-\(UUID())")
  defer { try? FileManager.default.removeItem(at: dir) }
  let file = WorkspaceFile(url: dir.appending(path: "workspace.json"))
  let original = Workspace.demo()
  try file.save(original)
  let a = try WorkspaceWriter(file: file)
  let b = try WorkspaceWriter(file: file)
  var edited = original
  edited.notes[0].title = "Newer work"
  try a.flush(edited)
  #expect(throws: WorkspaceError.self) { try b.flush(original) }
  #expect(try file.load() == edited)
}
@Test func queuedWritesFlushTheNewestRevision() throws {
  let dir = FileManager.default.temporaryDirectory.appending(path: "sprig-queue-\(UUID())")
  defer { try? FileManager.default.removeItem(at: dir) }
  let file = WorkspaceFile(url: dir.appending(path: "workspace.json"))
  var w = Workspace.demo()
  try file.save(w)
  let writer = try WorkspaceWriter(file: file)
  for i in 0..<50 {
    w.notes[0].title = "Edit \(i)"
    writer.enqueue(w) { _ in }
  }
  try writer.flush(w)
  #expect(try file.load()?.notes[0].title == "Edit 49")
}

@Test func canvasOriginAllowsUpperWorkspaceAndAnchoredZoom() {
  var camera = BoardCamera(origin: CGPoint(x: 0, y: 213))
  let cursor = CGPoint(x: 650, y: 120)
  let world = camera.worldPoint(cursor, viewportWidth: 1470)
  #expect(world.y == -93)
  camera.zoom(to: 0.7, anchor: cursor, viewportWidth: 1470)
  let after = camera.worldPoint(cursor, viewportWidth: 1470)
  #expect(abs(world.x - after.x) < 0.00001)
  #expect(abs(world.y - after.y) < 0.00001)
}
@Test func fitWithHeaderOriginIncludesNegativeCoordinates() {
  var w = Workspace.demo()
  w.notes[0].x = -500
  w.notes[0].y = -600
  let viewport = CGSize(width: 1470, height: 830)
  var camera = BoardCamera(origin: CGPoint(x: 0, y: 213))
  camera.fit(notes: w.notes, viewport: viewport)
  let scale = camera.scale(viewportWidth: viewport.width)
  for n in w.notes {
    let top = n.y * scale + camera.origin.y + camera.pan.height
    #expect(top >= 213)
    #expect(top + 256 * scale <= viewport.height - 45)
  }
}

@Test func ropeAnchorsSitAtFacingSideMidpoints() {
  let (a, b) = ConnectionGeometry.endpoints(from: .zero, to: CGPoint(x: 500, y: -100))
  #expect(a == CGPoint(x: 256, y: 128))
  #expect(b == CGPoint(x: 500, y: 28))
}
@Test func ropeSagsAndKeepsBothEndsPinned() {
  let a = CGPoint(x: 100, y: 100)
  let b = CGPoint(x: 700, y: 100)
  var rope = RopeSimulation(start: a, end: b)
  rope.settle(start: a, end: b)
  #expect(rope.points.first == a)
  #expect(rope.points.last == b)
  #expect(rope.points.map(\.y).max()! > 180)
  #expect(rope.motion == 0)
}
@Test func ropeTrailsMovementThenSettles() {
  let a = CGPoint(x: 0, y: 0)
  let b = CGPoint(x: 600, y: 0)
  var rope = RopeSimulation(start: a, end: b)
  rope.settle(start: a, end: b)
  let before = rope.points[10]
  let moved = CGPoint(x: 600, y: -180)
  rope.advance(start: a, end: moved)
  #expect(rope.points.last == moved)
  #expect(rope.points[10] != before)
  #expect(rope.motion > 0.025)
  for _ in 0..<360 { rope.advance(start: a, end: moved) }
  #expect(rope.motion < 0.1)
  rope.settle(start: a, end: moved)
  #expect(rope.motion == 0)
  #expect(rope.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
}
@Test func ropeHandlesCoincidentAndFastMovingAnchors() {
  var rope = RopeSimulation(start: .zero, end: .zero)
  for i in 0..<100 {
    rope.advance(start: CGPoint(x: Double(i) * 40, y: -Double(i) * 20), end: .zero)
  }
  rope.settle(start: .zero, end: .zero)
  #expect(rope.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
  #expect(rope.points.first == .zero)
  #expect(rope.points.last == .zero)
}

@Test func sideAttachmentsHaveOutwardNormalsWithoutRigidLeads() {
  let (left, right) = ConnectionGeometry.attachments(from: .zero, to: CGPoint(x: 600, y: 20))
  #expect(left.point.y == 128 && left.outward.y == 0)
  #expect(left.outward.x == 1)
  #expect(right.point.y == 148 && right.outward.y == 0)
  #expect(right.outward.x == -1)
  let (top, bottom) = ConnectionGeometry.attachments(from: .zero, to: CGPoint(x: 20, y: 600))
  #expect(top.point == CGPoint(x: 128, y: 256))
  #expect(bottom.point == CGPoint(x: 148, y: 600))
  #expect(top.outward == CGPoint(x: 0, y: 1))
}
@Test func connectionStyleIsBackwardCompatibleAndSurvivesImport() throws {
  let old = Data(#"{"id":"old","from":"note-0","to":"note-1"}"#.utf8)
  let decoded = try JSONDecoder().decode(Connection.self, from: old)
  #expect(decoded.colour == .sage && !decoded.rigid)
  var backup = Workspace.demo()
  backup.connections = [Connection(from: "note-0", to: "note-1", colour: .blue, rigid: true)]
  let roundtrip = try Workspace.decode(try backup.encoded())
  #expect(roundtrip.connections[0].colour == .blue && roundtrip.connections[0].rigid)
  var current = Workspace.demo()
  try current.importCopy(roundtrip)
  #expect(current.connections[0].colour == .blue && current.connections[0].rigid)
}

@Test func flexibleRopeStartsBendingAtItsPinnedSideMidpoint() {
  let (a, b) = ConnectionGeometry.attachments(from: .zero, to: CGPoint(x: 650, y: 30))
  var rope = RopeSimulation(start: a.point, end: b.point)
  rope.settle(start: a.point, end: b.point, startOutward: a.outward, endOutward: b.outward)
  #expect(rope.points.first == a.point && rope.points.last == b.point)
  #expect(rope.points[1].y > a.point.y + 1)
  #expect(rope.points[1].x >= a.point.x)
  #expect(rope.points[rope.points.count - 2].x <= b.point.x)
}

@Test func tighteningReducesSagAndLegacyConnectionsKeepTheirOriginalSlack() throws {
  let a = CGPoint(x: 0, y: 0)
  let b = CGPoint(x: 650, y: 0)
  var loose = RopeSimulation(start: a, end: b, tightness: 0)
  var tight = RopeSimulation(start: a, end: b, tightness: 0.9)
  loose.settle(start: a, end: b, tightness: 0)
  tight.settle(start: a, end: b, tightness: 0.9)
  #expect(loose.points.map(\.y).max()! > tight.points.map(\.y).max()! + 50)
  let legacy = try JSONDecoder().decode(
    Connection.self, from: Data(#"{"id":"old","from":"a","to":"b"}"#.utf8))
  #expect(legacy.tightness == 0.5)
  var w = Workspace.demo()
  w.connections = [Connection(from: "note-0", to: "note-1", tightness: 0.8)]
  let roundTrip = try Workspace.decode(w.encoded())
  #expect(roundTrip.connections[0].tightness == 0.8)
  var imported = Workspace.demo()
  try imported.importCopy(roundTrip)
  #expect(imported.connections[0].tightness == 0.8)
}
