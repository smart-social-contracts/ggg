# Generalized Global Governance (GGG)

GGG is a standard for Governance Operating Systems (GOS).

A GOS is software that runs the governance of a city or a country so that anyone can check what it
did: government, public administration and the records they keep. The aim is to make corruption
harder to hide and cooperation easier to scale.

GGG says what a GOS does, not how it is built. It calls each place a GOS governs a **realm**: a
city, a region, a country, or any other community that governs itself.

Three goals shape it:

1. **Any implementation.** GGG says what a GOS does, never how it stores or runs it.
2. **Interoperability.** Any GGG tool works with any GGG GOS, with no adapter in between.
3. **Familiar but general.** Close enough to ordinary governance that today's institutions map onto
   it, general enough not to be tied to one country or to fix how governance may change.

## The model

The model says what a realm is made of: the **entities** it stores, the **operations** that change
them, the **lifecycles** their statuses follow, the **invariants** that always hold, and the
**permissions** operations need. It describes behaviour, not code.

| Page | What is in it |
|---|---|
| [Conventions](model/conventions.md) | How to read the tables, who may call, time and periods, versions |
| [Members, departments and organizations](model/membership.md) | Joining, identity, attributes, departments, outside bodies |
| [Governance](model/governance.md) | Proposals, votes, mandates, contracts |
| [Finance](model/finance.md) | Treasury, budgets, funds, taxes, transfers |
| [Land, licences, justice and procurement](model/services.md) | Land and NFTs, licences and requests, courts, tenders |
| [Quarters and federation](model/federation.md) | Quarters, sweeps, links between realms |
| [Running a realm](model/running.md) | Codex, notifications, tasks, audit, setup, private content |
| [Permissions, invariants and decisions](model/reference.md) | Every permission key, the rules that cross subjects, what was decided and why |

Two pages sit beside it:

| Page | What is in it |
|---|---|
| [Ontology guidelines](model/ontology.md) | How to decide what belongs in the model, and how it is written. A change is expected to survive these. |
| [Layered codex](model/codex.md) | What GGG provides so a realm can run legislation from several sources at once. |

## The rest of the repository

| | |
|---|---|
| [`ggg.did`](ggg.did) | **The interface.** The model in Candid: a record for every entity, a method for every operation. |
| [`domains.json`](domains.json) | **The domain list.** The subjects of legislation (`tax`, `water`, …) a layered codex files chapters under. |
| [`delegation.json`](delegation.json) | **Power of attorney.** Every operation's tier and group, and the plain-language groups a grant names. |
| [`generated/`](generated/README.md) | **Derived files.** Written by a command, never by hand. |
| [`conformance/`](conformance/README.md) | **The conformance suite.** Checks a canister against `ggg.did`, on mainnet or a local replica. |

## Compliance

A GOS is GGG compliant when it implements `ggg.did`, lists `GGG` in
`icrc10_supported_standards`, and passes the conformance suite.

A realm does not have to use every domain. One with a single department, or one court whose only
judge is the realm itself, is compliant — as long as what it does not use still answers as the model
says: an empty list, `NotFound`, or `Forbidden` when nobody holds the permission. That empty state is
valid.

Changes to the model come first; implementations follow. What a GOS adds beyond the model, such as
Realms GOS's extensions, stays outside GGG and is documented by that GOS.

## Implementations

| GOS | Language | |
|---|---|---|
| [Realms GOS](https://github.com/smart-social-contracts/realms-gos) | Python (Basilisk) | The reference implementation. Its tests check its operations against the model's tables, so neither can drift. |
| [`conformance/fixture`](conformance/fixture/main.mo) | Motoko | A small GOS for testing the suite itself. |

## Status

The version this tree will be released as is in [`version.txt`](version.txt). A release is a tag of
this repository, with [semantic versioning](model/conventions.md#versions): until 1.0, anything may
change. Every entity is in `ggg.did`; the methods cover the operations bound so far.

## License

MIT.
