import Foundation

/// Converts a simple subset of YAML to JSON Data so it can be decoded with JSONDecoder.
/// Supports: top-level and one-level-nested key:value pairs, string/number/bool values.
/// Hex colors must be quoted: background: "#FF0000"
enum YAMLThemeParser {
    enum ParseError: Error { case invalidStructure(String) }

    static func toJSON(_ yaml: String) throws -> Data {
        var root: [String: Any] = [:]
        var sectionKey: String? = nil
        var sectionDict: [String: Any] = [:]

        for raw in yaml.components(separatedBy: .newlines) {
            // Strip inline comments (but not inside quoted strings)
            let line = stripComment(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let colonRange = trimmed.range(of: ":") else { continue }
            let key = String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rest = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            let indent = raw.prefix(while: { $0 == " " }).count

            if rest.isEmpty {
                // Section header — flush previous section
                if let sec = sectionKey { root[sec] = sectionDict }
                sectionKey = key
                sectionDict = [:]
            } else if indent >= 2, sectionKey != nil {
                sectionDict[key] = parseValue(rest)
            } else {
                if let sec = sectionKey { root[sec] = sectionDict; sectionKey = nil; sectionDict = [:] }
                root[key] = parseValue(rest)
            }
        }
        if let sec = sectionKey { root[sec] = sectionDict }

        guard JSONSerialization.isValidJSONObject(root) else {
            throw ParseError.invalidStructure("Resulting object is not valid JSON")
        }
        return try JSONSerialization.data(withJSONObject: root)
    }

    private static func parseValue(_ s: String) -> Any {
        // Quoted string — strip quotes
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
            return String(s.dropFirst().dropLast())
        }
        if s == "true"  { return true }
        if s == "false" { return false }
        if s == "null"  { return NSNull() }
        if let i = Int(s)    { return i }
        if let f = Double(s) { return f }
        return s
    }

    /// Strip a comment from a line, leaving quoted strings intact.
    private static func stripComment(_ line: String) -> String {
        var inQuote: Character? = nil
        var idx = line.startIndex
        while idx < line.endIndex {
            let ch = line[idx]
            if let q = inQuote {
                if ch == q { inQuote = nil }
            } else if ch == "\"" || ch == "'" {
                inQuote = ch
            } else if ch == "#" {
                return String(line[..<idx])
            }
            idx = line.index(after: idx)
        }
        return line
    }
}
