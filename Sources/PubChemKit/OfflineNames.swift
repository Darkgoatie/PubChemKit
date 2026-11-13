import Foundation

/// About 170 common compounds by name, as SMILES, English and German. Works with no network.
/// Every entry was drawn with RDKit, its mass compared with the formula and its structure compared with PubChem's.
/// Case, accents and punctuation do not matter: "Sulfur dioxide", "sulfur-dioxide" and "SULFUR DIOXIDE" are the same key.
public enum OfflineNames {
    public static func fold(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00DF}", with: "ss").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).filter { $0.isLetter || $0.isNumber }
    }

    private static func transliterated(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00E4}", with: "ae").replacingOccurrences(of: "\u{00F6}", with: "oe").replacingOccurrences(of: "\u{00FC}", with: "ue")
    }

    private static let index: [String: String] = {
        var out: [String: String] = [:]
        for line in table.split(separator: "\n") {
            guard let sep = line.range(of: " = ") else { continue }
            let smiles = String(line[sep.upperBound...]).trimmingCharacters(in: .whitespaces)
            for name in line[..<sep.lowerBound].split(separator: "|") {
                for variant in [String(name), transliterated(String(name))] {
                    let key = fold(variant)
                    if !key.isEmpty, out[key] == nil { out[key] = smiles }
                }
            }
        }
        return out
    }()

    /// The SMILES for a compound name, or nil when the name is not in the table.
    public static func smiles(forName name: String) -> String? {
        let key = fold(name.trimmingCharacters(in: .whitespacesAndNewlines))
        return key.isEmpty ? nil : index[key]
    }

    /// The number of distinct names in the table.
    public static var count: Int { index.count }

    /// The raw table: one line per compound, names separated by `|`, then ` = ` and the SMILES.
    public static let table = #"""
