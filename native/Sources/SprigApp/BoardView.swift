import AppKit
import SprigCore
import SwiftUI

struct BoardView: View {
  @Bindable var store: AppStore
  @GestureState private var panDrag = CGSize.zero
  @Namespace private var toolMotion
  @Namespace private var viewMotion
  @Environment(\.accessibilityReduceMotion) private var systemReduced
  private var reduced: Bool { SprigMotion.isReduced(system: systemReduced) }
  private var camera: BoardCamera { store.boardCamera }
  private func animate(_ action: () -> Void) {
    withAnimation(reduced ? nil : SprigMotion.settle, action)
  }
  var body: some View {
    GeometryReader { geo in
      let viewport = geo.size
      let scale = camera.scale(viewportWidth: geo.size.width)
      ZStack(alignment: .topLeading) {
        if store.listMode {
          list.padding(.top, 175).transition(.opacity)
        } else {
          ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle()).onTapGesture {
              store.selection = nil
              store.selectedConnectionID = nil
            }
            world(scale: scale)
              .scaleEffect(scale, anchor: .topLeading)
              .offset(
                x: camera.origin.x + store.pan.width + panDrag.width,
                y: camera.origin.y + store.pan.height + panDrag.height)
            if store.notes.isEmpty {
              VStack(spacing: 12) {
                Text("Space to think.").font(Theme.font(24, .bold))
                Text("Drag a coloured note onto your board, or click a stack.").foregroundStyle(
                  Theme.muted)
                PillButton(title: "+ Create your first note") { store.addNote(.butter) }
              }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 80).transition(
                .opacity)
            }
          }
          .frame(width: viewport.width, height: viewport.height).clipped()
          .coordinateSpace(name: "sprig-canvas")
          .simultaneousGesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .named("sprig-canvas")).updating(
              $panDrag
            ) { g, state, _ in if store.tool == .pan { state = g.translation } }.onEnded { g in
              if store.tool == .pan {
                store.pan.width += g.translation.width
                store.pan.height += g.translation.height
              }
            }
          )
          .background(
            CanvasEvents(
              enabled: store.editingID == nil && store.form == nil,
              onScroll: { event, point in
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
                {
                  zoom(
                    to: store.zoom * exp(event.scrollingDeltaY * 0.01), anchor: point,
                    width: viewport.width)
                } else {
                  store.pan.width += event.scrollingDeltaX
                  store.pan.height += event.scrollingDeltaY
                }
              },
              onMagnify: { event, point in
                zoom(
                  to: store.zoom * (1 + event.magnification), anchor: point, width: viewport.width)
              })
          )
          .transition(.opacity)
          .onAppear { store.canvasSize = viewport }.onChange(of: viewport) { _, size in
            store.canvasSize = size
          }
          VStack(spacing: 12) {
            ForEach(NoteColour.allCases, id: \.self) { colour in
              NotePileView(colour: colour, action: { store.addNote(colour) }) { point in
                guard CGRect(origin: .zero, size: viewport).contains(point) else { return }
                let world = camera.worldPoint(point, viewportWidth: viewport.width)
                store.addNote(colour, x: world.x - 128, y: world.y - 50)
              }
            }
          }
          .padding(.top, 65).padding(.trailing, 34).frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
      }
      .coordinateSpace(name: "sprig-board")
      .overlay(alignment: .bottom) {
        bottomControls(viewport: viewport).padding(.horizontal, 34).padding(.bottom, 14)
      }
      .overlay(alignment: .bottom) {
        if store.tool == .connect && !store.listMode && store.message == nil
          && store.selectedConnectionID == nil
        {
          Text(
            store.selection == nil
              ? "Choose two notes to connect them." : "Choose another note to connect."
          ).font(Theme.font(12)).foregroundStyle(Theme.accent).padding(8).background(
            Theme.background.opacity(0.9), in: Capsule()
          ).padding(.bottom, 70).transition(.opacity).allowsHitTesting(false)
        }
      }
      .overlay(alignment: .bottom) {
        if let id = store.selection, let note = store.notes.first(where: { $0.id == id }),
          store.tool == .select, store.editingID == nil
        {
          HStack(spacing: 16) {
            Button("Edit") { store.openNote(id) }
            ForEach(NoteColour.allCases, id: \.self) { colour in
              Button {
                store.updateNote(id) { $0.colour = colour }
              } label: {
                Circle().fill(colour.fill).frame(width: 18, height: 18).overlay(
                  Circle().stroke(Theme.muted.opacity(0.25)))
              }.accessibilityLabel("Change selected note to \(colour.rawValue)")
            }
            Button("Duplicate") { store.duplicate(note) }
            Button("Trash") { store.trash(id) }
          }.font(Theme.font(12)).padding(12).sprigGlass().padding(.bottom, 76).transition(
            reduced ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
      }
      .overlay(alignment: .bottom) {
        if store.tool == .connect, !store.listMode, let id = store.selectedConnectionID,
          let connection = store.workspace.connections.first(where: { $0.id == id })
        {
          HStack(spacing: 12) {
            Image(systemName: "paintpalette").foregroundStyle(Theme.muted).accessibilityHidden(true)
            ForEach(RopeColour.allCases, id: \.self) { colour in
              Button {
                store.updateConnection(id) { $0.colour = colour }
              } label: {
                Circle().fill(colour.tint).frame(width: 18, height: 18)
                  .overlay(
                    Circle().stroke(.white, lineWidth: connection.colour == colour ? 2 : 0).padding(
                      3)
                  )
                  .frame(width: 26, height: 30).contentShape(Rectangle())
              }.help(colour.rawValue.capitalized).accessibilityLabel(
                "Rope colour: \(colour.rawValue)")
            }
            Divider().frame(height: 22)
            Button {
              store.updateConnection(id) { $0.rigid.toggle() }
            } label: {
              Label(
                connection.rigid ? "Loosen" : "Rigidify",
                systemImage: connection.rigid
                  ? "point.topleft.down.to.point.bottomright.curvepath" : "line.diagonal"
              )
              .padding(.horizontal, 6).frame(height: 30).contentShape(Rectangle())
            }.accessibilityLabel(connection.rigid ? "Loosen rope" : "Rigidify rope")
            RopeTightnessControls(store: store, connection: connection)
            Button(role: .destructive) {
              store.deleteConnection(id)
            } label: {
              Image(systemName: "trash").frame(width: 30, height: 30).contentShape(Rectangle())
            }.help("Delete connection").accessibilityLabel("Delete connection")
          }.font(Theme.font(12)).padding(10).sprigGlass(26).padding(.bottom, 76)
            .transition(reduced ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
      }
      .sprigAnimate(store.selectedConnectionID)
      .sprigAnimate(store.selection).sprigAnimate(store.tool).sprigAnimate(store.listMode)
      .onChange(of: store.boardID) { _, _ in store.selection = nil }
    }
  }
  private func zoom(to value: Double, anchor: CGPoint, width: Double) {
    var next = camera
    next.zoom(to: value, anchor: anchor, viewportWidth: width)
    store.zoom = next.zoom
    store.pan = next.pan
  }
  private func world(scale: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      ForEach(store.workspace.connections) { connection in
        if let a = store.notes.first(where: { $0.id == connection.from }),
          let b = store.notes.first(where: { $0.id == connection.to })
        {
          let (start, end) = ConnectionGeometry.attachments(
            from: store.dragPositions[a.id] ?? CGPoint(x: a.x, y: a.y),
            to: store.dragPositions[b.id] ?? CGPoint(x: b.x, y: b.y))
          RopeView(
            start: start, end: end, colour: connection.colour, rigid: connection.rigid,
            tightness: connection.tightness,
            selected: store.tool == .connect && store.selectedConnectionID == connection.id
          )
          .onTapGesture { store.selectConnection(connection.id) }
          .contextMenu {
            Button("Remove connection") {
              store.deleteConnection(connection.id)
            }
          }
          .transition(.opacity).accessibilityLabel("Connection from \(a.title) to \(b.title)")
        }
      }
      ForEach(store.notes) { note in
        DraggableNote(store: store, note: note, scale: scale).transition(
          reduced ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
      }
    }.frame(width: 1470, height: 617, alignment: .topLeading)
      .sprigAnimate(store.notes.map(\.id)).sprigAnimate(store.workspace.connections.map(\.id))
  }
  private var list: some View {
    ScrollView {
      VStack(spacing: 10) {
        HStack {
          Text("\(store.notes.count) notes").font(Theme.font(16, .semibold))
          Spacer()
          PillButton(title: "+ New note") { store.addNote(.butter) }
        }.padding(.bottom, 14)
        ForEach(store.notes) { note in
          Button {
            store.openNote(note.id)
          } label: {
            HStack(spacing: 20) {
              RoundedRectangle(cornerRadius: 4).fill(note.colour.fill).frame(width: 16, height: 16)
              Text(note.title.isEmpty ? "Untitled note" : note.title).font(
                Theme.font(16, .semibold)
              ).lineLimit(1)
              Spacer()
              Caption(note.category)
              Caption("↗")
            }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 12))
          }.transition(.opacity)
        }
        if store.notes.isEmpty {
          Text("No notes yet. Create a note to get started.").foregroundStyle(Theme.muted).padding(
            30)
        }
      }.padding(.horizontal, 64).padding(.bottom, 90).sprigAnimate(store.notes.map(\.id))
    }
  }
  private func bottomControls(viewport: CGSize) -> some View {
    ZStack {
      HStack {
        HStack(spacing: 4) {
          ForEach([false, true], id: \.self) { list in
            Button {
              store.listMode = list
            } label: {
              Text(list ? "List" : "Board").frame(width: list ? 48 : 60, height: 30).background {
                if store.listMode == list {
                  Capsule().fill(Theme.colour("Selection", 0xdfead8)).matchedGeometryEffect(
                    id: "view", in: viewMotion)
                }
              }.foregroundStyle(store.listMode == list ? Theme.accent : Theme.ink)
            }
          }
          Rectangle().fill(Theme.muted.opacity(0.3)).frame(width: 1, height: 18)
          Button {
            store.undo()
          } label: {
            FigmaIcon(name: "Undo", group: "detail1", size: 18).frame(width: 30, height: 30)
          }.disabled(!store.canUndo).accessibilityLabel("Undo")
          Button {
            store.redo()
          } label: {
            FigmaIcon(name: "Redo", group: "detail1", size: 18).frame(width: 30, height: 30)
          }.disabled(!store.canRedo).accessibilityLabel("Redo")
        }.font(Theme.font(12, .medium)).padding(.horizontal, 6).padding(.vertical, 5).sprigGlass(20)
        Spacer(minLength: 0)
        if !store.listMode {
          HStack(spacing: 8) {
            Button {
              animate {
                var next = camera
                next.fit(notes: store.notes, viewport: viewport)
                store.zoom = next.zoom
                store.pan = next.pan
              }
            } label: {
              FigmaIcon(name: "Fit", group: "detail1", size: 18).frame(width: 46, height: 44)
            }.sprigGlass(22).accessibilityLabel("Fit board")
            HStack(spacing: 4) {
              Button("−") {
                animate {
                  zoom(
                    to: store.zoom / 1.15,
                    anchor: CGPoint(x: viewport.width / 2, y: viewport.height / 2),
                    width: viewport.width)
                }
              }.frame(width: 21).accessibilityLabel("Zoom out")
              Button("\(Int((store.zoom*100).rounded()))%") {
                animate {
                  store.zoom = 1
                  store.pan = .zero
                }
              }.accessibilityLabel("Reset zoom")
              Button("+") {
                animate {
                  zoom(
                    to: store.zoom * 1.15,
                    anchor: CGPoint(x: viewport.width / 2, y: viewport.height / 2),
                    width: viewport.width)
                }
              }.frame(width: 21).accessibilityLabel("Zoom in")
            }.font(Theme.font(12)).foregroundStyle(Theme.muted).padding(.horizontal, 10).frame(
              height: 35
            ).sprigGlass(20)
          }.transition(.opacity)
        }
      }
      if !store.listMode {
        HStack(spacing: 4) {
          ForEach(WorkspaceTool.allCases, id: \.self) { tool in
            Button {
              store.tool = tool
              store.selectedConnectionID = nil
              store.selection = nil
            } label: {
              HStack(spacing: 6) {
                FigmaIcon(name: tool.rawValue, group: "component3", size: 18)
                Text(tool.rawValue).font(Theme.font(12, .medium))
              }.padding(.horizontal, 8).frame(height: 32).background {
                if store.tool == tool {
                  Capsule().fill(Theme.colour("Selection", 0xdfead8)).matchedGeometryEffect(
                    id: "tool", in: toolMotion)
                }
              }.foregroundStyle(store.tool == tool ? Theme.accent : Theme.ink)
            }
          }
        }.padding(.horizontal, 6).padding(.vertical, 5).sprigGlass(22).transition(.opacity)
      }
    }.frame(height: 44)
  }
}

