import Foundation

public enum MarkdownFormat: String, CaseIterable, Sendable {
  case bold, italic, heading, bullets, numbered, checklist, link, quote, code
  public func apply(to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
    let original = text as NSString
    let safe = NSRange(
      location: min(max(0, selection.location), original.length),
      length: min(max(0, selection.length), max(0, original.length - selection.location)))
    if [.heading, .bullets, .numbered, .checklist, .quote].contains(self) {
      var range = original.lineRange(for: safe)
      // A selection ending at a line start must not format the following line.
      if safe.length > 0, NSMaxRange(safe) > 0,
        original.substring(with: NSRange(location: NSMaxRange(safe) - 1, length: 1)) == "\n"
      {
        range = original.lineRange(for: NSRange(location: safe.location, length: safe.length - 1))
      }
      let content = original.substring(with: range)
      let hasNewline = content.hasSuffix("\n")
      var lines = content.components(separatedBy: "\n")
      if hasNewline { lines.removeLast() }
      let formatted =
        lines.enumerated().map { i, line in
          let prefix: String =
            switch self {
            case .heading: "## "
            case .bullets: "- "
            case .numbered: "\(i+1). "
            case .checklist: "- [ ] "
            case .quote: "> "
            default: ""
            }
          let cleaned = line.replacingOccurrences(
            of: "^(#{1,6} |[-*] (?:\\[[ xX]\\] )?|[0-9]+\\. |> )", with: "",
            options: .regularExpression)
          return prefix + cleaned
        }.joined(separator: "\n") + (hasNewline ? "\n" : "")
      let next = original.replacingCharacters(in: range, with: formatted)
      let length = (formatted as NSString).length - (hasNewline ? 1 : 0)
      return (next, NSRange(location: range.location, length: max(0, length)))
    }
    let markers: (String, String) =
      switch self {
      case .bold: ("**", "**")
      case .italic: ("*", "*")
      case .link: ("[", "](https://example.com)")
      case .code: ("`", "`")
      default: ("", "")
      }
    let selected = original.substring(with: safe)
    let replacement = markers.0 + selected + markers.1
    return (
      original.replacingCharacters(in: safe, with: replacement),
      NSRange(location: safe.location + (markers.0 as NSString).length, length: safe.length)
    )
  }
}
