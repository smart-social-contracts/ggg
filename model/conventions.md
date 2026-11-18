# Conventions

One part of [the GGG model](../README.md#the-model).

## 1. Conventions

These rules apply to the model's data as `ggg.did` exposes it.

| Topic | Rule |
|---|---|
| Identity | Every entity has a text `id`. Human-facing codes (`CASE-12`, `LIC-7`) are ids, not extra fields. |
| References | Relations name both ends. A reference to "any entity" names the entity type and its id: `Organization:clinic-b` in text, `record { kind; id }` in Candid. |
| Principals | Candid `principal`. A user's `id` is their principal. |
| Time | `nat64` nanoseconds since 1970-01-01 UTC, as returned by `ic0.time`. Durations are `nat64` nanoseconds too. An unset time is absent (`opt`), never `0`. People see times in the realm's own `timezone`, and local times of a quarter in the quarter's own (§10); the stored value never changes. |
| Money | `Money`, a `nat` amount in the token's smallest unit (`Token.decimals`), with the token's `symbol`, at most 9 007 199 254 740 991 (2^53 − 1). No floats. Money computed from a ratio is rounded to the nearest cent, an exact half away from zero (2.345 becomes 2.35 and −2.345 becomes −2.35); for a token with more than two decimals the result is a multiple of 10^(decimals − 2) smallest units. One rule, so every implementation rounds the same way. |
| Periods | A deadline or term in legislation is a `Period`: a `count` and a `unit`, one of `Day`, `WorkingDay`, `Month` and `Year`, never a `Duration`: three months is three months, whatever the days. The realm's own cycles (`Calendar`, the treasury's epoch) stay `Duration`s. A working day is a day that is neither a weekend day nor a holiday in the realm's calendar, taken in the realm's `timezone` (for a matter of one quarter alone, the quarter's, §10). GGG names the unit; the GOS counts it, and fails closed when its calendar has no entries for a year the count reaches. Periods compare only within one unit: comparing two units fails closed, with no conversion through the calendar. A realm whose legislation does not use working days never uses that unit. |
| Ratios | One scale for every ratio (quorum, threshold, share, weight, tax rate): `nat` hundred-millionths, so 100 % = 100 000 000, 1 % = 1 000 000 and 0.123456 % = 123 456. A `Ratio` (quorum, threshold, share, weight) is at most 100 %; a `Rate` (a tax rate, a coefficient), which legislation takes above 100 %, is at most 100 times that, 10 000 000 000. Values are stored and compared as integers, which have one form; people and chapters read and write decimals (`0.1 %`). |
| Status | One of the values listed in the entity's lifecycle. Terminal states are final. In Candid a status is a variant, and a value `in_progress` is the tag `InProgress`. |
| Structured data | Typed records where the model fixes the shape. Where it doesn't, the ICRC-3 `Value` type, never JSON encoded into text. |
| Audit | Every update operation writes one `Event`. |
| Privacy | Personal or sensitive content is stored encrypted; entities hold only a reference and a hash. Keys are shared through key envelopes ([§13](running.md#13-private-content)). |
| Collections | Every call stays within the Internet Computer's limits however large the realm grows: lists are paginated, and work over many records runs in batches. |

In the entity tables, `→ X` is a reference to an `X`, `→ X*` to several, and `(Json)` marks structured
data.

### Operations

An operation has a **name** (`proposal_vote`), a **permission** (`proposal.vote`), arguments and a
result. Several operations may share a permission. Flags:

| Flag | Meaning |
|---|---|
| `read` | Query; changes nothing; not audited. |
| `delegable` | The direct tier of power of attorney: under a grant that covers the operation's group, a delegate's call runs at once as the grantor, and both principals are audited. |
| `confirm` | Asks each time: a delegate only prepares the exact call, and it runs when the grantor approves that very call (the mechanism, pending actions, is specified with them). Never done directly under a grant. |
| `governed` | When the governing department's policy is not direct, calling it files a `Proposal` that replays the exact call once approved. The governing department is the root, unless the operation acts on a department (that department; for `department_create` and `department_delete`, the parent; for a `department_edit` that changes the `parent`, the lowest department that is, or is above, both the old and the new parent) or on a record a department owns, such as a fund, budget, tender, contract or proposal (the owner; a proposal belongs to the department it is scoped to, and a realm-wide one to the root; a contract to the executor of its mandate, else to the requester of its tender, else to the root). Identity operations name it in their `department` argument (§2). A proposal carries such a call only within its scope (I-GOV-13). |
| `signing` | Produces an act its signer is personally accountable for: a decision, a certification, a sanction. The active codex's [signing policy](running.md#signing-policy) says whether agents may hold the permission and whether it may be delegated. By default only non-agents sign, and nobody signs on another's behalf. |

[`delegation.json`](../delegation.json) gives every operation its tier and its group, and defines the
groups a grant names and the conditions under which an operation asks each time
([Power of attorney](membership.md#power-of-attorney), §2). An operation with such a condition keeps `delegable`
here, and its example says in plain words when it asks. An operation with neither flag is the member's
own (`member`: never under a grant and never prepared), the founder's (`founder`: `setup_launch`), or
needs no power of attorney (`none`: public reads, calls between canisters, the host's steps, a delegate
acting as itself).

An operation either succeeds with its result or is refused with a `GggError`, and a refused
operation changes nothing.

### Callers

A call comes from a **user** (possibly acting `on_behalf_of` a grantor), an **agent** (a user holding
an agent appointment), a **codex** (limited to its declared capabilities), or a **replayed proposal**
(realm authority, within the proposal's scope: I-GOV-13). An implementation may add callers of its
own, each limited to what it declares. Every caller is held to the same permissions and invariants;
there is no path around them.

### Candid interface

[`ggg.did`](../ggg.did) has one record per entity, with the fields of the tables below, and one
method per operation:

- **Names.** Operation `x` is method `ggg_x` (`ggg_proposal_vote`). `read` operations are queries.
  A GOS may expose other methods, but not with a `ggg` prefix.
- **References.** A reference to one entity type is that entity's id: `text`, or `principal` for a
  `User`. A reference to any entity is `record { kind; id }`.
- **Results.** A method that can refuse returns `variant { Ok : T; Err : GggError }` and doesn't trap:
  `NotFound` (a record the call needs doesn't exist; a lookup by id returns `Ok(null)` instead),
  `Unauthenticated` (anonymous caller), `Forbidden` (names the missing permission),
  `InvalidArgument`, `Conflict` (contradicts the current state), `Unavailable` (during setup or
  while frozen), `GenericError`. Messages are for people, not for parsing.
- **Governed and delegable calls.** A `governed` operation replies `Governed`: `Done` with the id of
  any record it created, or `Proposed` with the id of the proposal it filed. The proposal's action is
  the same call, `Call { method; arg }`, and replaying it applies the change. A `delegable` operation
  whose arguments carry `on_behalf_of : opt principal` is called on the grantor's behalf with it; the
  other delegable operations are reached on a grantor's behalf through `call_for` and `read_for`
  ([Pending actions](membership.md#pending-actions)). `call_for` also files a call in its `confirm` form (a `confirm`
  operation, or a `direct` one whose condition holds), an update or a read, as a pending action;
  `read_for` carries direct reads alone and refuses a `confirm` one. Such a call through its own method
  with `on_behalf_of` is `Forbidden`, and the message says to file it through `call_for`: the method's
  own reply type has no place for a pending action. A `member` operation that carries `on_behalf_of`
  refuses it: it is the member's own act.
- **Kinds.** `Ratio`, `Rate`, `Money`, `SignedMoney`, `Area`, `Timestamp`, `Duration` and `Period` are
  named aliases, so a field's unit and range can be read off `ggg.did`. [`facts.json`](../generated/facts.json)
  lists them for every operation's facts, with every fact's range
  ([layered codex §3.3](codex.md#33-the-fact-schema-units-rates-money-and-periods)).
  **Ranges are enforced:** a call with a value outside its fact's range is refused with
  `InvalidArgument`, so what the schema says about a fact holds for every request a GOS accepts.
- **Codex.** A method never returns a `Codex`. It returns that codex's checksum, `sha256:<64 hex digits>`.
  `ggg_codex_status` returns the active checksum (absent when none is installed), whether it is
  healthy, the signing policy, and a page of earlier checksums.
- **Lists.** Arguments `cursor : opt text` and `limit : opt nat32`; replies one page of the list
  (`items`, or a named field such as a proposal's `votes`) and `next : opt text`. Pages fit the
  Internet Computer's limits, are never empty when `next` is set (a list by `tags` and a `status`
  together, I-GOV-15, may be), and walk every record exactly once in a stable order. A malformed
  cursor is `InvalidArgument`.
- **Extra fields.** A GOS may add fields to the records it returns, and `opt` fields to the arguments
  it accepts, named after itself (`realms_gos_tally_required`).
- **Discovery.** `icrc10_supported_standards`
  ([ICRC-10](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md)) lists `GGG` with the
  URL of the `ggg.did` it implements (`…/ggg/blob/v0.1.0/ggg.did`), and should list
  [ICRC-21](https://github.com/dfinity/wg-identity-authentication/blob/main/topics/ICRC-21/icrc_21_consent_msg.md),
  so wallets can show what a member signs.

Every entity and operation is in `ggg.did`. The
[conformance suite](../conformance/README.md) checks a canister against it.

### Versions

GGG uses [semantic versioning](https://semver.org). The model, `ggg.did`, the conformance suite and
the [domain list](../domains.json) share one version, released as a tag of this repository (`v0.1.0`),
so the GGG version a canister lists in `icrc10_supported_standards` also names its domain list.

- **0.x:** anything may change from one minor version to the next, except the domain list, which only
  grows in every version ([the codex page §2](codex.md#2-the-domain-list-ggg1)).
- **Minor (from 1.0):** only additions that Candid subtyping accepts: new methods, new `opt`
  arguments, new fields in replies, new entities, new domains in the domain list. Callers built for
  an earlier minor keep working; a GOS claims the new minor once it implements the additions.
- **Patch:** wording and examples only; nothing an implementation or caller would notice.
- **Variants** (statuses, kinds, errors) are fixed within a major version, because Candid callers
  reject a tag they don't know.
- **Major:** any other change, except to the domain list, which only grows in every version. Its
  methods take a new prefix (`ggg2_x`) and it is listed as `GGG2`, so a canister can serve both while
  callers move.

## Running example

All examples follow one realm, **Agora**: a capital and the quarters **North** and **South**, currency
**REALM**. People: **Alice** and **Bob** (members), **Dana** (head of Civil Registry), **Carla**
(planning officer, Infrastructure), **Dr. Ana** (physician at Clinic B), **Judge Elena**, **Mallory**
(a spammer). Departments: Civil Registry, Infrastructure, Finance, Health, Justice. External
organizations: **Clinic B** (health provider) and **BuildCo** (contractor). Agents: `claude-conn`
(Alice's AI connection) and `records-bot` (Clinic B's records agent).
