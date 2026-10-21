import Foundation

public enum NoteColour: String, Codable, CaseIterable, Sendable {
  case butter, sage, rose, lilac, apricot
}
public struct Folder: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var parentId: String?
  public init(id: String = UUID().uuidString, name: String, parentId: String?) {
    self.id = id
    self.name = name
    self.parentId = parentId
  }
}
public struct Board: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var folderId: String
  public var pinned: Bool
  public var colour: NoteColour
  public init(
    id: String = UUID().uuidString, title: String, folderId: String, pinned: Bool = false,
    colour: NoteColour = .butter
  ) {
    self.id = id
    self.title = title
    self.folderId = folderId
    self.pinned = pinned
    self.colour = colour
  }
}
public struct Note: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var boardId: String
  public var title: String
  public var markdown: String
  public var category: String
  public var meta: String
  public var summary: String
  public var colour: NoteColour
  public var x: Double
  public var y: Double
  public var updatedAt: Double
  public var deletedAt: Double?
  public init(
    id: String = UUID().uuidString, boardId: String, title: String = "Untitled note",
    markdown: String = "", colour: NoteColour = .butter, x: Double = 200, y: Double = 80
  ) {
    self.id = id
    self.boardId = boardId
    self.title = title
    self.markdown = markdown
    self.colour = colour
    self.x = x
    self.y = y
    self.category = "NOTE"
    self.meta = "Markdown · Updated just now"
    self.summary = ""
    self.updatedAt = Date().timeIntervalSince1970 * 1000
  }
}
public enum RopeColour: String, Codable, CaseIterable, Sendable {
  case sage, rose, blue, lilac, amber, charcoal
}
public struct Connection: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var from: String
  public var to: String
  public var colour: RopeColour
  public var rigid: Bool
  public var tightness: Double
  public init(
    id: String = UUID().uuidString, from: String, to: String, colour: RopeColour = .sage,
    rigid: Bool = false, tightness: Double = 0.5
  ) {
    self.id = id
    self.from = from
    self.to = to
    self.colour = colour
    self.rigid = rigid
    self.tightness = tightness
  }
  private enum CodingKeys: String, CodingKey { case id, from, to, colour, rigid, tightness }
  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    from = try values.decode(String.self, forKey: .from)
    to = try values.decode(String.self, forKey: .to)
    colour = try values.decodeIfPresent(RopeColour.self, forKey: .colour) ?? .sage
    rigid = try values.decodeIfPresent(Bool.self, forKey: .rigid) ?? false
    tightness = try values.decodeIfPresent(Double.self, forKey: .tightness) ?? 0.5
  }
}
public enum WorkspaceError: Error, LocalizedError {
  case invalid(String)
  public var errorDescription: String? {
    if case .invalid(let message) = self { return message }
    return nil
  }
}
public struct Workspace: Codable, Equatable, Sendable {
  public var version: Int
  public var folders: [Folder]
  public var boards: [Board]
  public var notes: [Note]
  public var connections: [Connection]
  public static func demo() -> Workspace {
    // This bundled fixture is checked against the shared JSON schema in tests.
    let url = Bundle.module.url(forResource: "Demo", withExtension: "json")!
    return try! JSONDecoder().decode(Workspace.self, from: Data(contentsOf: url))
  }
  public static func decode(_ data: Data) throws -> Workspace {
    let workspace = try JSONDecoder().decode(Workspace.self, from: data)
    try workspace.validate()
    return workspace
  }
  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }
  public func validate() throws {
    guard version == 1 else { throw WorkspaceError.invalid("Unsupported workspace version.") }
    let folderIDs = Set(folders.map(\.id))
    let boardIDs = Set(boards.map(\.id))
    let noteIDs = Set(notes.map(\.id))
    guard folderIDs.count == folders.count, boardIDs.count == boards.count,
      noteIDs.count == notes.count, Set(connections.map(\.id)).count == connections.count
    else { throw WorkspaceError.invalid("Duplicate identifiers in workspace.") }
    for f in folders {
      var seen: Set<String> = [f.id]
      var parent = f.parentId
      while let id = parent {
        guard !seen.contains(id), let next = folders.first(where: { $0.id == id }) else {
          throw WorkspaceError.invalid("Invalid folder hierarchy.")
        }
        seen.insert(id)
        parent = next.parentId
      }
    }
    guard boards.allSatisfy({ folderIDs.contains($0.folderId) }),
      notes.allSatisfy({
        boardIDs.contains($0.boardId) && $0.x.isFinite && $0.y.isFinite && $0.updatedAt.isFinite
          && ($0.deletedAt?.isFinite ?? true)
      })
    else { throw WorkspaceError.invalid("Workspace contains an invalid board or note.") }
    for c in connections {
      guard c.tightness.isFinite, (0...1).contains(c.tightness) else {
        throw WorkspaceError.invalid("Invalid rope tightness.")
      }
      guard c.from != c.to, let a = notes.first(where: { $0.id == c.from }),
        let b = notes.first(where: { $0.id == c.to }), a.boardId == b.boardId
      else { throw WorkspaceError.invalid("Invalid note connection.") }
    }
  }
  public func path(to id: String) -> [Folder] {
    var result: [Folder] = []
    var seen = Set<String>()
    var current = folders.first { $0.id == id }
    while let f = current, !seen.contains(f.id) {
      result.insert(f, at: 0)
      seen.insert(f.id)
      current = folders.first { $0.id == f.parentId }
    }
    return result
  }
  public func activeNotes(on boardID: String) -> [Note] {
    notes.filter { $0.boardId == boardID && $0.deletedAt == nil }
  }
  public func subject(for board: Board) -> String {
    let p = path(to: board.folderId)
    return (p.count > 1 ? p[1].name : p.first?.name) ?? ""
  }
  public func markdown(for board: Board) -> String {
    "# \(board.title)\n\n\(path(to:board.folderId).map(\.name).joined(separator:" / "))\n\n"
      + activeNotes(on: board.id).map { "## \($0.title)\n\n\($0.markdown)" }.joined(
        separator: "\n\n---\n\n")
  }
  public mutating func importCopy(_ incoming: Workspace) throws {
    try incoming.validate()
    let fm = Dictionary(uniqueKeysWithValues: incoming.folders.map { ($0.id, UUID().uuidString) })
    let bm = Dictionary(uniqueKeysWithValues: incoming.boards.map { ($0.id, UUID().uuidString) })
    let nm = Dictionary(uniqueKeysWithValues: incoming.notes.map { ($0.id, UUID().uuidString) })
    folders += incoming.folders.map {
      var f = $0
      f.id = fm[f.id]!
      f.parentId = f.parentId.flatMap { fm[$0] }
      return f
    }
    boards += incoming.boards.map {
      var b = $0
      b.id = bm[b.id]!
      b.folderId = fm[b.folderId]!
      return b
    }
    notes += incoming.notes.map {
      var n = $0
      n.id = nm[n.id]!
      n.boardId = bm[n.boardId]!
      return n
    }
    connections += incoming.connections.map {
      Connection(
        from: nm[$0.from]!, to: nm[$0.to]!, colour: $0.colour, rigid: $0.rigid,
        tightness: $0.tightness)
    }
  }
}

