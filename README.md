# Generalized Global Governance (GGG)

GGG describes what a realm is, a community that governs itself, independently of the software
that runs it. A program that runs realms is a Governance Operating System (GOS). Anyone can write
one. GGG is what lets different GOS, wallets, hosting platforms and tools work with each other's
realms.

This repository has three parts:

| | |
|---|---|
| [`model/`](model/README.md) | **The GGG model.** What a realm is made of: its entities, the operations that change them, their lifecycles, the invariants that always hold, and the permissions that guard them. It doesn't depend on any GOS. |
| [`standards/`](standards/README.md) | **The GGG standards.** How a GOS canister on the Internet Computer is called. Each standard binds part of the model to a Candid interface, following Internet Computer conventions (ICRC-10 discovery, ICRC-3 values, ICRC-21 consent messages). |
| [`conformance/`](conformance/README.md) | **The conformance suite.** Checks that a canister implements the standards it declares, on mainnet or on a local replica. |

A GOS is GGG compliant when it lists GGG-1 in `icrc10_supported_standards` and passes the GGG-1
checks of the conformance suite. Every other standard is optional.

## Implementations

| GOS | Language | Standards |
|---|---|---|
| [Realms GOS](https://github.com/smart-social-contracts/realms-gos) | Python (Basilisk) | The model; GGG-1 and GGG-2 planned |
| [`conformance/fixture`](conformance/fixture/main.mo) | Motoko | GGG-1, GGG-2. A minimal GOS for testing the suite. |

If you write a GOS, run the suite against it and open a pull request to add it here.

## Status

Everything here is a Draft: the model, GGG-1 and GGG-2. They will change, and drafts that
implementations build against are tagged (`ggg-1-draft.1`).

The documents in [`docs/`](docs) are the 2025 concept notes. The model and the standards replace
them.

## License

MIT.
