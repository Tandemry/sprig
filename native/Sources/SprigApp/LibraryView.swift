import SprigCore
import SwiftUI

struct LibraryView: View {
  @Bindable var store: AppStore
  var body: some View {
    HStack(alignment: .top, spacing: 34) {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          Text("Your library").font(Theme.font(16, .semibold)).padding(.bottom, 12)
          Button("All notes & boards") {
            store.folderID = nil
            store.showingTrash = false
          }.padding(.vertical, 8)
          FolderTree(store: store, parent: nil, depth: 0)
          Button("+ New folder") { store.form = .folder }.padding(.vertical, 8)
          Button("Trash  \(store.workspace.notes.filter{$0.deletedAt != nil}.count)") {
            store.showingTrash = true
          }.padding(.vertical, 8)
          Divider().padding(.vertical, 12)
          Button("Export workspace backup") { store.exportBackup() }
          Button("Import backup") { store.importBackup() }
        }.frame(maxWidth: .infinity, alignment: .leading).buttonStyle(SprigButtonStyle())
      }.frame(width: 216)
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            Text(
              store.showingTrash
                ? "Trash"
                : store.workspace.folders.first { $0.id == store.folderID }?.name
                  ?? "All notes & boards"
            ).font(Theme.font(16, .semibold))
            Spacer()
            if !store.showingTrash { PillButton(title: "+ New board") { store.form = .board } }
          }
          if store.showingTrash {
            Text("Notes stay here until you restore them.").foregroundStyle(Theme.muted)
            if !store.workspace.notes.contains(where: { $0.deletedAt != nil }) {
              Text("Your trash is empty.").foregroundStyle(Theme.muted).padding(.vertical, 24)
            }
            ForEach(store.workspace.notes.filter { $0.deletedAt != nil }) { n in
              HStack {
                Text(n.title)
                Spacer()
                Button("Restore note") { store.restore(n.id) }
              }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 12))
            }
          } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
              ForEach(
                store.libraryBoards
              ) { b in
                Button {
                  store.openBoard(b.id)
                } label: {
                  VStack(alignment: .leading, spacing: 12) {
                    FigmaIcon(name: "Board", group: "component0", size: 22).frame(
                      width: 54, height: 54
                    ).background(b.colour.fill, in: RoundedRectangle(cornerRadius: 10))
                    Text(b.title).font(Theme.font(16, .semibold))
                    Caption(
                      store.workspace.path(to: b.folderId).map(\.name).joined(separator: " / "))
                    Caption("\(store.workspace.activeNotes(on:b.id).count) notes ↗")
                  }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(
                    .white, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(SprigButtonStyle())
              }
            }
            Text("Notes").font(Theme.font(16, .semibold))
            LazyVGrid(
              columns: [GridItem(.adaptive(minimum: 196, maximum: 196), spacing: 26)],
              alignment: .leading, spacing: 26
            ) {
              ForEach(
                store.libraryNotes
              ) { n in
                let b = store.workspace.boards.first { $0.id == n.boardId }
                StickyNoteView(
                  note: n, compact: true, boardTitle: b?.title ?? "",
                  subject: b.map { store.workspace.subject(for: $0) } ?? ""
                ) { store.openNote(n.id) }
              }
            }
          }
        }.padding(.trailing, 24).padding(.bottom, 40).sprigAnimate(store.libraryBoards.map(\.id))
          .sprigAnimate(store.libraryNotes.map(\.id)).sprigAnimate(store.showingTrash)
      }
    }.padding(.horizontal, 34).padding(.top, 170).padding(.bottom, 20).sprigAnimate(store.folderID)
      .sprigAnimate(store.collapsedFolders)
  }
}
struct FolderTree: View {
  @Bindable var store: AppStore
  let parent: String?
  let depth: Int
  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      ForEach(store.workspace.folders.filter { $0.parentId == parent }) { folder in
        HStack(spacing: 6) {
          if store.workspace.folders.contains(where: { $0.parentId == folder.id }) {
            Button {
              if store.collapsedFolders.contains(folder.id) {
                store.collapsedFolders.remove(folder.id)
              } else {
                store.collapsedFolders.insert(folder.id)
              }
            } label: {
              Text(store.collapsedFolders.contains(folder.id) ? "▸" : "▾").frame(
                width: 16, height: 26)
            }.accessibilityLabel("Toggle \(folder.name) subfolders")
          } else {
            Text("▱").frame(width: 16)
          }
          Button {
            store.folderID = folder.id
            store.showingTrash = false
          } label: {
            HStack {
              Text(folder.name).lineLimit(1)
              Spacer(minLength: 0)
            }.padding(.vertical, 8)
          }
        }.padding(.leading, CGFloat(depth) * 12 + 8).padding(.trailing, 8).background(
          store.folderID == folder.id ? Theme.accent.opacity(0.12) : .clear,
          in: RoundedRectangle(cornerRadius: 8)
        ).buttonStyle(SprigButtonStyle())
        if !store.collapsedFolders.contains(folder.id) {
          FolderTree(store: store, parent: folder.id, depth: depth + 1).transition(.opacity)
        }
      }
    }
  }
}
struct SearchView: View {
  @Bindable var store: AppStore
  @FocusState private var searchFocused: Bool
  private var results: [Note] {
    store.activeNotes.filter { n in
      store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || "\(n.title) \(n.markdown) \(store.workspace.boards.first{$0.id==n.boardId}?.title ?? "") \(store.workspace.boards.first{$0.id==n.boardId}.map{store.workspace.path(to:$0.folderId).map(\.name).joined(separator:" ")} ?? "")"
          .localizedCaseInsensitiveContains(
            store.query.trimmingCharacters(in: .whitespacesAndNewlines))
    }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        HStack(spacing: 14) {
          FigmaIcon(name: "Search")
          TextField("Find a thought, topic or note…", text: $store.query).textFieldStyle(.plain)
            .font(Theme.font(16)).accessibilityLabel("Search notes").focused($searchFocused)
          Caption("⌘K")
        }.padding(.horizontal, 22).frame(height: 55).sprigGlass().frame(maxWidth: 700)
        Text(
          store.query.isEmpty
            ? "Search across your notes and Markdown." : "\(results.count) matching notes"
        ).foregroundStyle(Theme.muted)
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 196, maximum: 196), spacing: 26)],
          alignment: .leading, spacing: 26
        ) {
          ForEach(results) { n in
            let b = store.workspace.boards.first { $0.id == n.boardId }
            StickyNoteView(
              note: n, compact: true, boardTitle: b?.title ?? "",
              subject: b.map { store.workspace.subject(for: $0) } ?? ""
            ) { store.openNote(n.id) }
          }
        }
        if results.isEmpty {
          Text("No notes found. Try a different word.").foregroundStyle(Theme.muted)
        }
      }.padding(.horizontal, 64).padding(.top, 170).padding(.bottom, 50).sprigAnimate(
        results.map(\.id))
    }.task(id: store.searchFocusRequest) {
      // Wait for the incoming page to attach its native text field.
      try? await Task.sleep(for: .milliseconds(100))
      guard !Task.isCancelled else { return }
      searchFocused = true
    }
  }
}
struct CreateForm: View {
  @Bindable var store: AppStore
  let kind: CreateKind
  @State private var name = ""
  @FocusState private var nameFocused: Bool
  @State private var parent = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text(kind.rawValue).font(Theme.font(20, .semibold))
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text(kind == .rename ? "Board name" : "Name")
            .font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
          TextField("Name", text: $name).labelsHidden().textFieldStyle(.plain)
            .font(Theme.font(15)).focused($nameFocused)
            .padding(13).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
              nameFocused ? Theme.accent.opacity(0.6) : Theme.muted.opacity(0.2), lineWidth: 1))
            .accessibilityLabel(kind == .rename ? "Board name" : "Name")
        }
        if kind != .rename {
          Picker(kind == .folder ? "Inside folder" : "Folder", selection: $parent) {
            if kind == .folder { Text("Top level").tag("") }
            ForEach(store.workspace.folders) { f in
              Text(store.workspace.path(to: f.id).map(\.name).joined(separator: " / ")).tag(f.id)
            }
          }
        }
      }
      HStack {
        Spacer()
        Button("Cancel") { store.form = nil }.keyboardShortcut(.cancelAction)
          .buttonStyle(.glass).controlSize(.large).tint(.white.opacity(0.2))
          .foregroundStyle(Theme.ink)
        Button(kind == .rename ? "Save name" : "Create") {
          store.create(kind, name: name, parent: parent.isEmpty ? nil : parent)
        }.keyboardShortcut(.defaultAction).buttonStyle(.glassProminent).controlSize(.large).tint(Theme.accent).disabled(
          name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (kind == .board && parent.isEmpty))
      }
    }.padding(26).frame(width: 400).background(Theme.background)
      .font(Theme.font()).foregroundStyle(Theme.ink).tint(Theme.accent)
      .presentationCornerRadius(24).onAppear {
      nameFocused = true
      name = kind == .rename ? store.board?.title ?? "" : ""
      parent = store.folderID ?? store.board?.folderId ?? store.workspace.folders.first?.id ?? ""
    }
  }
}
