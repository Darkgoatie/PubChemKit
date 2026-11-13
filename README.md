# PubChemKit

A small Swift package for looking up chemicals in [PubChem](https://pubchem.ncbi.nlm.nih.gov). Give it a name, a formula or a CAS number and get back the structure (SMILES), molecular weight, physical properties and GHS hazard statements, as typed values or as plain text.

No dependencies. Async/await. Works on iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1 and Linux.

## Install

```swift
.package(url: "https://github.com/Darkgoatie/PubChemKit.git", from: "0.1.0")
```

then add `PubChemKit` to your target's dependencies.

## Use

```swift
import PubChemKit

let client = PubChemClient(configuration: .init(userAgent: "MyApp/1.0 (https://example.com/contact)"))

// The best match for a name, a CAS number or a formula
let c = try await client.compound(matching: "tetranitromethane")
print(c.cid, c.formula, c.molecularWeight, c.smiles)

// Several matches (a formula can fit more than one compound)
let all = try await client.compounds(matching: "C9H8O4")

// Physical properties and hazards
let result = try await client.lookup("50-78-2", includeDescription: true, includeHazards: true)
print(result.properties)          // melting point, boiling point, density, ...
print(result.hazards?.signalWord) // "Danger"

// Plain text, for example as a tool answer for a language model
print(TextFormatter().render(result))
```

Errors are `PubChemError`: `.notFound`, `.invalidQuery`, `.rateLimited`, `.unavailable(status:)`, `.badResponse`, `.network(_)`.

To suggest corrections for a misspelled name:

```swift
let names = await client.suggestions(for: "aspirn")   // ["aspirin", ...]
```

### Offline names

`OfflineNames` holds about 170 common compounds in English and German with no network needed. Case, accents and punctuation are ignored.

```swift
OfflineNames.smiles(forName: "Schwefeldioxid")   // "O=S=O"
```

Each structure was drawn with RDKit, its mass checked against the formula, and its structure compared with PubChem's.

## What the client does for you

- Spaces requests to 5 per second, which is PubChem's limit. PubChem also allows 400 per minute and 30 seconds of server time per second.
- Retries once after HTTP 429 or 503, then throws `.rateLimited`.
- Keeps answers in memory for 10 minutes (200 entries). `clearCache()` empties it.
- Sends only to `https://pubchem.ncbi.nlm.nih.gov` on the compound, PUG View and autocomplete paths. Redirects are not followed.
- Cleans queries: one line, no angle brackets or control characters, at most 80 characters.
- Refuses responses over 3 MB.

All of this is set through `PubChemClient.Configuration`. Pass your own `PubChemTransport` to test without the network.

## Data and terms

PubChem is run by the US National Library of Medicine. Its data is free to use, but records that PubChem collects from other sources can carry those sources' own terms. Check [PubChem's data policy](https://pubchem.ncbi.nlm.nih.gov/docs/downloads#section=Data-Use) before you redistribute large amounts of data, and show where it came from. `Compound.pageURL` links to the source record.

Hazard text is copied from PubChem and the sources it lists. It is not safety advice.

PubChemKit is an independent project. NCBI and PubChem do not endorse it.

See [PubChem's usage policy](https://pubchem.ncbi.nlm.nih.gov/docs/programmatic-access).

## Tests

```
swift test
```

The tests use recorded PubChem answers for tetranitromethane (CID 10509) in `Tests/PubChemKitTests/Fixtures`, so they run offline.

## License

MIT, see [LICENSE](LICENSE).
