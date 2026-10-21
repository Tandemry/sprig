import SprigCore
import SwiftUI

struct StickyNoteView: View {
  let note: Note
  var compact = false
  var boardTitle = ""
  var subject = ""
  var selected = false
  var doubleClick: (() -> Void)? = nil
  var open: () -> Void
  @State private var hovered = false
  @Environment(\.accessibilityReduceMotion) private var systemReduced
  private var reduced: Bool { SprigMotion.isReduced(system: systemReduced) }
  private var bodyText: String {
    if compact { return note.summary.isEmpty ? String(note.markdown.prefix(120)) : note.summary }
    return note.markdown.components(separatedBy: "<details>")[0].replacingOccurrences(
      of: "\n- ", with: "\n• "
    ).replacingOccurrences(of: "^- ", with: "• ", options: .regularExpression)
  }
  private var renderedBody: AttributedString {
    var result = AttributedString()
    for (index, line) in bodyText.components(separatedBy: "\n").enumerated() {
      if index > 0 { result.append(AttributedString("\n")) }
      let heading = line.range(of: "^#{1,6} ", options: .regularExpression)
      let content = heading.map { String(line[$0.upperBound...]) } ?? line
      var rendered =
        (try? AttributedString(
          markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(content)
      if heading != nil { rendered.font = Theme.font(compact ? 13 : 16, .semibold) }
      result.append(rendered)
    }
    return result
  }
  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 10 : 11) {
      Caption(compact ? boardTitle.uppercased() : note.category)
      Text(note.title.isEmpty ? "Untitled note" : note.title).font(Theme.font(16, .semibold))
        .foregroundStyle(Theme.ink).multilineTextAlignment(.leading).lineLimit(2).frame(
          maxWidth: .infinity, alignment: .leading)
      Text(renderedBody).font(Theme.font(compact ? 12 : 13)).lineSpacing(compact ? 2 : 3)
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped()
      Caption(compact ? subject : note.meta).lineLimit(2)
    }
    .padding(18).frame(
      width: compact ? 196 : 256, height: compact ? 196 : 256, alignment: .topLeading
    )
    .background(note.colour.fill, in: RoundedRectangle(cornerRadius: 12))
    .shadow(color: Color.black.opacity(compact ? 0.05 : 0.07), radius: 5, x: 0, y: compact ? 3 : 4)
    // The selection halo must occlude ropes behind its gap and translucent stroke.
    .background {
      if selected {
        RoundedRectangle(cornerRadius: 16).fill(Theme.background).padding(-5)
          .allowsHitTesting(false)
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: 12).stroke(
        Theme.accent.opacity(selected ? 0.7 : 0), lineWidth: 2
      ).padding(-4)
    )
    .scaleEffect(reduced ? 1 : hovered ? 1.008 : 1)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { (doubleClick ?? open)() }
    .onTapGesture { open() }
    .onHover { hovered = $0 }
    .sprigAnimate(hovered, animation: SprigMotion.quick).sprigAnimate(note.colour).sprigAnimate(
      selected, animation: SprigMotion.quick
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(note.title.isEmpty ? "Untitled note" : note.title), \(compact ? boardTitle : note.category)"
    )
    .accessibilityAddTraits(.isButton).accessibilityAction { open() }
    .accessibilityIdentifier("note-\(note.id)")
  }
}
struct NotePileView: View {
  let colour: NoteColour
  var action: () -> Void
  var drop: (CGPoint) -> Void
  @State private var hovered = false
  @GestureState(resetTransaction: Transaction(animation: SprigMotion.settle))
    private var translation = CGSize.zero
  @GestureState private var dragging = false
  @Environment(\.accessibilityReduceMotion) private var systemReduced
  private var reduced: Bool { SprigMotion.isReduced(system: systemReduced) }
  var body: some View {
    GeometryReader { geometry in
      let source = geometry.frame(in: .named("sprig-board"))
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 9).fill(colour.fill.opacity(0.65)).frame(
          width: 88, height: 88
        ).rotationEffect(.degrees(-6)).offset(x: 17, y: 0)
        RoundedRectangle(cornerRadius: 9).fill(colour.fill.opacity(0.82)).frame(
          width: 88, height: 88
        ).rotationEffect(.degrees(5)).offset(x: 2, y: 14)
        // Only the top sheet follows the pointer; the rest of the pile stays put.
        RoundedRectangle(cornerRadius: 9).fill(colour.fill).frame(width: 88, height: 88)
          .rotationEffect(.degrees(hovered && !reduced ? -8 : -5)).offset(
            y: hovered && !reduced ? -4 : 0
          ).shadow(color: .black.opacity(0.17), radius: 20, x: 0, y: 8)
          .offset(x: 15 + translation.width, y: 6 + translation.height)
          .allowsHitTesting(false)
      }.frame(width: 116, height: 112, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .gesture(
          DragGesture(minimumDistance: 5, coordinateSpace: .named("sprig-board"))
            .updating($translation) { gesture, state, transaction in
              transaction.animation = nil
              state = gesture.translation
            }
            .updating($dragging) { _, state, _ in state = true }
            .onEnded { gesture in
              // Returning a fresh sheet to its own pile never creates workspace data.
              guard !source.contains(gesture.location) else { return }
              drop(gesture.location)
            }
        )
    }.frame(width: 116, height: 112)
      .zIndex(dragging ? 1 : 0)
      .onHover { hovered = $0 }.sprigAnimate(hovered, animation: SprigMotion.quick)
      .transaction { if reduced { $0.animation = nil } }
      .help("Drag or click to create a \(colour.rawValue) note; return it to this pile to cancel")
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("New \(colour.rawValue) note")
      .accessibilityAddTraits(.isButton).accessibilityAction { action() }
  }
}
struct MiniatureView: View {
  var notes: [Note]
  var body: some View {
    GeometryReader { geo in
      let visible = Array(notes.prefix(6))
      let minX = visible.map(\.x).min() ?? 0
      let minY = visible.map(\.y).min() ?? 0
      let width = max(256, (visible.map { $0.x + 256 }.max() ?? 256) - minX)
      let height = max(256, (visible.map { $0.y + 256 }.max() ?? 256) - minY)
      let scale = min(max(1, geo.size.width - 48) / width, 220 / height)
      ZStack(alignment: .topLeading) {
        Theme.background
        ForEach(visible) { note in
          VStack(alignment: .leading, spacing: 7) {
            Text(note.title).font(Theme.font(11)).lineLimit(2)
            VStack(alignment: .leading, spacing: 4) {
              Rectangle().frame(width: 70, height: 2)
              Rectangle().frame(width: 73, height: 2)
              Rectangle().frame(width: 45, height: 2)
            }.foregroundStyle(Theme.muted.opacity(0.3))
            Spacer(minLength: 0)
          }.padding(10).frame(width: 102, height: 94).background(
            note.colour.fill, in: RoundedRectangle(cornerRadius: 6)
          )
          .scaleEffect(scale / 0.4, anchor: .topLeading).offset(
            x: 24 + (note.x - minX) * scale, y: 12 + (note.y - minY) * scale)
        }
      }.clipShape(RoundedRectangle(cornerRadius: 14)).sprigAnimate(
        visible.map { CGPoint(x: $0.x, y: $0.y) }
      ).sprigAnimate(visible.map(\.id))
    }.frame(height: 244).accessibilityHidden(true)
  }
}
struct NoteEditor: View {
  @Bindable var store: AppStore
  @State private var commands = SourceCommands()
  let note: Note
  static func textBinding(store: AppStore, noteID: String, session: String) -> Binding<String> {
    Binding(
      get: { store.workspace.notes.first { $0.id == noteID }?.markdown ?? "" },
      set: { value in
        store.updateNote(noteID, group: "editor-\(session)") {
          $0.markdown = value
          $0.summary = ""
        }
      })
  }
  private var source: Binding<String> {
    Self.textBinding(store: store, noteID: note.id, session: store.editorSession)
  }
  private let formats: [(String, String, String, String)] = [
    ("Bold", "B", "**", "**"), ("Italic", "I", "*", "*"), ("Heading", "H", "## ", ""),
    ("Bullets", "Bullets", "\n- ", ""), ("Numbered list", "Numbered", "\n1. ", ""),
    ("Checklist", "Checklist", "\n- [ ] ", ""), ("Link", "Link", "[", "](https://example.com)"),
    ("Quote", "Quote", "\n> ", ""), ("Code", "Code", "`", "`"),
  ]
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Caption(note.category)
        Spacer()
        Button("×") { store.closeEditor() }.font(Theme.font(20, .semibold)).foregroundStyle(
          Theme.muted
        ).frame(width: 24, height: 24).keyboardShortcut(.escape, modifiers: []).accessibilityLabel(
          "Return to board")
      }.frame(height: 22)
      TextField(
        "Untitled note",
        text: Binding(
          get: { store.workspace.notes.first { $0.id == note.id }?.title ?? "" },
          set: { value in
            store.updateNote(note.id, group: "editor-\(store.editorSession)") { $0.title = value }
          })
      ).textFieldStyle(.plain).font(Theme.font(24, .bold)).accessibilityLabel("Note title")
        .onSubmit { commands.perform("focus-start") }
      MarkdownLiveEditor(text: source, commands: commands, sourceMode: store.sourceMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      HStack(spacing: 12) {
        ForEach(NoteColour.allCases, id: \.self) { c in
          Button {
            store.editNote { $0.colour = c }
          } label: {
            Circle().fill(c.fill).frame(width: 18, height: 18).overlay(
              Circle().stroke(
                Theme.accent.opacity(c == note.colour ? 0.8 : 0.1),
                lineWidth: c == note.colour ? 2 : 1))
          }.help(c.rawValue.capitalized).accessibilityLabel("Change note to \(c.rawValue)")
        }
        Spacer(minLength: 0)
        Menu {
          Button(store.sourceMode ? "Use live editing" : "Edit Markdown source") {
            store.sourceMode.toggle()
          }
          Divider()
          Button("Export Markdown") { store.exportNote(note) }
          Button("Duplicate note") { store.duplicate(note) }
          Button("Move to trash") { store.trash(note.id) }
        } label: {
          Text("···").font(Theme.font(16))
        }.menuIndicator(.hidden).menuStyle(.borderlessButton).fixedSize().accessibilityLabel(
          "Note actions")
      }.frame(height: 22)
    }
    .padding(.horizontal, 30).padding(.vertical, 24)
    .frame(width: 520, height: 520).background(
      note.colour.fill, in: RoundedRectangle(cornerRadius: 14)
    )
    .shadow(color: Color(red: 0.16, green: 0.2, blue: 0.15).opacity(0.19), radius: 19, x: 0, y: 14)
    .overlay(alignment: .topLeading) {
      VStack(spacing: 4) {
        ForEach(Array(formats.enumerated()), id: \.offset) { i, f in
          Button {
            commands.request(MarkdownFormat.allCases[i])
          } label: {
            Group {
              if i < 3 {
                Text(f.1).font(Theme.font(18, i == 1 ? .regular : .bold)).italicIf(i == 1)
              } else {
                FigmaIcon(name: f.1, group: "detail2", size: 19)
              }
            }.frame(width: 36, height: 36)
          }.buttonStyle(SprigButtonStyle()).help(f.0).accessibilityLabel(f.0)
          if i == 2 || i == 5 {
            Rectangle().fill(Theme.muted.opacity(0.2)).frame(width: 36, height: 1)
          }
        }
      }.padding(.horizontal, 10).padding(.vertical, 8).frame(width: 56, height: 382).sprigGlass(28)
        .offset(x: -72, y: 69)
    }
    .buttonStyle(SprigButtonStyle()).sprigAnimate(note.colour)
  }
}
extension View {
  @ViewBuilder fileprivate func italicIf(_ condition: Bool) -> some View {
    if condition { self.italic() } else { self }
  }
}
