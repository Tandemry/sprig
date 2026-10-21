import AppKit
import SprigCore
import SwiftUI

struct RootView: View {
  @Bindable var store: AppStore
  @Namespace private var navigationMotion
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { SprigMotion.isReduced(system: systemReduceMotion) }
  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .topLeading) {
        Theme.background
        ZStack {
          switch store.destination {
          case .home: HomeView(store: store).transition(pageTransition)
          case .boards: BoardView(store: store).transition(pageTransition)
          case .library: LibraryView(store: store).transition(pageTransition)
          case .search: SearchView(store: store).transition(pageTransition)
          }
        }
        header.frame(
          maxWidth: min(460, max(230, (geo.size.width - 400) / 2 - 52)), alignment: .leading
        ).padding(.leading, store.destination == .boards ? 24 : 34).padding(.top, 49)
          .transition(.opacity)
        navigation.frame(width: 400, height: 60).position(x: geo.size.width / 2, y: 79)
        if store.destination == .home {
          PillButton(title: "+  New board") {
            store.form = store.workspace.folders.isEmpty ? .folder : .board
          }.frame(width: 150, height: 44)
            .padding(.top, 57).padding(.trailing, 64).frame(
              maxWidth: .infinity, alignment: .trailing)
        }
        WindowDragRegion().frame(height: 28).padding(.leading, 84)
        if let error = store.error {
          HStack {
            Text(error).font(Theme.font(12))
            Spacer()
            Button("Export recovery data") { store.exportRecovery() }
            Button("Export current backup") { store.exportBackup() }
          }.padding(16).background(NoteColour.rose.fill).padding(.top, 135)
        }
        if let message = store.message {
          HStack {
            Text(message)
            Button("×") { store.message = nil }
          }.font(Theme.font(12)).padding(14).sprigGlass().frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom
          ).padding(.bottom, 75)
        }
      }.disabled(store.editingNote != nil).accessibilityHidden(store.editingNote != nil)
        .overlay {
          if let note = store.editingNote {
            ZStack {
              Rectangle().fill(.ultraThinMaterial).opacity(0.55).onTapGesture {
                store.closeEditor()
              }
              NoteEditor(store: store, note: note).id(note.id).transition(
                reduceMotion
                  ? .opacity
                  : .scale(scale: 0.96).combined(with: .opacity).combined(with: .offset(y: 12)))
            }.frame(width: geo.size.width, height: geo.size.height).transition(.opacity).zIndex(20)
          }
        }.frame(width: geo.size.width, height: geo.size.height).clipped()
        .sprigAnimate(store.destination).sprigAnimate(store.editingID).sprigAnimate(store.message)
        .sprigAnimate(store.error, animation: SprigMotion.fade)
    }
    .frame(minWidth: 960, minHeight: 700)
    .font(Theme.font()).foregroundStyle(Theme.ink).tint(Theme.accent).buttonStyle(
      SprigButtonStyle()
    )
    .preferredColorScheme(.light).ignoresSafeArea()
    .sheet(item: $store.form) { kind in CreateForm(store: store, kind: kind) }
    .background(WindowConfiguration())
    .alert(
      "Sprig",
      isPresented: Binding(
        get: { store.operationError != nil }, set: { if !$0 { store.operationError = nil } })
    ) {
      Button("OK") { store.operationError = nil }
    } message: {
      Text(store.operationError ?? "")
    }
    .task(id: store.message) {
      guard let message = store.message else { return }
      try? await Task.sleep(for: .seconds(4))
      guard !Task.isCancelled, store.message == message else { return }
      store.message = nil
    }
  }
  private var navigation: some View {
    GlassEffectContainer(spacing: 4) {
      HStack(spacing: 4) {
        ForEach(Destination.allCases) { destination in
          Button {
            store.navigate(destination)
          } label: {
            VStack(spacing: 2) {
              FigmaIcon(
                name: destination.rawValue,
                group: destination == .boards ? "detail0" : "component2", size: 20,
                selected: store.destination == destination)
              Text(destination.rawValue).font(Theme.font(11, .medium))
            }.frame(width: 94, height: 48).contentShape(Rectangle()).background {
              if store.destination == destination {
                Capsule().fill(Theme.colour("Selection", 0xdfead8)).matchedGeometryEffect(
                  id: "navigation-selection", in: navigationMotion)
              }
            }.foregroundStyle(store.destination == destination ? Theme.accent : Theme.ink)
          }.buttonStyle(SprigButtonStyle()).accessibilityLabel(destination.rawValue)
            .accessibilityAddTraits(
              store.destination == destination ? .isSelected : [])
        }
      }.padding(6).sprigGlass(30)
    }
  }
  private var pageTransition: AnyTransition {
    reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6))
  }
  @ViewBuilder private var header: some View {
    if store.destination == .boards, let board = store.board {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          ForEach(Array(store.workspace.path(to: board.folderId).enumerated()), id: \.element.id) {
            i, f in
            if i > 0 { Caption("/") }
            Button {
              store.folderID = f.id
              store.navigate(.library)
            } label: {
              Caption(f.name)
            }
          }
        }.frame(height: 16)
        BoardTitle(store: store).id(board.id).frame(height: 44)
        Caption("\(store.notes.count) notes · \(store.saveStatus)")
      }
    } else {
      VStack(alignment: .leading, spacing: 3) {
        Caption("Sprig")
        Text(store.destination.rawValue).font(Theme.font(24, .bold))
      }
    }
  }
}
/// Keeps the title's editing state local to the visible board.
private struct BoardTitle: View {
  @Bindable var store: AppStore
  @State private var editing = false
  @State private var draft = ""
  @FocusState private var focused: Bool
  private var valid: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  var body: some View {
    HStack(spacing: 6) {
      if editing {
        HStack(spacing: 6) {
          TextField("Board name", text: $draft).textFieldStyle(.plain)
            .font(Theme.font(24, .bold)).focused($focused)
            .accessibilityLabel("Board name")
            .task {
              // Wait until the animated field has joined the native focus chain.
              try? await Task.sleep(for: .milliseconds(100))
              guard !Task.isCancelled else { return }
              focused = true
            }
            .onSubmit { save() }
            .onExitCommand { cancel() }
          Button(action: cancel) {
            Image(systemName: "xmark").frame(width: 26, height: 30).contentShape(Rectangle())
          }.accessibilityLabel("Cancel rename").help("Cancel rename (Escape)")
          Button(action: save) {
            Image(systemName: "checkmark").frame(width: 26, height: 30).contentShape(Rectangle())
          }.foregroundStyle(Theme.accent).disabled(!valid)
            .accessibilityLabel("Save board name").help("Save board name (Return)")
        }.padding(.horizontal, 10).padding(.vertical, 5).sprigGlass(14)
          .transition(.opacity)
      } else if let board = store.board {
        Text(board.title).font(Theme.font(24, .bold)).lineLimit(1).truncationMode(.tail)
          .contentShape(Rectangle()).onTapGesture(count: 2) { begin() }
          .accessibilityAction(named: "Rename board") { begin() }
          .help("Double-click to rename")
        Menu {
          Button("Rename board", action: begin)
          Button(board.pinned ? "Unpin board" : "Pin board") { store.togglePin() }
          Button("Export board as Markdown") { store.exportBoard() }
          Button("Switch board") {
            store.folderID = nil
            store.navigate(.library)
          }
        } label: {
          Text("⌄").font(Theme.font(16, .medium))
            .frame(width: 26, height: 32).contentShape(Rectangle())
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Theme.ink)
          .fixedSize().accessibilityLabel("Board options")
          .help("Rename, pin, export or switch board")
        Spacer(minLength: 0)
      }
    }.buttonStyle(SprigButtonStyle()).sprigAnimate(editing, animation: SprigMotion.quick)
  }
  private func begin() {
    draft = store.board?.title ?? ""
    editing = true
  }
  private func cancel() {
    focused = false
    editing = false
  }
  private func save() {
    guard valid else { return }
    store.create(.rename, name: draft, parent: nil)
    cancel()
  }
}

struct WindowConfiguration: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { ConfigurationView() }
  func updateNSView(_ view: NSView, context: Context) {}
  final class ConfigurationView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      window.backgroundColor = NSColor(Theme.background)
      window.isMovableByWindowBackground = false
    }
  }
}

struct WindowDragRegion: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { DragView() }
  func updateNSView(_ view: NSView, context: Context) {}
  final class DragView: NSView {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
  }
}
