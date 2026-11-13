import Foundation

/// Turns a `LookupResult` into plain text, for example as a tool answer for a language model.
public struct TextFormatter: Sendable {
    public var maxStatements: Int
    /// Appended after the source line. Empty by default.
    public var note: String

    public init(maxStatements: Int = 8, note: String = "") {
        self.maxStatements = maxStatements
        self.note = note
    }

    public func render(_ r: LookupResult) -> String {
        let m = r.compound
        var lines = [m.title + (m.formula.isEmpty ? "" : " (\(m.formula))")]
        if !m.iupacName.isEmpty, m.iupacName.lowercased() != m.title.lowercased() { lines.append("IUPAC name: \(m.iupacName)") }
        if !m.molecularWeight.isEmpty { lines.append("Molecular weight: \(m.molecularWeight) g/mol") }
        if !m.smiles.isEmpty { lines.append("SMILES: \(m.smiles)") }
        if r.requestedDescription {
            if let d = r.description, !d.isEmpty { lines.append("Description: \(d)") }
            else { lines.append("Description: PubChem has none for this compound.") }
        }
        for p in r.properties { lines.append("\(p.section.label): \(p.text)") }
        if r.requestedHazards {
            if let h = r.hazards {
                var head = "Hazards"
                if !h.signalWord.isEmpty { head += " (signal word \(h.signalWord))" }
                if !h.pictograms.isEmpty { head += ", pictograms: " + h.pictograms.joined(separator: ", ") }
                lines.append(head + (h.statements.isEmpty ? "" : ":"))
                for s in h.statements.prefix(maxStatements) { lines.append("  \(s.code) \(s.text)") }
                if h.statements.count > maxStatements { lines.append("  (\(h.statements.count - maxStatements) more not shown)") }
            } else {
                lines.append("Hazards: PubChem lists none for this compound.")
            }
        }
        if !r.otherMatches.isEmpty { lines.append("Other matches: " + r.otherMatches.map { "\($0.title) (\($0.formula))" }.joined(separator: "; ")) }
        lines.append("Source: \(m.pageURL.absoluteString)")
        if !note.isEmpty { lines.append(note) }
        return lines.joined(separator: "\n")
    }

    public func notFound(query: String, suggestions: [String]) -> String {
        let hint = suggestions.isEmpty ? "" : " Similar names: " + suggestions.prefix(5).joined(separator: ", ") + "."
        return "PubChem has no compound named \"\(query)\".\(hint)"
    }
}
