# Generalized Global Governance (GGG)

GGG is a standard for Governance Operating Systems (GOS).

A GOS is software that transparently and verifiably runs the governance processes of a city or a country, from government to public administration, so that corruption is harder to conceal and cooperation can scale.

GGG describes the entities, processes and conventions that a GOS should implement. For example, GGG calls each place a GOS governs a **realm**: a city, a region, a country, or any other community that governs itself.

GGG aims the following goals:

1. **Implementation-agnosticism:** it says what a GOS does, not how a GOS stores or runs it.

2. **Interoperability:** any GGG-compliant GOS or tool works out-of-the-box with any GGG-compliant GOS or tool.

3. **Familiar but abstract:** close enough to traditional governance that existing institutions map onto it, yet general enough not to be tied to any one country or to limit governance evolution.


## What's in this repository


| | |
|---|---|
| [`model/`](model/README.md) | **The model.** What a realm is made of: entities, operations, lifecycles, invariants and permissions. |
| [`model/ontology.md`](model/ontology.md) | **The ontology guidelines.** How to decide what belongs in the model, and what shape it takes. |
| [`ggg.did`](ggg.did) | **The interface.** The model in Candid: a record for every entity and a method for every operation. |
| [`domains.json`](domains.json) | **The domain list.** The subjects of legislation (`tax`, `water`, …) that a layered codex has chapters for. |
| [`facts.json`](facts.json) | **The fact schema.** For every operation, the facts a codex's rules see, each with its kind, range and allowed values. Generated from `ggg.did`. |
| [`delegation.json`](delegation.json) | **Power of attorney.** Every operation's tier (direct, asks the member each time, the member's own, the founder's, none) and group, and the plain-language groups a grant names. |
| [`conformance/`](conformance/README.md) | **The conformance suite.** Checks a canister against `ggg.did`, on mainnet or on a local replica. |

A GOS is GGG compliant when it implements `ggg.did`, lists `GGG` in `icrc10_supported_standards`,
and passes the conformance suite. A realm doesn't have to use every domain: one with a single
department, or one court whose only judge is the realm itself, is compliant, as long as what it
doesn't use answers as the model says (an empty list, `NotFound`, `Forbidden`).

What a GOS adds beyond the model, such as Realms GOS's extensions, stays outside GGG.

## Implementations

| GOS | Language | |
|---|---|---|
| [Realms GOS](https://github.com/smart-social-contracts/realms-gos) | Python (Basilisk) | Implements the model; `ggg.did` planned |
| [`conformance/fixture`](conformance/fixture/main.mo) | Motoko | A minimal GOS for testing the suite |

## Status

The version this tree will be released as is in [`version.txt`](version.txt); a release is a tag of
this repository, with [semantic versioning](model/README.md#versions): until 1.0, anything may
change. Every entity is in `ggg.did`; the methods cover the operations bound so far.

[What GGG provides for a layered codex](docs/layered-codex.md) is the operations, fields and units a
GOS implements so a realm can run legislation from several sources.

## License

MIT.