Methane|Methan = C
Ethane|Ethan = CC
Propane|Propan = CCC
Butane|Butan|n-Butane = CCCC
Isobutane|2-Methylpropane|Isobutan|2-Methylpropan = CC(C)C
Pentane|Pentan = CCCCC
Hexane|Hexan = CCCCCC
Heptane|Heptan = CCCCCCC
Octane|Octan = CCCCCCCC
Cyclopropane|Cyclopropan = C1CC1
Cyclobutane|Cyclobutan = C1CCC1
Cyclopentane|Cyclopentan = C1CCCC1
Cyclohexane|Cyclohexan = C1CCCCC1
Ethene|Ethylene|Ethen = C=C
Propene|Propylene|Propen = C=CC
1-Butene|But-1-ene|1-Buten = C=CCC
2-Butene|But-2-ene|2-Buten = CC=CC
1,3-Butadiene|Butadiene|Butadien|1,3-Butadien = C=CC=C
Isoprene|Isopren = C=CC(=C)C
Ethyne|Acetylene|Ethin|Acetylen = C#C
Propyne|Propin = C#CC
Benzene|Benzol = c1ccccc1
Toluene|Toluol|Methylbenzene|Methylbenzol = Cc1ccccc1
Styrene|Styrol = C=Cc1ccccc1
Naphthalene|Naphthalin = c1ccc2ccccc2c1
Anthracene|Anthracen = c1ccc2cc3ccccc3cc2c1
Phenol|Hydroxybenzene|Carbolic acid|Carbolsäure|Carbolsaeure = Oc1ccccc1
Aniline|Anilin|Aminobenzene|Aminobenzol = Nc1ccccc1
Benzoic acid|Benzoesäure|Benzoesaeure = OC(=O)c1ccccc1
Benzaldehyde|Benzaldehyd = O=Cc1ccccc1
Benzyl alcohol|Benzylalkohol = OCc1ccccc1
Nitrobenzene|Nitrobenzol = [O-][N+](=O)c1ccccc1
Chlorobenzene|Chlorbenzol|Chlorbenzen = Clc1ccccc1
Bromobenzene|Brombenzol|Brombenzen = Brc1ccccc1
Acetophenone|Acetophenon = CC(=O)c1ccccc1
Benzonitrile|Benzonitril = N#Cc1ccccc1
Salicylic acid|Salicylsäure|2-Hydroxybenzoic acid|Salicylsaeure = OC(=O)c1ccccc1O
Aspirin|Acetylsalicylic acid|Acetylsalicylsäure|ASS|Acetylsalicylsaeure = CC(=O)Oc1ccccc1C(=O)O
Paracetamol|Acetaminophen = CC(=O)Nc1ccc(O)cc1
Caffeine|Koffein|Coffein = Cn1cnc2c1c(=O)n(C)c(=O)n2C
o-Cresol|2-Methylphenol|o-Kresol = Cc1ccccc1O
Catechol|Brenzcatechin|Pyrocatechol = Oc1ccccc1O
Resorcinol|Resorcin = Oc1cccc(O)c1
Hydroquinone|Hydrochinon = Oc1ccc(O)cc1
Pyridine|Pyridin = c1ccncc1
Pyrrole|Pyrrol = c1cc[nH]c1
Furan = c1ccoc1
Thiophene|Thiophen = c1ccsc1
Imidazole|Imidazol = c1c[nH]cn1
Indole|Indol = c1ccc2[nH]ccc2c1
Pyrimidine|Pyrimidin = c1cncnc1
Vanillin = COc1cc(C=O)ccc1O
Anisole|Anisol|Methoxybenzene = COc1ccccc1
Methanol = CO
Ethanol|Ethyl alcohol|Ethylalkohol = CCO
1-Propanol|Propan-1-ol|n-Propanol|Propanol = CCCO
2-Propanol|Isopropanol|Propan-2-ol|Isopropyl alcohol = CC(C)O
1-Butanol|Butan-1-ol|n-Butanol|Butanol = CCCCO
2-Butanol|Butan-2-ol = CCC(C)O
tert-Butanol|tert-Butyl alcohol|2-Methylpropan-2-ol = CC(C)(C)O
Ethylene glycol|Ethylenglykol|Ethane-1,2-diol|Ethandiol = OCCO
Propylene glycol|Propylenglykol|Propane-1,2-diol = CC(O)CO
Glycerol|Glycerin|Propane-1,2,3-triol = OCC(O)CO
Cyclohexanol = OC1CCCCC1
Menthol = CC(C)C1CCC(C)CC1O
Diethyl ether|Diethylether|Ethoxyethane = CCOCC
Dimethyl ether|Dimethylether|Methoxymethane = COC
Tetrahydrofuran|THF = C1CCOC1
1,4-Dioxane|Dioxane|Dioxan = C1COCCO1
Ethylene oxide|Ethylenoxid|Oxirane|Oxiran = C1CO1
MTBE|Methyl tert-butyl ether = COC(C)(C)C
Formaldehyde|Formaldehyd|Methanal = C=O
Acetaldehyde|Acetaldehyd|Ethanal = CC=O
Propanal|Propionaldehyde = CCC=O
Butanal|Butyraldehyde = CCCC=O
Acetone|Aceton|Propanone|Propanon|Dimethyl ketone = CC(C)=O
Butanone|Methyl ethyl ketone|MEK = CCC(C)=O
Cyclohexanone|Cyclohexanon = O=C1CCCCC1
Acrolein = C=CC=O
Formic acid|Ameisensäure|Methanoic acid|Methansäure|Ameisensaeure|Methansaeure = OC=O
Acetic acid|Essigsäure|Ethanoic acid|Ethansäure|Essigsaeure|Ethansaeure = CC(=O)O
Propionic acid|Propansäure|Propanoic acid|Propionsäure|Propansaeure|Propionsaeure = CCC(=O)O
Butyric acid|Buttersäure|Butanoic acid|Butansäure|Buttersaeure|Butansaeure = CCCC(=O)O
Oxalic acid|Oxalsäure|Ethanedioic acid|Oxalsaeure = OC(=O)C(=O)O
Malonic acid|Malonsäure|Malonsaeure = OC(=O)CC(=O)O
Succinic acid|Bernsteinsäure|Bernsteinsaeure = OC(=O)CCC(=O)O
Lactic acid|Milchsäure|Milchsaeure = CC(O)C(=O)O
Citric acid|Zitronensäure|Citronensäure|Zitronensaeure|Citronensaeure = OC(=O)CC(O)(CC(=O)O)C(=O)O
Tartaric acid|Weinsäure|Weinsaeure = OC(C(O)C(=O)O)C(=O)O
Acrylic acid|Acrylsäure|Acrylsaeure = C=CC(=O)O
Maleic acid|Maleinsäure|Maleinsaeure = OC(=O)/C=C\C(=O)O
Fumaric acid|Fumarsäure|Fumarsaeure = OC(=O)/C=C/C(=O)O
Oleic acid|Ölsäure|Oelsaeure = CCCCCCCC/C=C\CCCCCCCC(=O)O
Stearic acid|Stearinsäure|Stearinsaeure = CCCCCCCCCCCCCCCCCC(=O)O
Palmitic acid|Palmitinsäure|Palmitinsaeure = CCCCCCCCCCCCCCCC(=O)O
Ascorbic acid|Vitamin C|Ascorbinsäure|Ascorbinsaeure = OC[C@H](O)[C@H]1OC(=O)C(O)=C1O
Pyruvic acid|Brenztraubensäure|Pyruvat|Brenztraubensaeure = CC(=O)C(=O)O
Methyl acetate|Methylacetat|Essigsäuremethylester|Essigsaeuremethylester = COC(C)=O
Ethyl acetate|Ethylacetat|Essigsäureethylester|Essigester|Essigsaeureethylester = CCOC(C)=O
Acetyl chloride|Acetylchlorid = CC(Cl)=O
Acetic anhydride|Essigsäureanhydrid|Essigsaeureanhydrid = CC(=O)OC(C)=O
Chloroform|Trichloromethane|Trichlormethan = ClC(Cl)Cl
Dichloromethane|Dichlormethan|Methylene chloride = ClCCl
Carbon tetrachloride|Tetrachlorkohlenstoff|Tetrachlormethan = ClC(Cl)(Cl)Cl
Chloromethane|Chlormethan|Methyl chloride = CCl
Chloroethane|Chlorethan|Ethyl chloride = CCCl
Vinyl chloride|Vinylchlorid = C=CCl
Methylamine|Methylamin = CN
Ethylamine|Ethylamin = CCN
Dimethylamine|Dimethylamin = CNC
Trimethylamine|Trimethylamin = CN(C)C
Diethylamine|Diethylamin = CCNCC
Triethylamine|Triethylamin = CCN(CC)CC
Urea|Harnstoff|Carbamide = NC(N)=O
Acetamide|Acetamid = CC(N)=O
Formamide|Formamid = NC=O
DMF|Dimethylformamide = CN(C)C=O
Acetonitrile|Acetonitril = CC#N
Acrylonitrile|Acrylnitril = C=CC#N
Ammonia|Ammoniak = N
Hydrazine|Hydrazin = NN
Nitromethane|Nitromethan = C[N+](=O)[O-]
DMSO|Dimethyl sulfoxide|Dimethylsulfoxid = CS(C)=O
Glycine|Glycin = NCC(=O)O
Alanine|Alanin|L-Alanine = C[C@H](N)C(=O)O
Serine|Serin = N[C@@H](CO)C(=O)O
Cysteine|Cystein = N[C@@H](CS)C(=O)O
Valine|Valin = CC(C)[C@H](N)C(=O)O
Leucine|Leucin = CC(C)C[C@H](N)C(=O)O
Isoleucine|Isoleucin = CC[C@H](C)[C@H](N)C(=O)O
Phenylalanine|Phenylalanin = N[C@@H](Cc1ccccc1)C(=O)O
Tyrosine|Tyrosin = N[C@@H](Cc1ccc(O)cc1)C(=O)O
Tryptophan = N[C@@H](Cc1c[nH]c2ccccc12)C(=O)O
Proline|Prolin = OC(=O)[C@@H]1CCCN1
Methionine = CSCC[C@H](N)C(=O)O
Aspartic acid|Asparaginsäure|Aspartat|Asparaginsaeure = N[C@@H](CC(=O)O)C(=O)O
Glutamic acid|Glutaminsäure|Glutamat|Glutaminsaeure = N[C@@H](CCC(=O)O)C(=O)O
Lysine|Lysin = NCCCC[C@H](N)C(=O)O
Arginine|Arginin = N[C@@H](CCCNC(=N)N)C(=O)O
Histidine|Histidin = N[C@@H](Cc1c[nH]cn1)C(=O)O
Threonine|Threonin = C[C@@H](O)[C@H](N)C(=O)O
Asparagine|Asparagin = N[C@@H](CC(N)=O)C(=O)O
Glutamine|Glutamin = N[C@@H](CCC(N)=O)C(=O)O
Glucose|Glukose|D-Glucose|Traubenzucker = OC[C@H]1OC(O)[C@H](O)[C@@H](O)[C@@H]1O
Fructose|Fruktose|Fruchtzucker = OCC1(O)OCC(O)C(O)C1O
Sucrose|Saccharose|Rohrzucker|Haushaltszucker = OCC1OC(OC2(CO)OC(CO)C(O)C2O)C(O)C(O)C1O
Adenine|Adenin = Nc1ncnc2[nH]cnc12
Guanine|Guanin = Nc1nc2[nH]cnc2c(=O)[nH]1
Cytosine|Cytosin = Nc1cc[nH]c(=O)n1
Thymine|Thymin = Cc1c[nH]c(=O)[nH]c1=O
Uracil = O=c1cc[nH]c(=O)[nH]1
Dopamine|Dopamin = NCCc1ccc(O)c(O)c1
Serotonin = NCCc1c[nH]c2ccc(O)cc12
Adrenaline|Epinephrine|Epinephrin = CNC[C@H](O)c1ccc(O)c(O)c1
Ibuprofen = CC(C)Cc1ccc(C(C)C(=O)O)cc1
Nicotine|Nikotin = CN1CCC[C@H]1c1cccnc1
Water|Wasser = O
Hydrogen peroxide|Wasserstoffperoxid = OO
Carbon dioxide|Kohlendioxid|Kohlenstoffdioxid = O=C=O
Carbon monoxide|Kohlenmonoxid|Kohlenstoffmonoxid = [C-]#[O+]
Hydrogen|Wasserstoff = [H][H]
Oxygen|Sauerstoff = O=O
Nitrogen|Stickstoff = N#N
Hydrogen chloride|Chlorwasserstoff|Salzsäure|Hydrochloric acid|Salzsaeure = Cl
Sulfuric acid|Schwefelsäure|Schwefelsaeure = OS(=O)(=O)O
Nitric acid|Salpetersäure|Salpetersaeure = O[N+](=O)[O-]
Phosphoric acid|Phosphorsäure|Phosphorsaeure = OP(=O)(O)O
Sodium chloride|Natriumchlorid|Kochsalz|Table salt = [Na+].[Cl-]
Sodium hydroxide|Natriumhydroxid|Natronlauge = [Na+].[OH-]
Hydrogen cyanide|Blausäure|Cyanwasserstoff|Blausaeure = C#N
Ozone|Ozon = [O-][O+]=O
Sulfur dioxide|Schwefeldioxid = O=S=O
"""#
}
