import Foundation

/// One compound as PubChem's property table describes it.
public struct Compound: Equatable, Hashable, Sendable, Codable {
    public let cid: Int
    public let title: String
    public let iupacName: String
    public let formula: String
    /// The molecular weight as PubChem prints it, for example "196.03".
    public let molecularWeight: String
    public let smiles: String

    public init(cid: Int, title: String, iupacName: String, formula: String, molecularWeight: String, smiles: String) {
        self.cid = cid
        self.title = title
        self.iupacName = iupacName
        self.formula = formula
        self.molecularWeight = molecularWeight
        self.smiles = smiles
    }

    public var weight: Double? { Double(molecularWeight) }

    /// The compound's page on pubchem.ncbi.nlm.nih.gov.
    public var pageURL: URL { URL(string: "https://pubchem.ncbi.nlm.nih.gov/compound/\(cid)")! }
}

/// A heading of a PUG View record that carries one property, with a readable label.
public struct PropertySection: Equatable, Hashable, Sendable {
    public let heading: String
    public let label: String

    public init(heading: String, label: String) {
        self.heading = heading
        self.label = label
    }

    public static let meltingPoint = PropertySection(heading: "Melting Point", label: "Melting point")
    public static let boilingPoint = PropertySection(heading: "Boiling Point", label: "Boiling point")
    public static let density = PropertySection(heading: "Density", label: "Density")
    public static let solubility = PropertySection(heading: "Solubility", label: "Solubility")
    public static let flashPoint = PropertySection(heading: "Flash Point", label: "Flash point")
    public static let vaporPressure = PropertySection(heading: "Vapor Pressure", label: "Vapor pressure")
    public static let appearance = PropertySection(heading: "Physical Description", label: "Appearance")
    public static let description = PropertySection(heading: "Record Description", label: "Description")

    /// The physical properties most callers want.
    public static let standard: [PropertySection] = [meltingPoint, boilingPoint, density, solubility, flashPoint, vaporPressure]
}

/// The text found for one section.
public struct PropertyValue: Equatable, Sendable {
    public let section: PropertySection
    public let text: String

    public init(section: PropertySection, text: String) {
        self.section = section
        self.text = text
    }
}

public struct HazardStatement: Equatable, Hashable, Sendable {
    /// `H225`, `H361fd` or a combined code such as `H301+H311+H331`.
    public let code: String
    public let text: String

    public init(code: String, text: String) {
        self.code = code
        self.text = text
    }
}

/// The GHS block of a record.
public struct Hazards: Equatable, Sendable {
    public var signalWord: String
    public var pictograms: [String]
    public var statements: [HazardStatement]

    public init(signalWord: String = "", pictograms: [String] = [], statements: [HazardStatement] = []) {
        self.signalWord = signalWord
        self.pictograms = pictograms
        self.statements = statements
    }
}

/// Everything `PubChemClient.lookup` returns for one query.
public struct LookupResult: Equatable, Sendable {
    public let compound: Compound
    /// Further matches, for a formula that fits several compounds.
    public let otherMatches: [Compound]
    public let properties: [PropertyValue]
    public let description: String?
    public let hazards: Hazards?
    public let requestedDescription: Bool
    public let requestedHazards: Bool

    public init(compound: Compound, otherMatches: [Compound] = [], properties: [PropertyValue] = [], description: String? = nil, hazards: Hazards? = nil,
                requestedDescription: Bool = false, requestedHazards: Bool = false) {
        self.compound = compound
        self.otherMatches = otherMatches
        self.properties = properties
        self.description = description
        self.hazards = hazards
        self.requestedDescription = requestedDescription
        self.requestedHazards = requestedHazards
    }
}

public enum PubChemError: Error, Equatable, Sendable {
    /// The query was empty or the URL built from it is not a PubChem API URL.
    case invalidQuery
    /// PubChem has no compound for the query.
    case notFound
    /// PubChem throttled the request (HTTP 429 or 503) even after one retry.
    case rateLimited
    /// Any other HTTP status.
    case unavailable(status: Int)
    /// The response was too large or not what the endpoint documents.
    case badResponse
    case network(String)
}
