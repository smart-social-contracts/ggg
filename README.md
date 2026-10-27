# Generalized Global Governance (GGG)

GGG describes what a realm is, a community that governs itself, independently of the software
that runs it. A program that runs realms is a Governance Operating System (GOS). Anyone can write
one. GGG is what lets different GOS, wallets, hosting platforms and tools work with each other's
realms.

| | |
|---|---|
| [`model/`](model/README.md) | **The model.** What a realm is made of: entities, operations, lifecycles, invariants and permissions. |
| [`ggg.did`](ggg.did) | **The interface.** The model in Candid: a record for every entity and a method for every operation. |
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

Draft. Every entity is in `ggg.did`; the methods cover the operations bound so far. Versions that
implementations build against are tagged `ggg-draft.N`.

The documents in [`docs/`](docs) are the 2025 concept notes, replaced by the model.

## License

MIT.