struct DraggableNote: View {
  @Bindable var store: AppStore
  let note: Note
  let scale: CGFloat
  @GestureState private var translation = CGSize.zero
  @Environment(\.accessibilityReduceMotion) private var systemReduced
  private var reduced: Bool { SprigMotion.isReduced(system: systemReduced) }
  var body: some View {
    StickyNoteView(
      note: note, selected: store.selection == note.id,
      doubleClick: {
        if store.tool == .select { store.openNote(note.id) }
      }
    ) {
      if store.tool == .connect {
        store.connect(note.id)
      } else if store.tool == .select {
        store.selection = note.id
      }
    }
    .gesture(
      DragGesture(minimumDistance: 4, coordinateSpace: .named("sprig-canvas")).updating(
        $translation
      ) { gesture, state, _ in if store.tool == .select { state = gesture.translation } }
      .onChanged { gesture in
        guard store.tool == .select else { return }
        store.dragPositions[note.id] = CGPoint(
          x: note.x + gesture.translation.width / scale,
          y: note.y + gesture.translation.height / scale)
      }.onEnded {
        gesture in
        defer { store.dragPositions[note.id] = nil }
        guard store.tool == .select else { return }
        store.updateNote(note.id) {
          $0.x = note.x + gesture.translation.width / scale
          $0.y = note.y + gesture.translation.height / scale
        }
      }
    )
    .onChange(of: translation == .zero) { _, ended in
      if ended { store.dragPositions[note.id] = nil }
    }
    .onDisappear { store.dragPositions[note.id] = nil }
    .scaleEffect(reduced || translation == .zero ? 1 : 1.025)
    .offset(x: note.x + translation.width / scale, y: note.y + translation.height / scale)
    .zIndex(translation != .zero ? 100 : store.selection == note.id ? 10 : 1)
    .sprigAnimate(CGPoint(x: note.x, y: note.y)).sprigAnimate(
      translation != .zero, animation: SprigMotion.quick
    )
    .contextMenu {
      Button("Edit note") { store.openNote(note.id) }
      Button("Duplicate") { store.duplicate(note) }
      Button("Export Markdown") { store.exportNote(note) }
      Button("Remove connections") {
        store.change { $0.connections.removeAll { $0.from == note.id || $0.to == note.id } }
      }.disabled(!store.workspace.connections.contains { $0.from == note.id || $0.to == note.id })
      Divider()
      Button("Move to trash") { store.trash(note.id) }
    }
  }
}
/// Observes only this canvas's events. It never takes mouse hits from notes or controls.
private struct CanvasEvents: NSViewRepresentable {
  let enabled: Bool
  let onScroll: @MainActor (NSEvent, CGPoint) -> Void
  let onMagnify: @MainActor (NSEvent, CGPoint) -> Void
  func makeNSView(context: Context) -> EventView { EventView() }
  func updateNSView(_ view: EventView, context: Context) {
    view.enabled = enabled
    view.onScroll = onScroll
    view.onMagnify = onMagnify
  }
  final class EventView: NSView {
    var enabled = false
    var onScroll: (@MainActor (NSEvent, CGPoint) -> Void)?
    var onMagnify: (@MainActor (NSEvent, CGPoint) -> Void)?
    private var monitor: Any?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
      guard window != nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) {
        [weak self] event in
        var handled = false
        MainActor.assumeIsolated {
          guard let self, self.enabled, event.window === self.window else { return }
          let point = self.convert(event.locationInWindow, from: nil)
          guard self.bounds.contains(point) else { return }
          if event.type == .magnify {
            self.onMagnify?(event, point)
          } else {
            self.onScroll?(event, point)
          }
          handled = true
        }
        return handled ? nil : event
      }
    }
    isolated deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
  }
}

