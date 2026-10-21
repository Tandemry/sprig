import CoreGraphics
import Foundation

public struct BoardCamera: Equatable, Sendable {
  public var zoom: Double
  public var pan: CGSize
  public var origin: CGPoint
  public init(zoom: Double = 1, pan: CGSize = .zero, origin: CGPoint = .zero) {
    self.zoom = zoom
    self.pan = pan
    self.origin = origin
  }
  public func scale(viewportWidth: Double) -> Double { min(1, max(1, viewportWidth) / 1470) * zoom }
  public mutating func zoom(to proposed: Double, anchor: CGPoint, viewportWidth: Double) {
    guard proposed.isFinite else { return }
    let old = scale(viewportWidth: viewportWidth)
    let next = min(4, max(0.1, proposed))
    let ratio = next / zoom
    guard old.isFinite, old > 0, next.isFinite else { return }
    pan = CGSize(
      width: anchor.x - origin.x - (anchor.x - origin.x - pan.width) * ratio,
      height: anchor.y - origin.y - (anchor.y - origin.y - pan.height) * ratio)
    zoom = next
  }
  public mutating func fit(notes: [Note], viewport: CGSize) {
    guard !notes.isEmpty else {
      self = BoardCamera(origin: origin)
      return
    }
    let minX = notes.map(\.x).min()!
    let minY = notes.map(\.y).min()!
    let maxX = notes.map { $0.x + 256 }.max()!
    let maxY = notes.map { $0.y + 256 }.max()!
    let availableWidth = max(80, viewport.width - origin.x - 190)
    let availableHeight = max(80, viewport.height - origin.y - 85)
    let desired = min(
      availableWidth / (maxX - minX + 40), availableHeight / (maxY - minY + 40), 1.5)
    zoom = desired / min(1, max(1, viewport.width) / 1470)
    pan = CGSize(width: 20 - minX * desired, height: 15 - minY * desired)
  }
  public func worldPoint(_ point: CGPoint, viewportWidth: Double) -> CGPoint {
    let scale = scale(viewportWidth: viewportWidth)
    return CGPoint(
      x: (point.x - origin.x - pan.width) / scale,
      y: (point.y - origin.y - pan.height) / scale)
  }
}
