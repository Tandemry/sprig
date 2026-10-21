import CoreGraphics

public struct RopeAttachment: Equatable, Sendable {
  public let point: CGPoint
  public let outward: CGPoint
}
public enum ConnectionGeometry {
  /// Side midpoints are pinned directly. The outward normal keeps nearby free
  /// particles outside the card without introducing a rigid lead segment.
  public static func attachments(from a: CGPoint, to b: CGPoint, size: Double = 256) -> (
    RopeAttachment, RopeAttachment
  ) {
    let ac = CGPoint(x: a.x + size / 2, y: a.y + size / 2)
    let bc = CGPoint(x: b.x + size / 2, y: b.y + size / 2)
    let horizontal = abs(bc.x - ac.x) >= abs(bc.y - ac.y)
    let direction = horizontal ? (bc.x >= ac.x ? 1.0 : -1.0) : (bc.y >= ac.y ? 1.0 : -1.0)
    let normal = CGPoint(x: horizontal ? direction : 0, y: horizontal ? 0 : direction)
    func attachment(_ centre: CGPoint, _ sign: Double) -> RopeAttachment {
      let point = CGPoint(
        x: centre.x + normal.x * sign * size / 2, y: centre.y + normal.y * sign * size / 2)
      return RopeAttachment(
        point: point,
        outward: CGPoint(x: normal.x * sign, y: normal.y * sign))
    }
    return (attachment(ac, 1), attachment(bc, -1))
  }
  public static func endpoints(from a: CGPoint, to b: CGPoint, size: Double = 256) -> (
    CGPoint, CGPoint
  ) {
    let (a, b) = attachments(from: a, to: b, size: size)
    return (a.point, b.point)
  }
}

/// A small pinned Verlet rope. Its slack adapts to endpoint distance while inertia
/// and gravity let the free particles trail moving cards and settle naturally.
public struct RopeSimulation: Sendable {
  public private(set) var points: [CGPoint]
  private var previous: [CGPoint]
  private var length: Double
  public init(start: CGPoint, end: CGPoint, segments: Int = 20, tightness: Double = 0.5) {
    let count = max(4, segments)
    let distance = hypot(end.x - start.x, end.y - start.y)
    length = Self.targetLength(distance, tightness: tightness)
    points = (0...count).map { i in
      let t = Double(i) / Double(count)
      let bow = sin(t * .pi)
      // A small lateral seed avoids a degenerate perfectly vertical chain.
      return CGPoint(
        x: start.x + (end.x - start.x) * t + bow * 16,
        y: start.y + (end.y - start.y) * t + bow * min(110, distance * 0.2 + 45))
    }
    points[0] = start
    points[count] = end
    previous = points
  }
  private static func targetLength(_ distance: Double, tightness: Double) -> Double {
    let slack = (1 - min(1, max(0, tightness))) * 2
    return distance + max(0.5, (distance * 0.12 + 90) * slack)
  }
  public mutating func advance(
    start: CGPoint, end: CGPoint, dt: Double = 1.0 / 60, startOutward: CGPoint? = nil,
    endOutward: CGPoint? = nil, tightness: Double = 0.5
  ) {
    guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite else { return }
    let delta = min(1.0 / 30, max(1.0 / 240, dt)) / 2
    let count = points.count - 1
    let target = Self.targetLength(hypot(end.x - start.x, end.y - start.y), tightness: tightness)
    length += (target - length) * 0.18
    for _ in 0..<2 {
      for i in 1..<count {
        let p = points[i]
        let dx = (p.x - previous[i].x) * 0.975
        let dy = (p.y - previous[i].y) * 0.975
        let speed = max(1, hypot(dx, dy) / 35)
        points[i] = CGPoint(x: p.x + dx / speed, y: p.y + dy / speed + 1150 * delta * delta)
        previous[i] = p
      }
      points[0] = start
      points[count] = end
      let segmentLength = length / Double(count)
      for _ in 0..<12 {
        for i in 0..<count {
          let a = points[i]
          let b = points[i + 1]
          let dx = b.x - a.x
          let dy = b.y - a.y
          let distance = max(0.0001, hypot(dx, dy))
          let correction = (distance - segmentLength) / distance
          let aWeight = i == 0 ? 0.0 : 1.0
          let bWeight = i + 1 == count ? 0.0 : 1.0
          let total = max(1, aWeight + bWeight)
          points[i].x += dx * correction * aWeight / total
          points[i].y += dy * correction * aWeight / total
          points[i + 1].x -= dx * correction * bWeight / total
          points[i + 1].y -= dy * correction * bWeight / total
        }
        points[0] = start
        points[count] = end
        // Constrain only the side of the attachment, never a fixed neck length.
        if let normal = startOutward {
          for i in 1...2 {
            let distance = (points[i].x - start.x) * normal.x + (points[i].y - start.y) * normal.y
            if distance < 0 {
              points[i].x -= distance * normal.x
              points[i].y -= distance * normal.y
            }
          }
        }
        if let normal = endOutward {
          for i in (count - 2)..<count {
            let distance = (points[i].x - end.x) * normal.x + (points[i].y - end.y) * normal.y
            if distance < 0 {
              points[i].x -= distance * normal.x
              points[i].y -= distance * normal.y
            }
          }
        }
      }
      previous[0] = start
      previous[count] = end
    }
  }
  public var motion: Double {
    zip(points, previous).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
  }
  public mutating func settle(
    start: CGPoint, end: CGPoint, startOutward: CGPoint? = nil, endOutward: CGPoint? = nil,
    tightness: Double = 0.5
  ) {
    for _ in 0..<300 {
      advance(
        start: start, end: end, startOutward: startOutward, endOutward: endOutward,
        tightness: tightness)
    }
    previous = points
  }
}