private struct RopeAnchors: Equatable {
  let start: CGPoint, end: CGPoint
  let reduced: Bool, rigid: Bool
  let tightness: Double
  let startOutward: CGPoint, endOutward: CGPoint
}
private struct RopeShape: Shape {
  var points: [CGPoint]
  var straightness: Double
  var animatableData: Double {
    get { straightness }
    set { straightness = newValue }
  }
  func path(in rect: CGRect) -> Path {
    Path { path in
      guard let first = points.first, let last = points.last else { return }
      let transformed = points.enumerated().map { i, p in
        let t = Double(i) / Double(max(1, points.count - 1))
        let straight = CGPoint(
          x: first.x + (last.x - first.x) * t, y: first.y + (last.y - first.y) * t)
        return CGPoint(
          x: p.x + (straight.x - p.x) * straightness, y: p.y + (straight.y - p.y) * straightness)
      }
      path.move(to: first)
      guard transformed.count >= 2 else { return }
      // A single interpolating spline follows the simulated rope right from
      // each anchor. There is no separate straight attachment section.
      for i in 0..<transformed.count - 1 {
        let p0 = transformed[max(0, i - 1)]
        let p1 = transformed[i]
        let p2 = transformed[i + 1]
        let p3 = transformed[min(transformed.count - 1, i + 2)]
        path.addCurve(
          to: p2,
          control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
          control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
      }
    }
  }
}
private struct RopeView: View {
  let start: RopeAttachment, end: RopeAttachment
  let colour: RopeColour
  let rigid: Bool
  let tightness: Double
  let selected: Bool
  @State private var simulation: RopeSimulation?
  @Environment(\.accessibilityReduceMotion) private var systemReduced
  private var reduced: Bool { SprigMotion.isReduced(system: systemReduced) }
  private var shape: RopeShape {
    let rope =
      simulation?.points
      ?? RopeSimulation(start: start.point, end: end.point, tightness: tightness).points
    return RopeShape(points: rope, straightness: rigid ? 1 : 0)
  }
  var body: some View {
    shape.stroke(
      colour.tint.opacity(0.85),
      style: StrokeStyle(lineWidth: selected ? 4 : 2.8, lineCap: .round, lineJoin: .round)
    )
    .shadow(
      color: selected ? colour.tint.opacity(0.22) : Theme.ink.opacity(0.08),
      radius: selected ? 4 : 1, x: 0, y: 1.5
    )
    .contentShape(shape.path(in: .zero).strokedPath(.init(lineWidth: 20)))
    .sprigAnimate(rigid).sprigAnimate(colour).sprigAnimate(selected)
    .task(
      id: RopeAnchors(
        start: start.point, end: end.point, reduced: reduced, rigid: rigid, tightness: tightness,
        startOutward: start.outward, endOutward: end.outward)
    ) {
      var rope =
        simulation ?? RopeSimulation(start: start.point, end: end.point, tightness: tightness)
      if reduced || rigid {
        rope.settle(
          start: start.point, end: end.point, startOutward: start.outward, endOutward: end.outward,
          tightness: tightness)
        simulation = rope
        return
      }
      var quiet = 0
      for _ in 0..<240 {
        guard !Task.isCancelled else { return }
        rope.advance(
          start: start.point, end: end.point, startOutward: start.outward, endOutward: end.outward,
          tightness: tightness)
        simulation = rope
        quiet = rope.motion < 0.025 ? quiet + 1 : 0
        if quiet >= 20 { return }
        do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
      }
    }
  }
}

private struct RopeTightnessControls: View {
  @Bindable var store: AppStore
  let connection: Connection
  @State private var adjustmentGroup = UUID().uuidString
  @State private var lastStep = Date.distantPast
  private func adjust(_ amount: Double) {
    let now = Date()
    if now.timeIntervalSince(lastStep) > 0.8 { adjustmentGroup = UUID().uuidString }
    lastStep = now
    store.adjustConnectionTightness(
      connection.id, by: amount, group: "rope-tightness-\(adjustmentGroup)")
  }
  var body: some View {
    HStack(spacing: 3) {
      Button {
        adjust(-0.02)
      } label: {
        Image(systemName: "chevron.left").frame(width: 28, height: 30).contentShape(Rectangle())
      }.buttonRepeatBehavior(.enabled).help("Hold to loosen").accessibilityLabel(
        "Loosen rope tension"
      )
      .disabled(connection.rigid || connection.tightness <= 0)
      Text("Tighten").foregroundStyle(Theme.muted).accessibilityLabel("Rope tightness")
        .accessibilityValue("\(Int((connection.tightness * 100).rounded())) percent")
      Button {
        adjust(0.02)
      } label: {
        Image(systemName: "chevron.right").frame(width: 28, height: 30).contentShape(Rectangle())
      }.buttonRepeatBehavior(.enabled).help("Hold to tighten").accessibilityLabel(
        "Tighten rope tension"
      )
      .disabled(connection.rigid || connection.tightness >= 1)
    }.help(
      connection.rigid
        ? "Loosen the rigid line to adjust its slack" : "Hold < to loosen or > to tighten")
  }
}
