import AppKit
import SwiftUI

@main struct SprigApp: App {
  @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
  @State private var store: AppStore
  init() {
    Theme.registerFonts()
    let url = ProcessInfo.processInfo.environment["SPRIG_WORKSPACE_PATH"].map {
      URL(fileURLWithPath: $0)
    }
    let model = AppStore(url: url)
    AppLifecycle.store = model
    _store = State(initialValue: model)
  }
  var body: some Scene {
    Window("Sprig", id: "main") {
      RootView(store: store)
    }
    .windowStyle(.hiddenTitleBar).defaultSize(width: 1470, height: 830)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New board") {
          store.closeEditor()
          store.form = store.workspace.folders.isEmpty ? .folder : .board
        }.keyboardShortcut(
          "n", modifiers: [.command, .shift]
        ).disabled(store.form != nil)
        Button("New note") {
          store.destination = .boards
          store.addNote(.butter)
        }.keyboardShortcut("n").disabled(store.form != nil || store.board == nil)
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo") {
          if let text = NSApp.keyWindow?.firstResponder as? NSTextView {
            if text.undoManager?.canUndo == true { text.undoManager?.undo() }
          } else if store.editingID != nil {
            SourceCommands.current?.perform("undo")
          } else {
            store.undo()
          }
        }.keyboardShortcut("z")
        Button("Redo") {
          if let text = NSApp.keyWindow?.firstResponder as? NSTextView {
            if text.undoManager?.canRedo == true { text.undoManager?.redo() }
          } else if store.editingID != nil {
            SourceCommands.current?.perform("redo")
          } else {
            store.redo()
          }
        }.keyboardShortcut("z", modifiers: [.command, .shift])
      }
      CommandGroup(after: .importExport) {
        Button("Import Sprig backup…") { store.importBackup() }
        Button("Export workspace backup…") { store.exportBackup() }
      }
      CommandMenu("Navigate") {
        ForEach(Destination.allCases) { destination in
          Button(destination.rawValue) { store.navigate(destination) }.disabled(store.form != nil)
            .keyboardShortcut(
              destination == .search
                ? "k" : destination == .home ? "1" : destination == .boards ? "2" : "3")
        }
      }
    }
  }
}

@MainActor final class AppLifecycle: NSObject, NSApplicationDelegate {
  static weak var store: AppStore?
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if let editor = SourceCommands.current, editor.ready {
      editor.flush { [weak self] in
        guard let self else {
          sender.reply(toApplicationShouldTerminate: false)
          return
        }
        sender.reply(toApplicationShouldTerminate: self.finishTermination() == .terminateNow)
      }
      return .terminateLater
    }
    return finishTermination()
  }
  private func finishTermination() -> NSApplication.TerminateReply {
    guard let store = Self.store, !store.flush() else { return .terminateNow }
    let alert = NSAlert()
    alert.messageText = "Your latest changes could not be saved"
    alert.informativeText = store.error ?? "Export a backup before quitting to keep your work."
    alert.addButton(withTitle: "Keep Sprig open")
    alert.addButton(withTitle: "Export backup…")
    alert.addButton(withTitle: "Quit anyway")
    switch alert.runModal() {
    case .alertThirdButtonReturn: return .terminateNow
    case .alertSecondButtonReturn:
      store.exportBackup()
      return .terminateCancel
    default: return .terminateCancel
    }
  }
}
