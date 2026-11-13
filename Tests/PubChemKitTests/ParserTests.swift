import Testing
import Foundation
@testable import PubChemKit

// The fixtures were recorded from pubchem.ncbi.nlm.nih.gov for tetranitromethane (CID 10509), trimmed to the fields the reader uses.
@Suite struct ParserTests {
    @Test func thePropertiesOfARealAnswerAreRead() {
        let m = PubChemParser.compounds(from: fixture("props"))
        #expect(m.count == 1 && m[0].cid == 10509 && m[0].title == "Tetranitromethane" && m[0].formula == "CN4O8" && m[0].molecularWeight == "196.03")
        #expect(m[0].iupacName == "tetranitromethane" && m[0].smiles.hasPrefix("C([N+](=O)[O-])"))
        #expect(m[0].weight == 196.03)
        #expect(m[0].pageURL.absoluteString == "https://pubchem.ncbi.nlm.nih.gov/compound/10509")
    }

    @Test func badInputGivesEmptyResults() {
        #expect(PubChemParser.compounds(from: Data("{}".utf8)).isEmpty)
        #expect(PubChemParser.compounds(from: Data("nope".utf8)).isEmpty)
        #expect(PubChemParser.compounds(from: Data()).isEmpty)
        #expect(PubChemParser.hazards(from: Data("nope".utf8)) == nil)
        #expect(PubChemParser.values(from: Data(), heading: "Density").isEmpty)
        #expect(PubChemParser.suggestions(from: Data("[]".utf8)).isEmpty)
    }

    @Test func suggestionsAreRead() {
        let d = Data(#"{"status":{"code":0},"total":2,"dictionary_terms":{"compound":["tetranitromethane","tetranitroaniline"]}}"#.utf8)
        #expect(PubChemParser.suggestions(from: d) == ["tetranitromethane", "tetranitroaniline"])
    }

    @Test func aSectionValueIsReadAndCut() {
        #expect(PubChemParser.firstValue(from: fixture("melting"), heading: "Melting Point") == "57.6 °F (EPA, 1998)")
        #expect(PubChemParser.firstValue(from: fixture("density"), heading: "Density")?.hasPrefix("1.638 at 68") == true)
        #expect(PubChemParser.values(from: fixture("melting"), heading: "Boiling Point").isEmpty)
        let long = PubChemParser.firstValue(from: fixture("description"), heading: "Record Description", limit: 60)
        #expect(long != nil && long!.count <= 64)
    }

    @Test func truncationPrefersSentenceEnds() {
        #expect(PubChemParser.truncate("short", limit: 20) == "short")
        #expect(PubChemParser.truncate("One sentence here. And a second one that runs on", limit: 30) == "One sentence here.")
        #expect(PubChemParser.truncate("a long line without any sentence end at all", limit: 20).hasSuffix(" ..."))
    }

    @Test func theHazardBlockIsReadAndCleaned() throws {
        let h = try #require(PubChemParser.hazards(from: fixture("ghs")))
        #expect(h.signalWord == "Danger")
        #expect(h.pictograms == ["Oxidizer", "Acute Toxic", "Irritant", "Health Hazard"])
        let codes = h.statements.map(\.code)
        #expect(codes == ["H271", "H301", "H315", "H319", "H350"])
        #expect(h.statements.first { $0.code == "H271" }?.text == "May cause fire or explosion; strong Oxidizer")
        #expect(h.statements.first { $0.code == "H301" }?.text == "Toxic if swallowed")
    }

    @Test func hazardCodesAreFoundAtTheStartOfALine() {
        #expect(PubChemParser.leadingCode("H225 (100%): Highly Flammable") == "H225")
        #expect(PubChemParser.leadingCode("H361fd: Suspected of damaging") == "H361fd")
        #expect(PubChemParser.leadingCode("H301+H311+H331: Toxic") == "H301+H311+H331")
        #expect(PubChemParser.leadingCode("Not a code") == nil)
        #expect(PubChemParser.leadingCode("H12: short") == nil)
    }

    @Test func deletedStatementsAndRepeatsAreDropped() {
        let out = PubChemParser.cleanStatements(["H225: Flammable [Danger]", "H225 (50%): Flammable again", "H999: (Deleted)", "H300: "])
        #expect(out == [HazardStatement(code: "H225", text: "Flammable")])
    }
}
