import AppKit
import SprigCore
import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
  let markdown: String
  let colour: NoteColour
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    let view = WKWebView(frame: .zero, configuration: config)
    view.setValue(false, forKey: "drawsBackground")
    view.navigationDelegate = context.coordinator
    context.coordinator.text = markdown
    context.coordinator.colour = colour
    if let url = Bundle.sprigResources.url(
      forResource: "index", withExtension: "html", subdirectory: "Markdown")
    {
      view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    return view
  }
  func updateNSView(_ view: WKWebView, context: Context) {
    context.coordinator.text = markdown
    context.coordinator.colour = colour
    context.coordinator.render(view)
  }
  @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
    var text = "", colour: NoteColour = .butter, ready = false
    private var lastText: String?
    private var lastColour: NoteColour?
    func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) {
      ready = true
      render(view)
    }
    func render(_ view: WKWebView) {
      guard ready, lastText != text || lastColour != colour,
        let payload = try? JSONSerialization.data(withJSONObject: [text, colour.css]),
        let json = String(data: payload, encoding: .utf8)
      else { return }
      let snapshot = text
      let tint = colour
      view.evaluateJavaScript("window.sprigRender(...\(json))") { [weak self] _, error in
        guard error == nil else { return }
        self?.lastText = snapshot
        self?.lastColour = tint
      }
    }
    func webView(
      _ view: WKWebView, decidePolicyFor action: WKNavigationAction,
      decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
      if action.navigationType == .linkActivated {
        if let url = action.request.url, ["https", "http"].contains(url.scheme?.lowercased() ?? "")
        {
          NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
      } else {
        decisionHandler(.allow)
      }
    }
  }
}

@MainActor @Observable final class SourceCommands {
  static weak var current: SourceCommands?
  weak var webView: WKWebView?
  var ready = false
  var pending: [String] = []
  var commit: ((String) -> Void)?
  func flush(_ completion: @escaping () -> Void) {
    guard ready, let view = webView else {
      completion()
      return
    }
    view.evaluateJavaScript("window.sprigEditor.getText()") { [weak self] value, _ in
      if let text = value as? String { self?.commit?(text) }
      completion()
    }
  }
  func request(_ format: MarkdownFormat) { perform(format.rawValue) }
  func perform(_ action: String) {
    guard ready, let view = webView else {
      pending.append(action)
      return
    }
    guard let data = try? JSONSerialization.data(withJSONObject: [action]),
      let json = String(data: data, encoding: .utf8)
    else { return }
    view.evaluateJavaScript("window.sprigEditor.action(...\(json))")
    view.window?.makeFirstResponder(view)
  }
  func activate() {
    ready = true
    Self.current = self
    let actions = pending
    pending = []
    for action in actions { perform(action) }
  }
}

/// Live editing keeps one Markdown document and one undo history in a local WebKit editor.
struct MarkdownLiveEditor: NSViewRepresentable {
  @Binding var text: String
  let commands: SourceCommands
  var sourceMode: Bool
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.userContentController.add(context.coordinator, name: "sprigEditor")
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.setValue(false, forKey: "drawsBackground")
    view.navigationDelegate = context.coordinator
    view.setAccessibilityLabel("Note text")
    commands.webView = view
    commands.commit = { [weak coordinator = context.coordinator] text in coordinator?.accept(text) }
    if let url = Bundle.sprigResources.url(
      forResource: "index", withExtension: "html", subdirectory: "Markdown")
    {
      view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    return view
  }
  func updateNSView(_ view: WKWebView, context: Context) {
    context.coordinator.parent = self
    context.coordinator.sync(view)
  }
  static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
    view.configuration.userContentController.removeScriptMessageHandler(forName: "sprigEditor")
    coordinator.disposed = true
    coordinator.parent.commands.ready = false
    if SourceCommands.current === coordinator.parent.commands { SourceCommands.current = nil }
  }
  @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: MarkdownLiveEditor
    var lastText: String?
    var lastMode: Bool?
    var ready = false
    var disposed = false
    init(_ parent: MarkdownLiveEditor) { self.parent = parent }
    func javascript(_ arguments: [Any]) -> String {
      guard let data = try? JSONSerialization.data(withJSONObject: arguments),
        let json = String(data: data, encoding: .utf8)
      else { return "[]" }
      return json
    }
    func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) {
      let text = parent.text
      let mode = parent.sourceMode
      view.evaluateJavaScript("window.sprigStartEditor(...\(javascript([text, mode])))") {
        [weak self, weak view] _, error in
        guard let self, let view, !self.disposed else { return }
        guard error == nil else { return }
        self.lastText = text
        self.lastMode = mode
        self.ready = true
        self.parent.commands.activate()
        self.sync(view)
      }
    }
    func sync(_ view: WKWebView) {
      guard ready, !disposed else { return }
      if lastText != parent.text {
        lastText = parent.text
        view.evaluateJavaScript("window.sprigEditor.setText(...\(javascript([parent.text])))")
      }
      if lastMode != parent.sourceMode {
        lastMode = parent.sourceMode
        view.evaluateJavaScript("window.sprigEditor.setMode(...\(javascript([parent.sourceMode])))")
      }
    }
    func userContentController(
      _ controller: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      guard message.frameInfo.isMainFrame,
        let body = message.body as? [String: Any], let text = body["text"] as? String
      else { return }
      accept(text)
    }
    func accept(_ text: String) {
      lastText = text
      if parent.text != text { parent.text = text }
    }
    func webView(
      _ view: WKWebView, decidePolicyFor action: WKNavigationAction,
      decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
      if action.navigationType == .linkActivated {
        if let url = action.request.url, ["https", "http"].contains(url.scheme?.lowercased() ?? "")
        {
          NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
      } else {
        decisionHandler(.allow)
      }
    }
  }
}
