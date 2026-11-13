import Foundation

/// How a query string is read.
public enum QueryKind: Equatable, Sendable { case name, formula, cas }

/// URL building, query checks and the allow list. Pure functions, no network.
public enum PubChemAPI {
    public static let host = "pubchem.ncbi.nlm.nih.gov"
    public static let maxQueryLength = 80

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encode(_ text: String) -> String { text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "" }

    /// One line, no angle brackets or control characters, at most `maxQueryLength` characters.
    public static func clean(_ text: String) -> String {
        let flat = text.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }.joined()
        var out = flat.replacingOccurrences(of: "<", with: " ").replacingOccurrences(of: ">", with: " ")
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return String(out.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxQueryLength))
    }

    /// A CAS number is two to seven digits, two digits and a check digit, as in 50-78-2. The check digit is verified.
    public static func isCAS(_ s: String) -> Bool {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, (2...7).contains(parts[0].count), parts[1].count == 2, parts[2].count == 1,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) else { return false }
        let digits = (parts[0] + parts[1]).reversed().compactMap { $0.wholeNumberValue }
        let sum = digits.enumerated().reduce(0) { $0 + ($1.offset + 1) * $1.element }
        return sum % 10 == parts[2].first?.wholeNumberValue
    }

    private static let elementSymbols: Set<String> = [
        "H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne", "Na", "Mg",
        "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca", "Sc", "Ti", "V", "Cr",
        "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr",
        "Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd",
        "In", "Sn", "Sb", "Te", "I", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd",
        "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu", "Hf",
        "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po",
        "At", "Rn", "Fr", "Ra", "Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm",
        "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs",
        "Mt", "Ds", "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og",
    ]

    /// A formula such as C9H8O4, CH3NO2 or NaCl: real element symbols, each with an optional count, and at least one digit or two symbols.
    /// TNT and DMSO are made of capital letters too, but T and DMS are not elements, so they are names.
    public static func isFormula(_ s: String) -> Bool {
        guard !s.isEmpty, s.count <= 40, s.first?.isUppercase == true, s.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return false }
        let chars = Array(s)
        var i = 0, symbols = 0, digits = 0
        while i < chars.count {
            guard chars[i].isUppercase else { return false }
            var symbol = String(chars[i])
            i += 1
            if i < chars.count, chars[i].isLowercase {
                let two = symbol + String(chars[i])
                if elementSymbols.contains(two) { symbol = two; i += 1 } else { return false }
            }
            guard elementSymbols.contains(symbol) else { return false }
            symbols += 1
            while i < chars.count, chars[i].isNumber { digits += 1; i += 1 }
        }
        return digits > 0 || symbols > 1
    }

    public static func kind(of query: String) -> QueryKind {
        if isCAS(query) { return .cas }
        if isFormula(query) { return .formula }
        return .name
    }

    /// The property table for a name, CAS number or formula. Formulas return at most five records.
    public static func propertiesURL(for query: String) -> URL? {
        let q = clean(query)
        guard !q.isEmpty else { return nil }
        let list = "Title,IUPACName,MolecularFormula,MolecularWeight,SMILES"
        switch kind(of: q) {
        case .formula:
            return URL(string: "https://\(host)/rest/pug/compound/fastformula/\(encode(q))/property/\(list)/JSON?MaxRecords=5")
        case .cas, .name:
            return URL(string: "https://\(host)/rest/pug/compound/name/\(encode(q))/property/\(list)/JSON")
        }
    }

    /// One heading of a compound's PUG View record.
    public static func recordURL(cid: Int, heading: String) -> URL? {
        guard cid > 0 else { return nil }
        return URL(string: "https://\(host)/rest/pug_view/data/compound/\(cid)/JSON?heading=\(encode(heading).replacingOccurrences(of: "%20", with: "+"))")
    }

    public static func autocompleteURL(_ query: String, limit: Int = 5) -> URL? {
        let q = clean(query)
        guard !q.isEmpty else { return nil }
        return URL(string: "https://\(host)/rest/autocomplete/compound/\(encode(q))/json?limit=\(max(1, limit))")
    }

    /// Only PubChem over https, to the property, record and autocomplete paths, with no user name or port.
    public static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme == "https", url.host?.lowercased() == host, url.port == nil, url.user == nil, url.password == nil else { return false }
        return url.path.hasPrefix("/rest/pug/compound/") || url.path.hasPrefix("/rest/pug_view/data/compound/") || url.path.hasPrefix("/rest/autocomplete/compound/")
    }
}
