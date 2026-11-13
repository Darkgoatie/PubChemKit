import Testing
import Foundation
@testable import PubChemKit

@Suite struct FormatterAndOfflineTests {
    @Test func theTextAnswerCarriesTheStructureAndSource() async throws {
        let client = PubChemClient(configuration: fastConfiguration, transport: tetranitromethaneTransport())
        let r = try await client.lookup("tetranitromethane", includeHazards: true)
        let text = TextFormatter(maxStatements: 2, note: "Data from PubChem.").render(r)
        #expect(text.hasPrefix("Tetranitromethane (CN4O8)\n"))
        #expect(text.contains("Molecular weight: 196.03 g/mol"))
        #expect(text.contains("SMILES: C([N+](=O)[O-])"))
        #expect(text.contains("Hazards (signal word Danger)"))
        #expect(text.contains("(3 more not shown)"))
        #expect(text.contains("Source: https://pubchem.ncbi.nlm.nih.gov/compound/10509"))
        #expect(text.hasSuffix("Data from PubChem."))
    }

    @Test func missingHazardsAreStatedWhenAsked() {
        let c = Compound(cid: 1, title: "X", iupacName: "", formula: "", molecularWeight: "", smiles: "")
        let r = LookupResult(compound: c, otherMatches: [], properties: [], description: nil, hazards: nil, requestedDescription: true, requestedHazards: true)
        let text = TextFormatter().render(r)
        #expect(text.contains("Hazards: PubChem lists none for this compound."))
        #expect(text.contains("Description: PubChem has none for this compound."))
    }

    @Test func notFoundOffersSuggestions() {
        let f = TextFormatter()
        #expect(f.notFound(query: "aspirn", suggestions: ["aspirin"]) == "PubChem has no compound named \"aspirn\". Similar names: aspirin.")
        #expect(f.notFound(query: "zz", suggestions: []) == "PubChem has no compound named \"zz\".")
    }

    @Test func offlineNamesIgnoreCaseAccentsAndPunctuation() {
        #expect(OfflineNames.count >= 170)
        #expect(OfflineNames.smiles(forName: "Methane") == "C")
        #expect(OfflineNames.smiles(forName: "methan") == "C")
        #expect(OfflineNames.smiles(forName: "  SULFUR-dioxide ") == "O=S=O")
        #expect(OfflineNames.smiles(forName: "Schwefeldioxid") == "O=S=O")
        #expect(OfflineNames.smiles(forName: "not a compound") == nil)
        #expect(OfflineNames.smiles(forName: "") == nil)
    }

    @Test func everyOfflineLineHasAtLeastOneNameAndAStructure() {
        for line in OfflineNames.table.split(separator: "\n") {
            let parts = line.components(separatedBy: " = ")
            #expect(parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty, Comment(rawValue: String(line)))
        }
    }
}