public struct WorkspaceHistory: Sendable {
  public private(set) var current: Workspace
  private var past: [Workspace] = [], future: [Workspace] = []
  private var lastGroup: String?
  public init(_ workspace: Workspace) { current = workspace }
  public var canUndo: Bool { !past.isEmpty }
  public var canRedo: Bool { !future.isEmpty }
  public mutating func apply(group: String? = nil, _ change: (inout Workspace) -> Void) {
    var next = current
    change(&next)
    guard next != current else { return }
    if group == nil || group != lastGroup {
      past.append(current)
      if past.count > 80 { past.removeFirst() }
    }
    current = next
    future = []
    lastGroup = group
  }
  public mutating func undo() {
    guard let previous = past.popLast() else { return }
    future.append(current)
    current = previous
    lastGroup = nil
  }
  public mutating func redo() {
    guard let next = future.popLast() else { return }
    past.append(current)
    current = next
    lastGroup = nil
  }
}

public struct WorkspaceFile: Sendable {
  public let url: URL
  public init(url: URL) { self.url = url }
  public func load() throws -> Workspace? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try Workspace.decode(Data(contentsOf: url))
  }
  public func save(_ workspace: Workspace) throws {
    try workspace.validate()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try workspace.encoded().write(to: url, options: .atomic)
  }
}

extension Workspace {
  /// A parent folder includes the material filed in every descendant.
  public func folderIDs(includingDescendantsOf id: String?) -> Set<String> {
    guard let id else { return Set(folders.map(\.id)) }
    var found: Set<String> = [id]
    var pending = [id]
    while let parent = pending.popLast() {
      for folder in folders where folder.parentId == parent && !found.contains(folder.id) {
        found.insert(folder.id)
        pending.append(folder.id)
      }
    }
    return found
  }
}

/// Disk work is serial and off the UI thread; obsolete queued edits are skipped.
/// Comparing the last observed bytes also prevents a second instance overwriting newer work.
public final class WorkspaceWriter: @unchecked Sendable {
  private let file: WorkspaceFile
  private let queue = DispatchQueue(label: "dev.tandemry.sprig.persistence", qos: .userInitiated)
  private let lock = NSLock()
  private var revision = 0
  private var lastBytes: Data?
  public init(file: WorkspaceFile) throws {
    self.file = file
    lastBytes =
      FileManager.default.fileExists(atPath: file.url.path) ? try Data(contentsOf: file.url) : nil
  }
  private func persist(_ workspace: Workspace) throws {
    try FileManager.default.createDirectory(
      at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var result: Result<Void, any Error>?
    coordinator.coordinate(
      writingItemAt: file.url, options: .forReplacing, error: &coordinationError
    ) { url in
      result = Result {
        let exists = FileManager.default.fileExists(atPath: url.path)
        let disk = exists ? try Data(contentsOf: url) : nil
        guard disk == lastBytes else {
          throw WorkspaceError.invalid(
            "This workspace changed in another app or window. Export your current work as a backup, then reopen Sprig to load the newer file."
          )
        }
        try WorkspaceFile(url: url).save(workspace)
        lastBytes = try Data(contentsOf: url)
      }
    }
    if let coordinationError { throw coordinationError }
    guard let result else {
      throw WorkspaceError.invalid("The workspace file could not be accessed.")
    }
    try result.get()
  }

  public func enqueue(
    _ workspace: Workspace, completion: @escaping @Sendable (Result<Void, any Error>) -> Void
  ) {
    let generation = lock.withLock {
      revision += 1
      return revision
    }
    queue.async { [self] in
      guard lock.withLock({ revision == generation }) else { return }
      completion(Result { try persist(workspace) })
    }
  }
  public func flush(_ workspace: Workspace) throws {
    lock.withLock { revision += 1 }
    try queue.sync { try persist(workspace) }
  }
}
