import SprigCore
import SwiftUI

struct HomeView: View {
  @Bindable var store: AppStore
  var body: some View {
    GeometryReader { geo in
      let compact = geo.size.width < 1180
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          HStack(spacing: 36) {
            Text("Pick up where you left off").font(Theme.font(16, .semibold)).frame(
              maxWidth: .infinity, alignment: .leading)
            if !compact {
              Text("Pinned boards").font(Theme.font(16, .semibold)).frame(
                width: 430, alignment: .leading)
            }
          }.frame(height: 28)
          if compact {
            continueCard
            Text("Pinned boards").font(Theme.font(16, .semibold))
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16
            ) { pinnedBoards }
          } else {
            HStack(alignment: .top, spacing: 36) {
              continueCard
              VStack(spacing: 16) { pinnedBoards }.frame(width: 430)
            }
          }
          HStack {
            Text("Recent notes").font(Theme.font(16, .semibold))
            Spacer()
            Button("All notes ↗") {
              store.folderID = nil
              store.showingTrash = false
              store.navigate(.library)
            }.font(Theme.font(12, .medium)).foregroundStyle(Theme.accent)
          }.frame(height: 28)
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 196, maximum: 196), spacing: 26)],
            alignment: .leading, spacing: 26
          ) {
            ForEach(store.recentNotes) { note in
              let board = store.workspace.boards.first { $0.id == note.boardId }
              StickyNoteView(
                note: note, compact: true, boardTitle: board?.title ?? "",
                subject: board.map { store.workspace.subject(for: $0) } ?? ""
              ) { store.openNote(note.id) }.transition(.opacity)
            }
          }.sprigAnimate(store.recentNotes.map(\.id))
        }.padding(.horizontal, 64).padding(.top, 156).padding(.bottom, 64)
      }.scrollIndicators(.hidden)
    }
  }
  @ViewBuilder private var pinnedBoards: some View {
    let boards = Array(store.workspace.boards.filter(\.pinned).prefix(3))
    ForEach(boards) { board in
      Button {
        store.openBoard(board.id)
      } label: {
        HStack(spacing: 14) {
          FigmaIcon(name: "Board", group: "component0", size: 22).frame(width: 54, height: 54)
            .background(board.colour.fill, in: RoundedRectangle(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 3) {
            Text(board.title).font(Theme.font(16, .semibold)).lineLimit(1)
            Caption(
              "\(store.workspace.subject(for:board)) · \(store.workspace.activeNotes(on:board.id).count) notes"
            ).lineLimit(1)
          }
          Spacer(minLength: 0)
          Caption("↗")
        }.padding(14).frame(height: 82).frame(maxWidth: .infinity, alignment: .leading).background(
          .white, in: RoundedRectangle(cornerRadius: 16))
      }.buttonStyle(SprigButtonStyle()).transition(.opacity)
    }
    if boards.isEmpty {
      Text("Pin a board from its options to keep it close.").font(Theme.font(12)).foregroundStyle(
        Theme.muted
      ).padding(20).frame(maxWidth: .infinity, minHeight: 82).background(
        .white, in: RoundedRectangle(cornerRadius: 16))
    }
  }
  private var continueCard: some View {
    HStack(alignment: .top, spacing: 24) {
      VStack(alignment: .leading, spacing: 12) {
        Caption(store.board.map { store.workspace.subject(for: $0).uppercased() } ?? "")
        Text(store.board?.title ?? "Your first board").font(Theme.font(24, .bold)).lineLimit(2)
        Text(
          store.board.map { store.workspace.path(to: $0.folderId).last?.name ?? "" }
            ?? "A little structure. Space to think."
        ).foregroundStyle(Theme.muted)
        Spacer(minLength: 0)
        PillButton(title: store.board == nil ? "Create a board" : "Open board  ↗") {
          if let board = store.board {
            store.openBoard(board.id)
          } else {
            store.form = store.workspace.folders.isEmpty ? .folder : .board
          }
        }
        Caption("\(store.notes.count) notes · \(store.saveStatus)")
      }.frame(width: 268, alignment: .leading)
      MiniatureView(notes: store.notes).frame(maxWidth: .infinity)
    }.padding(24).frame(height: 292).frame(maxWidth: .infinity, alignment: .leading).background(
      .white, in: RoundedRectangle(cornerRadius: 20)
    ).overlay(
      RoundedRectangle(cornerRadius: 20).strokeBorder(
        Color(red: 0.9, green: 0.91, blue: 0.88), lineWidth: 1)
    ).sprigAnimate(store.workspace.boards.filter(\.pinned).map(\.id))
  }
}
