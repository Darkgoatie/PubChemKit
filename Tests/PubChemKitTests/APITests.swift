import Testing
import Foundation
@testable import PubChemKit

@Suite struct APITests {
    @Test func casNumbersAreRecognisedByTheirCheckDigit() {
        for ok in ["50-78-2", "64-17-5", "509-14-8", "7732-18-5", "118-96-7", "67-64-1"] { #expect(PubChemAPI.isCAS(ok), Comment(rawValue: ok)) }
        for bad in ["50-78-3", "50782", "5-78-2", "abc-de-f", "50-7-2", "12345678-12-3", "", "50-78-22"] { #expect(!PubChemAPI.isCAS(bad), Comment(rawValue: bad)) }
    }

    @Test func formulasAreToldFromWords() {
        for ok in ["C9H8O4", "CH3NO2", "H2O", "NaCl", "CN4O8", "C6H12O6", "H2SO4", "CO2", "HCl", "NaOH", "CaCl2"] { #expect(PubChemAPI.isFormula(ok), Comment(rawValue: ok)) }
        for bad in ["Water", "aspirin", "Caffeine", "TNT", "benzene", "", "C", "9H", "Tetranitromethane", "DMSO", "THC", "EDTA", "LSD", "MDMA"] { #expect(!PubChemAPI.isFormula(bad), Comment(rawValue: bad)) }
    }

    @Test func theKindOfQueryDecidesTheEndpoint() {
        #expect(PubChemAPI.kind(of: "50-78-2") == .cas)
        #expect(PubChemAPI.kind(of: "C9H8O4") == .formula)
        #expect(PubChemAPI.kind(of: "aspirin") == .name)
        #expect(PubChemAPI.propertiesURL(for: "C9H8O4")?.absoluteString.contains("fastformula/C9H8O4/property/") == true)
        #expect(PubChemAPI.propertiesURL(for: "tetranitromethane")?.absoluteString == "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/tetranitromethane/property/Title,IUPACName,MolecularFormula,MolecularWeight,SMILES/JSON")
        #expect(PubChemAPI.propertiesURL(for: "50-78-2")?.absoluteString.contains("/compound/name/50-78-2/property/") == true)
    }

    @Test func queriesAreCleanedAndEncoded() {
        #expect(PubChemAPI.clean("  2,4,6-Trinitro\ntoluene <b> ") == "2,4,6-Trinitro toluene b")
        #expect(PubChemAPI.clean(String(repeating: "a", count: 300)).count == PubChemAPI.maxQueryLength)
        #expect(PubChemAPI.propertiesURL(for: "   ") == nil)
        #expect(PubChemAPI.propertiesURL(for: "a/b?c#d")?.absoluteString.contains("name/a%2Fb%3Fc%23d/property") == true)
        #expect(PubChemAPI.recordURL(cid: 10509, heading: "Melting Point")?.absoluteString == "https://pubchem.ncbi.nlm.nih.gov/rest/pug_view/data/compound/10509/JSON?heading=Melting+Point")
        #expect(PubChemAPI.recordURL(cid: 0, heading: "Density") == nil)
    }

    @Test func everyBuiltUrlPassesTheAllowList() {
        let urls = [PubChemAPI.propertiesURL(for: "aspirin"), PubChemAPI.propertiesURL(for: "C9H8O4"), PubChemAPI.recordURL(cid: 1, heading: "GHS Classification"), PubChemAPI.autocompleteURL("tetranitro")]
        for u in urls { #expect(u != nil && PubChemAPI.isAllowed(u!), Comment(rawValue: u?.absoluteString ?? "nil")) }
    }

    @Test func otherHostsAndPathsAreRefused() {
        for u in ["http://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/x/JSON", "https://evil.com/rest/pug/compound/name/x/JSON", "https://pubchem.ncbi.nlm.nih.gov.evil.com/rest/pug/compound/x",
                  "https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest", "https://pubchem.ncbi.nlm.nih.gov:8443/rest/pug/compound/x", "https://user@pubchem.ncbi.nlm.nih.gov/rest/pug/compound/x",
                  "https://pubchem.ncbi.nlm.nih.gov/rest/pug/substance/name/x/JSON"] {
            #expect(!PubChemAPI.isAllowed(URL(string: u)!), Comment(rawValue: u))
        }
    }
}
