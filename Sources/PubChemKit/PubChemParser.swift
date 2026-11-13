import Foundation

/// Reads PubChem's JSON answers. Malformed input gives an empty result, never a crash.
public enum PubChemParser {
    public static func compounds(from data: Data) -> [Compound] {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let rows = (o["PropertyTable"] as? [String: Any])?["Properties"] as? [[String: Any]] else { return [] }
        return rows.compactMap { r in
            guard let cid = r["CID"] as? Int else { return nil }
            func s(_ k: String) -> String { (r[k] as? String) ?? (r[k] as? NSNumber)?.stringValue ?? "" }
            let smiles = s("SMILES").isEmpty ? s("ConnectivitySMILES") : s("SMILES")
            return Compound(cid: cid, title: s("Title"), iupacName: s("IUPACName"), formula: s("MolecularFormula"), molecularWeight: s("MolecularWeight"), smiles: smiles)
        }
    }

    public static func suggestions(from data: Data) -> [String] {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let terms = (o["dictionary_terms"] as? [String: Any])?["compound"] as? [String] else { return [] }
        return terms
    }

    /// The texts under a heading anywhere in a PUG View record, in order: the first string of each value, whitespace collapsed.
    public static func values(from data: Data, heading: String) -> [String] {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let rec = o["Record"] as? [String: Any],
              let secs = rec["Section"] as? [[String: Any]] else { return [] }
        var out: [String] = []
        func walk(_ list: [[String: Any]]) {
            for s in list {
                if (s["TOCHeading"] as? String) == heading {
                    for info in (s["Information"] as? [[String: Any]]) ?? [] {
                        let value = info["Value"] as? [String: Any]
                        if let sm = (value?["StringWithMarkup"] as? [[String: Any]])?.first, let t = sm["String"] as? String {
                            let flat = t.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                            if flat.count > 1 { out.append(flat) }
                        }
                    }
                }
                walk((s["Section"] as? [[String: Any]]) ?? [])
            }
        }
        walk(secs)
        return out
    }

    /// The first value under a heading, cut at a sentence or word end after `limit` characters.
    public static func firstValue(from data: Data, heading: String, limit: Int = 320) -> String? {
        guard let v = values(from: data, heading: heading).first else { return nil }
        return truncate(v, limit: limit)
    }

    /// The GHS block: signal word, pictogram names, and one statement per H-code with its plain text.
    /// Percentages, source tags, repeats and deleted statements are dropped.
    public static func hazards(from data: Data) -> Hazards? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let rec = o["Record"] as? [String: Any],
              let secs = rec["Section"] as? [[String: Any]] else { return nil }
        var h = Hazards()
        var raw: [String] = []
        func walk(_ list: [[String: Any]]) {
            for s in list {
                if (s["TOCHeading"] as? String) == "GHS Classification" {
                    for info in (s["Information"] as? [[String: Any]]) ?? [] {
                        let name = (info["Name"] as? String) ?? ""
                        for sm in ((info["Value"] as? [String: Any])?["StringWithMarkup"] as? [[String: Any]]) ?? [] {
                            let text = ((sm["String"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            if name == "Signal", !text.isEmpty { h.signalWord = text }
                            else if name == "GHS Hazard Statements", !text.isEmpty { raw.append(text) }
                            else if name.hasPrefix("Pictogram") {
                                for m in (sm["Markup"] as? [[String: Any]]) ?? [] {
                                    if let e = m["Extra"] as? String, !e.isEmpty, !h.pictograms.contains(e) { h.pictograms.append(e) }
                                }
                            }
                        }
                    }
                }
                walk((s["Section"] as? [[String: Any]]) ?? [])
            }
        }
        walk(secs)
        h.statements = cleanStatements(raw)
        return h.signalWord.isEmpty && h.pictograms.isEmpty && h.statements.isEmpty ? nil : h
    }

    static func cleanStatements(_ raw: [String]) -> [HazardStatement] {
        var seen: [String: String] = [:]
        for t in raw {
            guard let code = leadingCode(t) else { continue }
            var rest = String(t.dropFirst(code.count)).trimmingCharacters(in: .whitespaces)
            if rest.hasPrefix("(") { if let close = rest.firstIndex(of: ")") { rest = String(rest[rest.index(after: close)...]).trimmingCharacters(in: .whitespaces) } }
            while rest.hasPrefix("*") { rest.removeFirst() }
            rest = rest.trimmingCharacters(in: .whitespaces)
            guard rest.hasPrefix(":") else { continue }
            rest.removeFirst()
            rest = rest.trimmingCharacters(in: .whitespaces)
            if let b = rest.lastIndex(of: "["), rest.hasSuffix("]") { rest = String(rest[..<b]).trimmingCharacters(in: .whitespaces) }
            if rest.hasPrefix("(Deleted)") || rest.isEmpty { continue }
            if seen[code] == nil { seen[code] = rest }
        }
        return seen.keys.sorted().map { HazardStatement(code: $0, text: seen[$0] ?? "") }
    }

    /// `H225`, `H361fd`, `H301+H311+H331` at the start of a line.
    static func leadingCode(_ t: String) -> String? {
        var out = ""
        var rest = Substring(t)
        while true {
            guard rest.first == "H" else { return out.isEmpty ? nil : out }
            var code = "H"
            var r = rest.dropFirst()
            let digits = r.prefix(3)
            guard digits.count == 3, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return out.isEmpty ? nil : out }
            code += digits
            r = r.dropFirst(3)
            var letters = 0
            while let c = r.first, c.isASCII, c.isLetter, letters < 3 { code.append(c); r = r.dropFirst(); letters += 1 }
            out += code
            rest = r
            if rest.first == "+" { out += "+"; rest = rest.dropFirst(); continue }
            return out
        }
    }

    public static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        if let dot = head.lastIndex(where: { ".!?".contains($0) }), head.distance(from: head.startIndex, to: dot) > limit / 2 { return String(head[...dot]) }
        if let space = head.lastIndex(of: " ") { return String(head[..<space]) + " ..." }
        return head + " ..."
    }
}
