# The GGG model

**Version:** 0.1.0 (see [Versions](#versions)).

GGG (Generalized Global Governance) is the architecture a Governance Operating System (GOS) is built
for. This model says what a GGG realm is made of:

- the **entities** it stores;
- the **operations** that change them;
- the **lifecycles** their statuses follow;
- the **invariants** that must always hold;
- the **permissions** operations need.

It describes behaviour, not code, and does not depend on any implementation.

[`ggg.did`](../ggg.did) is this model in Candid: a record for every entity and a method for every
operation ([Candid interface](#candid-interface)). A GGG GOS implements all of it. It may store its
data however it likes, as long as what it shows matches this model.

The model names the entities that governments and other bodies commonly have: departments,
courts, funds, licences, tenders. A realm does not need all of them. A realm can have a single
department, or one court whose only judge is the realm itself, and still be compliant. What a
GOS may not do is leave an operation out. When a realm has nothing in a domain, its operations
still answer as the model says: an empty list, `NotFound`, or `Forbidden` when nobody holds the
permission. That empty state is valid.

[Realms GOS](https://github.com/smart-social-contracts/realms-gos) is the reference implementation of
every domain. Its tests check that its operations match the operation tables below, so neither can
drift from the other. Changes to the model come first; the implementations follow. What an
implementation adds beyond the model (Realms GOS has extensions and a task scheduler, for example)
is documented by that implementation, not here.

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
| Privacy | Personal or sensitive content is stored encrypted; entities hold only a reference and a hash. Keys are shared through key envelopes ([§13](#13-private-content)). |
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
| `governed` | When the governing department's policy is not direct, calling it files a `Proposal` that replays the exact call once approved. The governing department is the root, unless the operation acts on a department (that department; for `department_create` and `department_delete`, the parent; for a `department_edit` that changes the `parent`, the lowest department that is, or is above, both the old and the new parent) or on a record a department owns, such as a fund, budget, tender or proposal (the owner; a proposal belongs to the department it is scoped to, and a realm-wide one to the root). Identity operations name it in their `department` argument (§2). A proposal carries such a call only within its scope (I-GOV-13). |
| `signing` | Produces an act its signer is personally accountable for: a decision, a certification, a sanction. The active codex's [signing policy](#signing-policy) says whether agents may hold the permission and whether it may be delegated. By default only non-agents sign, and nobody signs on another's behalf. |

[`delegation.json`](../delegation.json) gives every operation its tier and its group, and defines the
groups a grant names and the conditions under which an operation asks each time
([Power of attorney](#power-of-attorney), §2). An operation with such a condition keeps `delegable`
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
  ([Pending actions](#pending-actions)). `call_for` also files a call in its `confirm` form (a `confirm`
  operation, or a `direct` one whose condition holds), an update or a read, as a pending action;
  `read_for` carries direct reads alone and refuses a `confirm` one. Such a call through its own method
  with `on_behalf_of` is `Forbidden`, and the message says to file it through `call_for`: the method's
  own reply type has no place for a pending action. A `member` operation that carries `on_behalf_of`
  refuses it: it is the member's own act.
- **Kinds.** `Ratio`, `Rate`, `Money`, `SignedMoney`, `Area`, `Timestamp`, `Duration` and `Period` are
  named aliases, so a field's unit and range can be read off `ggg.did`. [`facts.json`](../facts.json)
  lists them for every operation's facts, with every fact's range
  ([layered codex §3.3](../docs/layered-codex.md#33-the-fact-schema-units-rates-money-and-periods)).
  **Ranges are enforced:** a call with a value outside its fact's range is refused with
  `InvalidArgument`, so what the schema says about a fact holds for every request a GOS accepts.
- **Codex.** A method never returns a `Codex`. It returns that codex's checksum, `sha256:<64 hex digits>`.
  `ggg_codex_status` returns the active checksum (absent when none is installed), whether it is
  healthy, the signing policy, and a page of earlier checksums.
- **Lists.** Arguments `cursor : opt text` and `limit : opt nat32`; replies one page of the list
  (`items`, or a named field such as a proposal's `votes`) and `next : opt text`. Pages fit the
  Internet Computer's limits, are never empty when `next` is set, and walk every record exactly once
  in a stable order. A malformed cursor is `InvalidArgument`.
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
  grows in every version ([layered-codex §2](../docs/layered-codex.md#2-the-domain-list-ggg1)).
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

## 2. Identity and membership

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `User` | `id` (principal), `nickname`, `avatar`, `home_quarter`, `home_zone` → `Zone`, `language` (a BCP 47 tag), `profiles` → `UserProfile`*, `private_data` (encrypted) | One per principal known to this quarter. `home_zone` is a zone the realm defined, such as a district (§6): the member states it when joining, and `user_edit` changes it; a name that is no defined zone, or a member's home cell, is `InvalidArgument`. | `alice`: nickname Alice, home quarter North, home zone Riverside, language `en`, profiles `[member]` |
| `Member` | `id`, `user` → `User`, `status`, `joined_at` | Membership of a user in this quarter. | Alice: `active` since 2026-03-02 |
| `GuestUser` | `id` (principal), `home_quarter`, `permissions` (Json) | A user from another quarter acting here. | Bob from South, allowed to view and transact |
| `Human` | `id`, `user` → `User`, `date_of_birth`, `h3_index` | A verified person behind a user. At most one user per human. | Alice's verified person record: born 1990-04-12, home cell `871f1d489ffffff` |
| `Identity` | `id`, `human` → `Human`, `kind` (`national_id`, `passport`, `residence_permit`, `driver_license`, `email`, …), `category`, `issuer`, `ref`, `status`, `verified_at`, `expires_at` | An attestation. Proof material is stored encrypted or off-chain; `ref` points to it. The standard kinds are the ones named here, and a realm may add its own; `category` is a subdivision of the kind (a long-term permit); the issuer of a national id or passport is the country, so it says the nationality. | Alice's passport: kind `passport`, issuer `ES`, verified 2026-03-02, expires 2031-03-01 |
| `Attribute` | `id`, `human` → `Human`, `kind`, `value`, `issuer`, `ref`, `status`, `verified_at`, `expires_at` | A certified attribute of a person, which another body certifies and the realm verifies as it verifies identities: a disability, a family status, being a student. The kinds and values are legislation's; GGG records the attestation. `kind` and `value` are in clear, readable only by the person, by the reviewers while it awaits review and by the codex, never the audit log (I-PRV-1). | Alice's large-family title: kind `large_family`, value `general`, issued by the regional government, `verified`, expires 2028-06-30 |
| `UserProfile` | `id` (name), `description`, `allowed_to` (Json list of permissions), `permissions` → `Permission`* | A named role. Defaults: `admin` (`all`), `member`. | `member` → `[self.join, proposal.vote, proposal.create, dispute.create, …]` |
| `Permission` | `id` (name), `description`, `category`, `scope`, `users` → `User`*, `profiles` → `UserProfile`*, `departments` → `Department`* | A fine-grained grant of one permission to users, profiles or departments. | `transfer.create` on scope `fund:ROADS`, granted to Infrastructure |
| `Invite` | `id` (code hash), `profile`, `department`, `position`, `max_uses`, `uses`, `redeemed_by` (Json), `expires_at`, `revoked`, `created_by` | The code itself is never stored. | 50-use code for new clerks: profile `member`, Civil Registry, position `clerk`, expires in 30 days |
| `Delegation` | `id`, `grantor`, `delegate`, `scope` (Json), `status`, `label`, `description`, `requires_acceptance`, `granted_by`, `accepted_at`, `starts_at`, `expires_at`, `revoked_at`, `revoked_by` | Power of attorney. `scope` names groups (`group:vote`, `group:office:health`, `group:*` for everything) or, in a grant made before groups, permissions ([Power of attorney](#power-of-attorney)). | Alice → `claude-conn`: `[group:vote, group:propose]` for 30 days, `active` |
| `DelegationRequest` | `id`, `grantor`, `delegate`, `scope`, `label`, `description`, `starts_at`, `expires_at`, `request_expires_at` | A delegate asking a member for a grant, by group. Deleted once decided. | Claude asks Alice for `[group:vote]` for 30 days; the link is valid 1 h |
| `PendingAction` | `id`, `grantor` → `User`, `delegate`, `grant` → `Delegation`, `call`, `summary`, `risk`, `note`, `status`, `hash`, `filed_at`, `expires_at`, `decided_at`, `result` | A `confirm` call prepared by a delegate, waiting for the grantor's own approval ([Pending actions](#pending-actions)). `summary` and `risk` are the realm's words about the call, `note` the delegate's; `hash` seals the record; `result` is the operation's reply once it ran. | `AC-12`: Claude prepares `payment_account_add` for Alice, "Token ckBTC · Address bc1q…", `pending` until tomorrow 09:31 |

### Lifecycles

- `Member.status`: `active` ⇄ `inactive`; `active` ⇄ `suspended`; any → `banned` (terminal).
- `Identity`: `pending` → `verified` | `rejected`.
- `Attribute.status`: `pending` → `verified` | `rejected`.
- `Delegation.status`: `pending` → `active` → `revoked` | `expired`; `pending` → `declined`.
- `PendingAction.status`: an update `pending` → `approving` → `done` | `failed`; a read `pending` →
  `approved` → `done` (collected) | `expired` | `void`; either `pending` → `declined` | `withdrawn` |
  `expired` | `void`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `realm_join` (with optional invite code, language and home zone) | `self.join` | confirm | Bob joins with code `X7K-29Q` → `{user: "bob", status: "active", profiles: ["member"]}` |
| `user_get`, `user_list` | `user.view` | read, delegable | Dana looks up `bob`: nickname, status, profiles |
| `me` (own record, profiles, permissions, delegations) | `self.data_view` | read, delegable | Alice's dashboard: her profiles, permissions and the grant to Claude |
| `profile_update` (nickname, avatar, language) | `self.update_public_profile` | delegable | Claude sets Alice's avatar `{avatar: "…/alice.png", on_behalf_of: "alice"}` |
| `private_data_update` | `self.update_private_data` | confirm | Alice stores her home address, encrypted |
| `user_add`, `user_import` (bulk) | `user.add` | governed, delegable | Civil Registry imports 1,200 residents from the old register (2-of-3 approval) |
| `user_edit` | `user.edit` | delegable | Dana fixes a typo in Bob's nickname, and moves him to the district he lives in |
| `user_set_status` | `user.update_status` | governed, delegable | `{user: "mallory", status: "suspended"}` → proposal `P-9` under Civil Registry's policy |
| `user_remove` | `user.delete` | governed, delegable | Remove Bob's duplicate test account |
| `identity_submit` | `identity.submit` | confirm | Alice submits her passport proof; prepared by Claude, it waits for her approval |
| `identity_review` | `identity.review` | signing, confirm | Dana approves Alice's passport proof |
| `attribute_submit` | `attribute.submit` | confirm | Alice submits her large-family title |
| `attribute_review` | `attribute.review` | signing, confirm | Dana verifies it |
| `attribute_pending_list` (the attributes awaiting review) | `attribute.review` | read, confirm | Dana lists the attributes awaiting her review, kind and value in clear. Prepared by a delegate, it waits for Dana's approval: third parties' personal data |
| `attribute_list` (own) | `self.data_view` | read, delegable | Alice's verified attributes |
| `invite_create`, `invite_revoke` | `invite.manage` | delegable | Dana creates 50 clerk invites; revokes one sent to the wrong email. `invite_create` asks each time when the invite carries a profile beyond member, or a seat |
| `invite_list` | `invite.manage` | read, delegable | Dana checks which of her invites have been used |
| `profile_create`, `profile_edit` | `permission.grant` | governed, delegable | New profile `treasurer` → `[treasury.view, transfer.create]`; during setup each asks each time |
| `role_assign`, `role_revoke` (profile ↔ user) | `role.assign`, `role.revoke` | governed, delegable | Give Bob `treasurer` → proposal under the root department's policy; during setup `role_assign` asks each time |
| `delegation_grant`, `delegation_accept` | `self.delegate` | confirm | Alice lets Bob vote for her for 2 weeks while she travels; Bob accepts. Prepared by a delegate, each waits for the member's own approval |
| `delegation_revoke` | `self.delegate` | delegable | Alice ends Bob's grant when she is back |
| `delegation_revoke_all` (every open grant the caller gave, a page at a time) | `self.delegate` | | Alice ends every grant she gave with one call; never under a grant |
| `delegation_request` (by the delegate: any signed-in principal, e.g. an AI connection) | `self.join` | | Claude asks Alice for `[proposal.vote, proposal.create]`, 24 h |
| `delegation_request_decide` (by the grantor) | `self.delegate` | delegable | Alice approves only voting. Approving asks each time; declining is direct |
| `delegation_list`, `delegable_operations` | `self.data_view` | read, delegable | Alice's grants; the operations a permission-named grant covers: `[proposal.vote, proposal.create, …]` |
| `delegation_groups` (the groups the caller can grant, each with its operations and their tiers) | `self.data_view` | read, delegable | Alice's Authorize page: "Vote for me", "Propose for me", "See my affairs and the realm", … |
| `delegation_activity` (the events recorded under one grant, to its grantor or its delegate) | `self.data_view` | read, delegable | What `claude-conn` did under Alice's grant: two votes and a motion |
| `action_get` (one pending action, to its grantor or its delegate; anyone else gets `Ok(null)`) | `self.join` | read, delegable | Claude reads `AC-12`: `done`, with the new account's id |
| `action_list` (the caller's pending actions, as grantor or as delegate, optionally by status) | `self.join` | read, delegable | Alice's "Waiting for you": `AC-12` and `AC-13` |
| `action_approve` (by its hash), `action_decline` | `self.confirm` | | Alice approves `AC-12`: the realm adds the payout account as her own act. Never under a grant |
| `action_withdraw` (by the delegate, as itself) | `self.join` | | Claude withdraws `AC-13` to file it again with the right address |
| `action_collect` (by the delegate that prepared an approved read, once, as itself) | `self.join` | | Dana approved `AC-14`; Claude collects the attributes awaiting her review, once |
| `call_for` (one call on a grantor's behalf: a `confirm` operation files a pending action, a `direct` one runs) | `self.join` (and the carried method's, held by the grantor) | | Claude: `{method: "ggg_payment_account_add", arg: …, on_behalf_of: "alice"}` → `Pending AC-12` |
| `read_for` (one read on a grantor's behalf) | `self.join` (and the carried method's, held by the grantor) | read | Claude reads Alice's key envelopes for her |

A holder of `attribute.review` reads the attributes awaiting review with `attribute_pending_list`,
`kind` and `value` in clear, before deciding with `attribute_review` (I-PRV-1); nobody decides their
own (I-ALL-3). Its cursor continues after the last attribute returned, so deciding a page skips none.
A holder of `attribute.review` on a scope reads and decides only the attributes in it: scope
`kind:<kind>` for the kinds that body certifies (Social Services on `kind:large_family`); held without
a scope, every pending attribute of the realm. `attribute_pending_list` and `attribute_review` apply
the same scope. Once decided, an attribute is read by its person alone, with `attribute_list`. The
audit events of `attribute_submit` and `attribute_review` record the attribute's id, and for a review
the decision, never its `kind` or `value`.

Governed identity operations follow the policy of the department named in their `department`
argument (it must hold that permission through its positions or grants); otherwise the root's.

#### Power of attorney

A member lets another principal act for them with a `Delegation`: a human delegate, who accepts the
grant, or an AI connection, whose grant is active at once. Every operation has a **tier**, in
[`delegation.json`](../delegation.json), the same whoever the delegate is: `direct` operations run at
once under a grant and the grantor is told afterwards; `confirm` operations ask each time, so the
delegate only prepares the exact call and the grantor approves it; `member` operations are the
member's own, never done under a grant nor prepared; `setup_launch` is the `founder`'s; `none` needs no
power of attorney. The flags `delegable` and `confirm` ([§1](#operations)) mark the first two tiers. A
`direct` operation with a condition asks each time when the condition holds: `proposal_create` with an
action, `invite_create` with a profile beyond member or a seat, `setup_step` for the trust-policy step,
`document_store` with keys for others, `organization_edit` when it changes the
admins, `delegation_request_decide` when it approves, and, while the realm is in setup, where they would
give someone power without a vote, `appoint`, `appoint_acting`, `role_assign`, `profile_create`,
`profile_edit`, `authority_grant`, `judge_appoint`, `realm_configure_trust_policy`, `department_edit`
when it names a head and `department_set_policy` when it names veto holders.

A grant names **groups**: the 17 of `delegation.json`, each a plain-language set of operations: `see`,
`profile`, `vote`, `propose`, `filings`, `justice`, `money`, `payout`, `identity`, `keys`, `poa`,
`membership`, `office` (one entry per department where the grantor holds a seat), `sign`, `orgs` (one
per organization the grantor administers), `admin` and `setup`. An operation of the `setup` group
belongs to `admin` once the realm is launched. In `scope`, and in the arguments of `delegation_grant`,
`delegation_request` and `delegation_request_decide`, a group is `group:<id>`, an office group
`group:office:<department id>`, an organization group `group:orgs:<organization id>`, and everything
`group:*`. A grant names either groups or permission names, never both.

- **Everything** (`group:*`) covers every group, those the grantor gains later included, and every
  operation a later release adds. It lasts at most 90 days, each group's own longest duration still
  applies under it, and it never covers a `member`, `founder` or `none` operation.
- **Longest durations.** A grant of a group lasts at most the group's `longest`: one year, except
  `money` and `admin` (90 days) and `setup` (30 days, and never past Launch, I-ID-12). A grant naming
  several groups lasts at most the shortest. Nothing lasts more than one year (I-ID-6).
- **Limits are checked at use**, not only at grant: a later, stricter limit binds existing grants.
- **Signing acts** are `confirm`, in the `sign` group: the official's own approval is their signature
  (I-ALL-7), and the delegate only drafts. So is the one read in that group, `attribute_pending_list`:
  a read asks each time only when it returns third parties' personal data. The signing policy's `delegable` key
  ([§11](#signing-policy)) lets a codex make a signing permission direct instead; by default none is.
- **Setup.** While the realm is in setup, an operation of the `setup` group runs at once under a grant
  wherever the founder's own call would: most are not governed before launch, and Launch is the
  founder's review. After launch it is governed, and a delegate's call files a proposal tied to the
  grant (I-ID-10). Money (`transfer_create`, `payroll_run`) is always a proposal, and giving someone
  power without a vote asks each time.
- **Inboxes.** Under `see` a delegate reads the grantor's own inbox only. A department's or an
  organization's inbox is read only under `office:<department>` or `orgs:<organization>`.
- **Tasks.** A task scheduled or rescheduled under a grant is tied to that grant. When it runs, its
  operation must be one the grant covers directly at that moment: never a `confirm`, `member` or
  `founder` operation, and never one outside the grant's groups. The task fails once the grant is
  revoked, replaced or expired (I-EXT-5).
- **Grants made before groups.** A grant whose `scope` names permissions covers only these operations,
  with the rules that held before groups: `me`, `profile_update`, `zone_set`, `zone_clear`,
  `proposal_create` (a motion), `proposal_withdraw`, `proposal_vote`, `transfer_create` (always a
  proposal), `invoice_check`, `my_invoices`, `tax_declare`, `license_apply`, `license_renew`,
  `request_file`, `request_get`, `dispute_file`, `dispute_withdraw`, `dispute_get`, `evidence_submit`,
  `appeal_file`, `bid_submit`, `bid_withdraw`, `notification_list` and `notification_read`. Not
  `attribute_list`, delegable then too: an attribute is I-PRV-1 data, and such a grant was consented
  to for the member's own card, notifications and invoices; it is read under `see`. Under such a grant
  a proposal with an action, a payout account, an identity proof, an attribute, a quarter move and a
  federal vote stay refused: nothing widens an old grant. A new grant may still name permissions, and
  then it covers these alone.
- **The vocabulary.** `delegation_groups` returns the groups the caller can grant, each with its
  label, summary, risk and longest duration, whether some of its operations ask each time, and the
  caller's operations in it with their tiers, as `delegation.json` states them, so every GOS and
  every client show the same words. A GOS that has groups answers it; `delegable_operations` keeps
  its reply, the operations a permission-named grant covers.
- **The record.** Every delegated act's `Event` names the grant it ran under (`Event.grant`, §11),
  and `delegation_activity` pages the events of one grant, newest first, to its grantor and its
  delegate; anyone else is refused, and an unknown grant is `NotFound`. After each direct update the
  grantor is notified in the realm; reads are queries and are not audited.
- **Revoking.** `delegation_revoke` ends one grant and is direct under the `poa` group: ending a
  grant only removes power. `delegation_revoke_all` ends every open grant the caller gave, `limit` at
  a time, and replies how many it revoked and `next` until none is left; it never runs under a grant.

#### Pending actions

A call in its confirm form (a `confirm` operation, or a `direct` one whose condition holds,
[§1](#operations)) is never done directly under a grant. The delegate prepares it, and the grantor's own
approval runs it:

1. **Filing.** The delegate calls `call_for` with the method, an update or a read, its Candid-encoded
   arguments, `on_behalf_of` the grantor and an optional `note`. When the grant is active and covers the
   operation's group, the grantor acting for themselves would be allowed the call now, and fewer than
   10 actions are open between the two, the GOS stores a `PendingAction`, replies `Pending` with it and
   notifies the grantor. Otherwise the call is refused as any delegated call would be. A call in its
   direct form through `call_for` first meets every check a delegated call meets (the grant's groups and
   limits, the inbox rule, the motion rule, I-ID-10), then runs: `Done` with the method's own reply,
   Candid-encoded, or `Proposed` with the proposal a governed call filed under the grant.
2. **The record.** `call` is the exact call: the GOS decodes `arg` with the method's own argument type
   at filing, and later runs exactly that. `summary`, label and value lines, and `risk`, the sentence
   of the operation's group, are the realm's own words about the call: the delegate words neither.
   `note` is the delegate's text, shown apart. `hash` seals the record: the GOS computes it over at
   least the realm, the id, the call, the grantor, the delegate, the grant and `expires_at`, in a
   canonical form of its own, with sha256 or a stronger hash, and a client sends it back unchanged.
   `expires_at` is 24 hours after `filed_at`. Nothing in the record changes after filing: to change the
   call, the delegate withdraws the action and files another.
3. **Deciding.** The grantor approves with `action_approve { action; hash }`, which carries no
   arguments, or declines with `action_decline`; the delegate withdraws its own with `action_withdraw`.
   An approval succeeds only if the caller is the grantor, the hash equals the stored one, the status
   is `pending` and `expires_at` has not passed, and the grant is still active and still covers the
   group. The GOS then sets `approving` before it calls any other canister, runs exactly the call it
   decoded at filing, as the grantor, with every check the grantor's own call would meet now
   (permission, guardrails, parties, banned status), and stores the reply as `result`, without what the
   event log strips (a secret the operation returns, such as an invite code, is in the approval's own
   reply alone): `done`, or `failed`. A governed call goes as the grantor's own call would: at once
   where the governing department decides directly, else as the grantor's own proposal, with
   `Proposal.prepared_by` the delegate. An action left `approving` after a trap ends `failed` and is
   never retried.
   **A read is approved, then collected.** Approving a `confirm` read stores nothing: it authorises
   exactly one run, and the action is `approved`. The delegate that prepared it calls `action_collect`
   once, before `expires_at`, while the grant is still active and covers the group: the GOS runs the
   stored read as the grantor at that moment, with every check the grantor's own call would meet then,
   returns the reply, Candid-encoded with the method's own type, and marks the action `done`. A second
   call is `Conflict`; so is a call after `expires_at`, and the action reads `expired`, or after the
   grant was revoked or replaced, and the action reads `void`: nothing is collected once the grantor
   has revoked. A call by anyone else is `Forbidden`. `result` stays empty, `action_get` and
   `action_list` never carry the data, and what was decided between approval and collection is no
   longer returned (I-PRV-1).
4. **Ending otherwise.** `expired` once `expires_at` passes; `void` once its grant is revoked,
   replaced, expires or loses the group, for an `approved` read as for a `pending` action. Unlike a
   proposal filed under a grant (I-ID-10), a pending action does not outlive its grant.
5. **The audit.** The filing writes an `Event` with the operation's name, `user` the grantor, `by` the
   delegate, `grant`, and the result `{pending: id}`. The approval writes an `Event` with `user` and
   `by` both the grantor, origin `confirmed`, `prepared_by` the delegate and `grant`. A collection
   writes an `Event` with `op` the read's name, `user` the grantor, `by` and `prepared_by` the delegate,
   `grant`, and the result `{collected: id}`, never the reply (I-ALL-4).

`action_get` returns an action to its grantor or its delegate, and `Ok(null)` to anyone else;
`action_list` pages the caller's actions as grantor or as delegate, optionally by status. `read_for`
is the query twin of `call_for`: one direct read on the grantor's behalf, replying the method's own
reply, Candid-encoded; a `confirm` read through it is `Forbidden`, with a message that says to file it
through `call_for`, which files it as a pending action. Both carry only a `direct` or `confirm`
operation, and refuse a method that is not in `ggg.did`, an update through `read_for` or a direct
read through `call_for`, themselves, a `member`, `founder` or `none` operation, `on_behalf_of` equal
to the caller, and an `arg` whose own `on_behalf_of` is set and differs from the outer one
(`InvalidArgument`: there is no chaining through another grant). They are the delegate's own calls (tier `none`): the grant and the permission checked
are the grantor's, for the method they carry. A call in its confirm form through its own method with
`on_behalf_of` is `Forbidden`, with a message that says to file it through `call_for` ([§1](#operations)).

### Invariants

- I-ID-1: A user's `id` equals the principal that signs their calls; nobody can act as another user
  except through a `Delegation`.
- I-ID-2: An invite grants at most the profile, department and position it names, at most
  `max_uses` times, never after `expires_at` or `revoked`.
- I-ID-3: Nobody can assign a profile containing a permission they do not hold themselves.
- I-ID-4: A `banned` member can call nothing except read operations on public data.
- I-ID-5: Private data is readable only by its owner and by principals the owner shared it with.
- I-ID-6: A grant by groups covers an operation only if it names the operation's group (or `group:*`),
  the grantor holds the operation's permission at the time of use (for an office group, through a seat
  in the named department; for an organization group, as an admin of the named organization), and the
  group's longest duration since the grant's start has not passed. `group:*` never covers a `member`,
  `founder` or `none` operation and lasts at most 90 days. A grant by permissions covers only the operations
  listed under [Power of attorney](#power-of-attorney). No grant covers a `signing` permission the
  signing policy keeps personal or `all`, and none lasts more than one year.
- I-ID-7: A delegate acts only within `starts_at`…`expires_at` and while the grant is `active`.
- I-ID-8: Every delegated act records both the grantor and the delegate.
- I-ID-9: An identity or attribute authorizes nothing once `rejected`, or past its `expires_at`. What a
  verified one means is legislation's to say, never GGG's.
- I-ID-10: A delegate's proposal is a motion, with no action. A delegable governed call made under a
  delegation is filed as a proposal, and the GOS records the grant it was filed under. It replays
  unless that grant was revoked or replaced, even if the grant has expired since, and only if the
  grant could still make that call. A delegate never votes on a proposal it filed or prepared,
  whichever grantor it votes for: a delegate that holds grants from two members and filed or prepared
  for one votes on it for neither. Granting or accepting power of attorney, approving a request for
  it, payout accounts, identity proofs,
  attributes, moving to another quarter and federal votes are never done directly under a grant: they
  are `confirm` (outside setup, [§2](#power-of-attorney)), filed as
  [pending actions](#pending-actions).
- I-ID-11: A pending action runs at most once, only on its grantor's own approval that sends its
  hash, within 24 hours of filing, and only while the grant it was filed under is active and still
  covers its group, at approval and, for a read, at collection; its call never changes after filing.
  Neither a delegate, nor another member, nor `call_for`, a codex, a task, a replayed proposal or
  any caller an implementation adds can approve or decline it.
- I-ID-12: A setup grant ends at launch: `setup_launch` removes the `setup` group from every grant,
  and a grant left with no group ends. `setup_launch` itself is never done under a grant nor prepared.
- I-ID-13: No delegate of a member votes on a proposal that any delegate of the same member filed
  under a grant, or prepared as a pending action the member approved, whatever that grant's status
  now. The member votes on it as usual.

## 3. Departments and organizations

Two kinds of body:

- A **department** belongs to the realm. Its positions, appointments and policy are realm data and
  change only under the realm's own rules.
- An **organization** is an external party: a company, clinic, school or contractor. How it runs
  inside is its own business. The realm records its licences and its **representatives**: the people
  and agents who may act or sign for it.

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Department` | `id` (name), `description`, `kind`, `parent` → `Department`, `is_root`, `head` → `User`, `policy` (Json), `target_policy` (Json), `fund` → `Fund` | `policy` = `{m, n, quorum, veto: [principals], threshold_of}`, quorum in hundred-millionths (50 % = 50 000 000); `n` is what a proposal's threshold is measured against, not the seats filled: Civil Registry decides 2 of 3 though it seats seven (I-GOV-3). `threshold_of` `cast` makes the department decide by a majority of the votes cast instead, the usual rule of a council or a parliament, with its quorum of n and its `head` as chair, whose casting vote decides a tie in a second vote; `m` is then not used. Absent, or `eligible`, it decides m of n. Exactly one root department per realm. `kind` says what the body is (the realm's plenary, a committee), so legislation from another source can address a kind without naming a department. | Civil Registry: under Administration, 2-of-3 policy, head `dana`; the Council: kind `plenary`, a majority of the votes cast of its 33 seats with a third of them voting, chaired by its head |
| `Organization` | `id` (name), `description`, `status`, `admins` → `User`* | An external party. Its admins manage its representatives. | Clinic B: `active`, admin `dr-ana` |
| `Position` | `id` (key), `department` → `Department` or `organization` → `Organization`, `title`, `profile` → `UserProfile`, `headcount`, `salary` (int), `salary_period`, `status`, `inherit_from_capital` | A seat in a department, or a representative seat in an organization. | `civil-registry.clerk`: 4 seats, 2,000 REALM/month, profile `clerk`; `clinic-b.physician`: 3 seats |
| `Appointment` | `id`, `position` → `Position`, `user` → `User`, `kind` (`substantive`, `acting`), `agent` (bool), `supervisor` → `User`, `started_at`, `ended_at`, `status`, `source_quarter` | One user holding one seat. Agents are users with `agent = true`. | Bob holds a clerk seat since 2026-05-01; `records-bot` holds `records_agent` at Clinic B, agent, supervisor `dr-ana` |
| `Authority` | `id`, `grantor` → `Department`, `target` (department or quarter ref), `operations` (Json) | One department's powers over another. | Finance lets Infrastructure use `[transfer.create]` on the `ROADS` fund |

### Lifecycles

- `Position.status`: `open` ⇄ `frozen`; `open` | `frozen` → `closed`.
- `Appointment.status`: `active` → `ended`.
- `Organization.status`: `active` ⇄ `suspended`; `active` | `suspended` → `dissolved`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `department_create` | `org.create` | governed, delegable | Create department Health under the root → proposal `P-12` |
| `department_edit`, `department_delete` | `org.set_policy` | governed, delegable | Move Roads under Infrastructure; make `dana` head of Civil Registry; mark the Council as the `plenary`. During setup `department_edit` asks each time when it names a head |
| `department_set_policy` | `org.set_policy` | governed, delegable | Infrastructure goes from 1-of-1 to 2-of-3 with 50% quorum; the Council decides by a majority of the votes cast. During setup it asks each time when the policy names veto holders |
| `department_get`, `department_list`, `department_chart` | `realm.data_view` | read, delegable | Civil Registry's chart: 3 positions, 7 of 9 seats filled |
| `position_create`, `position_edit`, `position_close` | `org.manage_members` | governed, delegable | Open 2 `inspector` seats in Infrastructure at 2,400 REALM/month |
| `appoint`, `appoint_acting`, `appointment_end` | `org.appoint` | governed, delegable | Appoint Carla planning officer; Bob acts as head while Dana is on leave. During setup an appointment asks each time |
| `department_expel` | `org.expel` | governed, delegable | Expel a member from Infrastructure after a misconduct verdict |
| `authority_grant`, `authority_revoke` | `org.grant_authority`, `org.revoke_authority` | governed, delegable | Finance grants Infrastructure spending on `ROADS`; during setup `authority_grant` asks each time |
| `organization_register` | `organization.add` | delegable | Dr. Ana registers Clinic B and becomes its admin |
| `organization_edit` | `organization.edit` (its admins) | delegable | Clinic B updates its description and adds an admin; asks each time when it changes the admins |
| `representative_add` | `organization.edit` (its admins) | confirm | Clinic B adds `records-bot` as an agent supervised by Dr. Ana; prepared by a delegate, it waits for an admin's approval |
| `representative_remove` | `organization.edit` (its admins) | delegable | Clinic B removes a physician who left |
| `organization_set_status` | `organization.delete` | governed, delegable | Suspend BuildCo while it is investigated for fraud |
| `organization_get`, `organization_list` | `realm.data_view` | read, delegable | Licensed health providers in North |

A department is a delegation from its parent, which decides whether it exists: `department_create` and
`department_delete` are governed by the parent, the root for a top-level department (§1); the root is
never deleted (I-ORG-6, `InvalidArgument`), nor a department that owns a fund (`Conflict`), so no fund
is left without an owner. The department itself governs its edits, except a change of `parent`, which
the lowest department that is, or is above, both the old and the new parent governs: a department
cannot leave its parent by its own vote, and a parent alone cannot move it under a department it does
not govern. Moving Roads from Infrastructure to Finance is the root's to decide; moving it under a
sub-department of Infrastructure, Infrastructure's. A new parent that does not exist is `NotFound`.

### Invariants

- I-ORG-1: A user holds a department's permissions only through an active appointment in it (or
  through an `Authority` granted to a department they hold an appointment in).
- I-ORG-2: Active appointments of a position never exceed its `headcount`.
- I-ORG-3: An agent appointment has a supervisor who holds an active, non-agent appointment in the
  same department or organization, unless the signing policy makes supervision optional.
- I-ORG-4: An agent holds a `signing` permission only if the active codex's signing policy allows
  agents to hold it.
- I-ORG-5: A policy satisfies `1 ≤ m ≤ n`; veto principals hold an appointment in the department.
- I-ORG-6: The root department always exists and cannot be deleted.
- I-ORG-7: A department's positions and policy change only under the realm's rules; an organization's
  representatives are managed only by its admins.
- I-ORG-8: Nobody can act for a suspended or dissolved organization.

## 4. Governance

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Proposal` | `id`, `title`, `description`, `proposer` → `User`, `on_behalf_of`, `prepared_by` (the delegate, when the proposer approved it from a pending action, §2), `department` → `Department` (scope; root = realm-wide), `kind`, `matter`, `action` (nothing for a motion; one operation call with its arguments; or codex code ref + checksum), `status`, `opens_at`, `deadline`, `effective_at`, `threshold`, `quorum` (both in hundred-millionths), `threshold_of` (`cast` or `eligible`), `casting_vote` → `User`, `majority_of_cast`, `tally` (Json), `first_vote` (Json), `result` (Json), `links` | `kind` and `matter` say what the proposal is (a change of legislation, a budget) and what it decides, in the realm's own words, for legislation to read. `threshold`, `quorum`, `threshold_of`, `casting_vote` and `majority_of_cast` are the rule that decides it (I-GOV-3), fixed when the vote opens; the casting vote is the scope's, the realm's for a realm-wide proposal or the head of a department that counts the votes cast, never the proposer's. `first_vote` is the count of a first vote that tied, when a second one followed (I-GOV-14). A link is `replaces` or `relates to` another proposal, fixed at creation. `links` is optional in `proposal_create`: absent means none. | `P-7` Bike lane on Main St, scope Infrastructure, action `transfer_create` 50,000 REALM to BuildCo, `voting` until 8 Nov, threshold 2/3 of Infrastructure's 3 policy seats |
| `Vote` | `id`, `proposal` → `Proposal`, `voter` → `User`, `cast_by`, `choice` (`yes`, `no`, `abstain`), `cast_at` | One per voter per proposal; may be replaced until the vote ends. A second vote (I-GOV-14) starts with none: the first vote's are in the audit log. | Alice votes `yes` on `P-7`, cast by `claude-conn` |
| `Mandate` | `id`, `title`, `scope` (Json), `max_value`, `symbol`, `executor` → `Department`, `proposal` → `Proposal`, `status`, `expires_at` | An authorization to act, granted by governance. Contracts under it are worth at most `max_value` in `symbol`, when set. | Infrastructure may contract road works up to 200,000 REALM until 2027-06-30 (from `P-4`) |
| `Contract` | `id`, `title`, `parties` (Json list of `Entity:id`), `mandate` → `Mandate`, `kind`, `procedure`, `tender` → `Tender`, `value`, `symbol`, `terms_ref`, `terms_hash`, `status`, `starts_at`, `ends_at` | Agreement between parties, possibly under a mandate. `value` is what the realm commits, in `symbol`. `kind` (works, supplies, services) and `procedure` are the realm's words; a contract made from a tender names it and takes its kind and procedure. | `C-9`: Agora × BuildCo, bike lane works, 50,000 REALM, Dec–Mar, from tender `T-5`, terms `sha256:4be1…` |

### Lifecycles

- `Proposal.status`: `draft` → `voting` → `accepted` | `rejected` | `expired`; `accepted` →
  `executed` | `failed`; `draft` | `voting` → `withdrawn`. A proposal with an action that is accepted
  with an `effective_at` still ahead goes straight on to `execution_scheduled`, then `executed` |
  `failed` | `withdrawn`. A motion has nothing to execute, so it stays `accepted`. A department's
  first vote that ties under a majority of the votes cast leaves the proposal `voting`, for a second
  vote (I-GOV-14). A GOS that runs
  the action itself takes a proposal with an action from `voting` straight to `executed` or `failed`
  (I-GOV-12).
- `Mandate.status`: `active` → `completed` | `revoked` | `expired`.
- `Contract.status`: `draft` → `active` → `fulfilled` | `terminated` | `disputed`; `disputed` →
  `active` | `terminated`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `proposal_create` | `proposal.create` | delegable | `{title: "Bike lane on Main St", department: "infrastructure", action: {…}}` → `P-7`. Under a grant a motion is direct; a proposal that carries an action asks each time |
| `proposal_withdraw` | `proposal.create` (own) | delegable | Bob withdraws his draft `P-8` |
| `proposal_vote` | `proposal.vote` | delegable | `{proposal: "P-7", choice: "yes", on_behalf_of: "alice"}` → `V-31` |
| `proposal_open`, `proposal_finalize`, `proposal_execute` | `proposal.manage` | delegable | After the deadline: 412 yes, 120 no, quorum met → `accepted`; execute pays BuildCo. The Council's 15 yes, 15 no and 3 abstentions are a tie: finalizing opens its second vote |
| `proposal_stop` | `proposal.manage` | governed, delegable | `P-12`, scoped to Infrastructure, is scheduled for 1 Dec; under Infrastructure's policy a vote (`P-15`) calls `proposal_stop` on it and it ends `withdrawn` |
| `proposal_get`, `proposal_list` | `realm.data_view` | read, delegable | Open proposals in quarter North |
| `proposal_linked_from` | `realm.data_view` | read, delegable | The proposals that link to `P-7`: `P-9` replaces it, `P-11` and `P-12` relate to it |
| `mandate_create`, `mandate_revoke` | `mandate.create` | governed, delegable | Grant Infrastructure the road-works mandate (via `P-4`) |
| `mandate_assign_executor` | `mandate.assign_executor` | governed, delegable | Make Infrastructure the mandate's executor |
| `contract_create` | `contract.create_under_mandate` | confirm | Sign `C-9` with BuildCo under the road-works mandate. Prepared by a delegate, it waits for the member's approval: it binds the realm to an outside party at once |
| `contract_terminate` | `contract.terminate` | signing, confirm | End `C-9` after BuildCo misses two milestones (court order) |
| `governance_update` (the realm's voting window, threshold, quorum and casting vote) | `governance.update` | governed, delegable | Voting window from 7 to 5 days; Dana's vote decides ties |

### Invariants

- I-GOV-1: A replayed proposal executes exactly the `action` that was voted on, and only once.
- I-GOV-2: Votes count only from users eligible for the proposal's scope when they vote.
- I-GOV-3: A proposal is accepted only if its quorum and threshold are met when its vote ends. Its rule,
  `threshold`, `quorum`, `threshold_of`, `casting_vote` and `majority_of_cast`, states the one that
  decides it, and that rule is applied; it is fixed when the vote opens, together with `tally.eligible`
  and `tally.seats`: at creation for a proposal filed open, at `proposal_open` for a draft, which then
  takes, for each of threshold, quorum and basis, the stricter of the rule it stated and the scope's
  default of that moment, never a weaker one, and the scope's casting vote and `majority_of_cast` of
  that moment; after that it never moves, like the action. One comparison per scope and policy:
  - A **realm-wide** proposal takes the realm's `voting_threshold` and `voting_quorum`, over the votes
    `cast`: it is accepted when the votes cast reach the quorum of the eligible voters and the yes votes
    *exceed* `threshold` of the yes and no votes. Over the `eligible` voters, the yes votes must exceed
    `threshold` of them all, so 50 % over the eligible is more than half of the members.
  - A **department's** proposal under an **m-of-n** policy (`Policy.threshold_of` absent or
    `eligible`) takes `threshold` m/n, in hundred-millionths
    rounded down (2 of 3 is 66 666 666, shown as 66.666666 %), over the policy's n (`tally.seats`), not
    over the seats filled, and the policy's quorum; its `threshold_of` is `eligible`, which for a
    department means its policy's n, and `cast` is weaker and refused. It is accepted when the yes
    votes *reach* `threshold` of n, exactly m under the policy's own rule and the next whole number at
    or above t·n under a stricter threshold t, and a veto holder's `no` rejects it whatever the count
    (I-GOV-7). A direct policy (1 of 1) needs one yes. The eligible voters are the department's seated
    members (`tally.eligible`): they drive the quorum and the end at which everyone has voted, never
    the threshold, so a vacancy never makes a vote easier.
  - A **department's** proposal under a policy that counts the **votes cast** (`Policy.threshold_of`
    `cast`, the usual rule of a council or a parliament) takes a majority of them, `threshold` 50 %
    over the votes `cast`, the policy's quorum, and the department's `head`, its chair, as
    `casting_vote`; it has `majority_of_cast`. It is accepted when the votes cast reach the quorum of the
    policy's n (`tally.seats`) and the yes votes *exceed* `threshold` of the yes and no votes: an
    abstention counts towards the quorum, never towards the majority. The quorum counts over n, not
    the seats filled, so here too a vacancy never makes a vote easier; the policy's m is not used. A
    veto holder's `no` rejects it whatever the count (I-GOV-7). A tie in its first vote is put to a
    second vote (I-GOV-14), and a tie in the second vote is decided by the casting vote.
  - Under `cast`, a vote is a tie when at least one yes or no was cast and the yes votes are exactly
    `threshold` of the yes and no votes together (at 50 %: as many yes as no). The `casting_vote`
    member's yes accepts a tie; without one, or if that member did not vote yes, the tie rejects, so a
    tie never passes on its own. A realm-wide tie is decided at once; a department's under
    `majority_of_cast` only in its second vote.
    The casting vote is part of the scope's default rule, never the proposer's: for a realm-wide
    proposal the realm's, set by governed configuration, `Realm.casting_vote` (`governance_update`, an
    active member); for a department's, its `head` (`department_edit`). A proposal copies it when its
    vote opens: a chair who filed the proposal keeps it, and a later change moves no open proposal. A
    department under an m-of-n policy has none, since it counts over the seats, where no tie arises.
    A department's casting vote belongs to whoever `department_edit` has made its `head` when the vote
    opens; an acting appointment (`appoint_acting`) to a seat does not count, since it never changes
    `Department.head`. With no head a tie rejects. A head who holds no seat in the department cannot
    vote (I-GOV-2), so its ties reject too. If the realm's casting member leaves the
    realm, new proposals still copy them but their vote does not count (I-GOV-2), so realm-wide ties
    reject until `governance_update` names another member or clears it.
  - The proposer may state a stricter rule when creating the proposal, never a weaker one
    (`InvalidArgument`): a higher threshold or quorum, or `eligible` where the default is `cast`. Each
    change narrows what the default accepts, so legislation's guards, which may require them, only ever
    tighten. A stricter threshold t over the votes cast has its own tie, the yes votes exactly t of the
    yes and no votes, decided as the default's tie is. That never loosens the default: above 50 %, such
    a count already has more yes than no, which the default accepts outright. In a
    department that counts the votes cast, `eligible` adds a requirement and removes none: the yes
    votes must also *reach* `threshold` of n, rounded up as under m of n (an absolute majority of 33
    seats is 17, at 50 %), while the majority of the votes cast, with its second vote and casting
    vote, and the quorum of n still apply (`majority_of_cast`). So no stated rule accepts what the
    default rejects or would put to a second vote, even in a department that seats more members than
    its n. `cast` is never stricter than `eligible`.
  - A proposal that a governed call files takes its scope's default rule. Legislation may require a
    matter to be filed as a proposal of its own, with `proposal_create`, a `Call` action and a stricter
    rule, and a guard on the governed operation may refuse the direct path, so a chapter can demand a
    larger majority for, say, the budget.
  - `tally.eligible` is counted when the vote opens: the realm's active members, or the department's
    seated members; a department's `tally.seats`, its policy's n, is fixed then too.
- I-GOV-4: A contract created under a mandate stays within the mandate's scope and term, and its
  `value` within the mandate's `max_value` in the same `symbol`.
- I-GOV-5: A proposal may state `effective_at`, the time its action takes effect, in the future when
  the proposal is created. Without it, the action executes on acceptance. It is part of what voters
  approve: fixed at creation like the action, and it never moves, not after acceptance either.
- I-GOV-6: A proposal with an action, accepted with an `effective_at` still ahead, is
  `execution_scheduled`. It is executed at `effective_at`, not before: until then `proposal_execute`
  is refused with `Conflict`. A motion has nothing to execute: it stays `accepted`, and
  `proposal_execute` refuses it with `Conflict`, before and after `effective_at`. When several
  proposals are scheduled for the same moment, no order is specified.
- I-GOV-7: A proposal whose vote ends after its `effective_at` ends `expired`, whatever was decided,
  and is not executed; the proposer submits a new one. A vote ends at its `deadline`, or earlier at
  the moment every eligible member has voted. The vote of a department under an m-of-n policy may
  also end as soon as it can only be accepted: its yes votes reach its `threshold` of its policy's n
  seats (`m` under the policy's own rule, more under a stricter one the proposer stated), every veto holder
  has voted and none of them against (a veto holder's `no` rejects the proposal), and its quorum is met
  (I-GOV-3).
  Only an acceptance ends a department vote this early: until its deadline, or until every eligible
  member has voted, a `no` can still be replaced, even when the threshold is out of reach, and a veto
  holder yet to vote keeps it open. The end at which every eligible member has voted can still reject.
  A realm-wide vote, and one under `majority_of_cast`, has no such early end. When it is finalized
  doesn't matter: finalizing never moves the end of the vote (I-GOV-12 says how a GOS settles it).
  After the vote ends no vote is accepted or replaced (`Conflict`). A vote that ended before
  `effective_at` does not expire: finalized before `effective_at` the proposal is scheduled, even if
  its `deadline` is later, and finalized after it the proposal is accepted and its action executes at
  once.
- I-GOV-8: `proposal_stop` ends a proposal that is `execution_scheduled`, without executing it, as
  `withdrawn`; for any other status, or while its action is running, it is refused with `Conflict`.
  Its governing department is the one that owns the stopped proposal (§1), so the votes that may carry
  it are that department's and those of the departments above it (I-GOV-13). Under a policy that is
  not direct, calling it files a proposal of that department and replies `Proposed` with the new
  proposal's id; under a direct policy it applies at once and replies `Done` with no id, because it
  creates no record. A stop proposal that runs after its target is no longer scheduled ends `failed`.
- I-GOV-9: A proposal's links are fixed at creation, like its action: no operation edits a proposal's
  links or its action. To change a proposal, its proposer withdraws it and creates a new one that
  `replaces` it.
- I-GOV-10: A link names an existing proposal (`NotFound` otherwise), once (`InvalidArgument`
  otherwise). A proposal has at most 16 links of its own (`InvalidArgument`); the links to it from
  others are not limited. A `replaces` link names a `withdrawn` proposal filed for the same member (the
  grantor when `on_behalf_of` is set, else the proposer), else `Conflict`, or `Forbidden` when it was
  filed for another. A withdrawn proposal is replaced once: a second `replaces` of it is a `Conflict`.
  If the replacement is withdrawn too, a new proposal replaces the replacement, not the first one: in
  a chain A ← B ← C, `replaced_by` of A stays B. `relates to` has no such conditions.
- I-GOV-11: The other side of every link is readable. `proposal_get` shows the one proposal that
  replaces this one (`replaced_by`), and `proposal_linked_from` lists, a page at a time and oldest
  first, every proposal that links to it. A `replaces` there means "replaced by", and `relates to` is a
  reference both ways.
- I-GOV-12: A GOS may settle a proposal in any of these ways, and all are allowed: (1)
  `proposal_finalize` records the outcome and leaves an accepted action `accepted` for
  `proposal_execute`; (2) `proposal_finalize` also runs the accepted action; (3) the GOS settles the
  proposal itself when its vote ends, at the deciding vote or at the deadline, and a later
  `proposal_finalize` is refused with `Conflict`. After (2) and (3) an accepted proposal with an action
  is `executed` or `failed`, and `proposal_execute` is refused with `Conflict`; after (1) it is
  `accepted`, and `proposal_execute` replies `executed` or `failed`. In every way the proposal is
  `execution_scheduled` while `effective_at` is ahead, and at `effective_at` a GOS that runs the
  action by itself refuses `proposal_execute` with `Conflict`, one that does not waits for it. The
  action runs once (I-GOV-1).
- I-GOV-13: A proposal carries a call only within its scope. A realm-wide proposal may carry any call.
  A department's proposal may carry a call only when it is governed and its governing department (§1)
  is that department or one below it; `proposal_create` refuses any other with `Forbidden`. A call on
  a record that does not exist has no governing department: a department's proposal carrying it is
  refused with `NotFound`; a realm-wide one may carry it, and its execution ends `failed`. The check
  is made at creation and again when the action executes, against the departments as they are then: a
  proposal carries nothing when its department has been deleted, or when the department that governs
  its call is no longer that department or one below it (it was moved out from under it), and its
  execution ends `failed` (I-GOV-1: nothing runs). So a department's vote cannot stop a realm-wide
  scheduled proposal, the realm's can stop a department's, and a parent's can act on a department
  below it, where a sibling's cannot. A governed call that files a proposal itself (§1) scopes it to
  the governing department, so that proposal carries it when it is filed.
- I-GOV-14: Under `majority_of_cast` (I-GOV-3), a first vote that meets its quorum and ties does not end
  the proposal: recording its outcome (`proposal_finalize`, or the GOS settling it, I-GOV-12) opens a
  second vote on the same proposal instead, which stays `voting`. A veto holder's `no` still rejects
  the proposal whatever the count (I-GOV-3), so a tied first vote in which a veto holder voted no is
  rejected, not put to a second vote. The second vote keeps the rule, its casting vote included, the
  action, `effective_at`, `tally.eligible` and `tally.seats`; `first_vote` keeps the first vote's
  count, the ballots start empty, so every member votes again, and `opens_at` and `deadline` become
  the second vote's: it opens when the tie is recorded and lasts as long as the first did (with no
  deadline when the first had none). It ends as any vote does (I-GOV-7) and is decided like the first,
  so a second vote that misses its quorum is rejected; a tie in it is decided by the casting vote, and
  there is no third vote. A first vote that ended after `effective_at` expires the proposal instead,
  like a second vote that does. The first vote's ballots stay in the audit log (I-ALL-4).

## 5. Finance

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Treasury` | `id` (`1`), `config` (Json: epoch length, anchor month, source fund, auto-allocate), `debt_outstanding` | Singleton. `debt_outstanding` is the sum of the active loans' `outstanding`. | Monthly epochs, source fund `ROOT`, auto-allocation on, 420,000 REALM of debt |
| `Token` | `id` (symbol), `ledger`, `indexer`, `decimals`, `fee` | A fungible ledger the realm uses (ICRC-1). | `ckBTC`: ledger `mxzaz-…`, 8 decimals, fee 10 |
| `NFTToken` | `id` (symbol), `canister`, `name`, `description`, `transferable`, `required_license` (licence type or empty), `supply_cap`, `total_supply` | An NFT ledger (ICRC-7) the realm mints into. | `LAND` (transferable); `CRED` (non-transferable, minting needs a licence) |
| `Fund` | `id` (code), `name`, `kind` (general, special revenue, …), `department` → `Department`, `balances` (Json: running balance per token), `allocation_rule` → `AllocationRule` | | `ROADS`: special revenue, owned by Infrastructure |
| `FiscalPeriod` | `id`, `name`, `starts_at`, `ends_at`, `status`, `statements` (Json: running totals), `source_hash` (chained over its entries) | | `FY2026`: 2026-01-01 to 2026-12-31, `open` |
| `Budget` | `id`, `fund` → `Fund`, `period` → `FiscalPeriod`, `category`, `kind` (`revenue` or `expense`), `planned`, `actual`, `status`, `proposal` → `Proposal` | One line of a period's budget: `category` is the realm's word for what (capital, salaries, property tax), `kind` whether the money comes in or goes out. | Roads FY2026, expense, capital: planned 300,000, actual 120,500, `adopted` |
| `AllocationRule` | `id`, `source_fund`, `rules` (Json: fund and `share`), `status`, `proposal` → `Proposal` | How revenue is split between funds. Shares are in hundred-millionths and add up to at most 100 000 000. | From `ROOT`: 30% `WELFARE`, 20% `ROADS`, 50% `GENERAL` |
| `LedgerEntry` | `id`, `transaction`, `kind` (asset, liability, equity, revenue, expense), `category`, `debit`, `credit`, `symbol`, `fund` → `Fund`, `period` → `FiscalPeriod`, `transfer` → `Transfer`, `invoice` → `Invoice`, `user` → `User`, `organization` → `Organization`, `contract` → `Contract`, `case` → `Case`, `penalty` → `Penalty`, `appeal` → `Appeal`, `at`, `description` | Double entry. At most one of the source references is set. | Tx `T-88`: debit `ROADS` capital expense 50,000, credit cash 50,000, contract `C-9` |
| `Invoice` | `id`, `payer` (`Entity:id`), `amount`, `symbol`, `items` (lines, each an `InvoiceItem`: `concept`, `amount` (signed: a discount is negative), `quantity`, `unit`, `legislation`), `facts` (Json), `due_at`, `status`, `reason` (`Entity:id`), `paid_at`, `payment` (Json) | Paid into the subaccount derived from its `id`. At least one item, and the items sum to `amount`, which is never negative; `facts` is what legislation reads about the invoice beyond its items. | `INV-301`: Alice owes 120 REALM property tax, due 2026-12-31, `pending`: lines `property_tax` 150 and `large_family_bonus` −30 |
| `Transfer` | `id`, `sender`, `to`, `symbol`, `amount`, `ledger_tx`, `invoice` → `Invoice`, `status`, `at`, `payroll` (the payroll run) | | 50,000 REALM from `ROADS` to BuildCo, ledger tx 18234, `completed` |
| `Trade` | `id`, `contract` → `Contract`, `leg_a` → `Transfer`, `leg_b` → `Transfer`, `status` | An exchange of two transfers. | `C-9` milestone: realm pays 10,000 REALM, BuildCo hands over the road deed NFT |
| `PaymentAccount` | `id`, `owner` (`Entity:id`), `network`, `address`, `symbol`, `label`, `verified` | External accounts for payouts. | Bob's ckBTC payout address, verified |
| `FinancialReport` | `id`, `kind`, `period` → `FiscalPeriod`, `as_of`, `statements` (Json), `source_hash`, `issued_by`, `supersedes` → `FinancialReport` | Frozen statements. | FY2025 closing statements issued by Finance, `sha256:77d0…` |
| `TaxPolicy` | `id`, `status`, `document` (Json), `description`, `proposal` → `Proposal`, `adopted_at`, `taxes` (typed entries, each a `TaxEntry`: `code`, `kind` (the realm's word, e.g. `tax`, `fee`, `surcharge`), `subject` (the entity assessed, e.g. `Land`, `User`, `Organization`), `rate`, `amount`, `facts` (Json)) | Typed entries, which legislation checks one by one; the codex computes each taxpayer's amount. `document` holds the policy's text and whatever else the realm records about it, as Json; the entries are what the rules and the assessment read. | `TAX-POLICY-3`: `property_tax` (tax on `Land`, rate 0.4 %) and `waste_fee` (fee on `User`, 120 REALM a year), `adopted` |
| `TaxDeclaration` | `id`, `declarant` (`Entity:id`), `period`, `base`, `amount`, `status`, `invoice` → `Invoice` | Self-declared bases (revenue, payroll). | Clinic B declares 182,000 revenue for 2026-Q3 → `INV-412` |
| `Loan` | `id`, `lender` → `External`, `amount`, `symbol`, `term` (a Period), `rate`, `fund` → `Fund`, `outstanding`, `status`, `facts` (Json) | Money the realm owes an outside lender (§11), in the accounting currency, so the treasury's `debt_outstanding` is one sum. The money itself moves outside the realm; GGG records the debt and its repayments. | `LOAN-2`: 500,000 REALM from Bank A over 10 years at 3.2 %, into `ROADS`, 420,000 outstanding, `active` |

There is no balance entity: the ledgers are the source of truth.

### Lifecycles

- `Invoice.status`: `pending` → `paid` | `overdue` | `cancelled`; `overdue` → `paid` | `cancelled`.
- `Trade.status`: `pending` → `completed` | `failed`.
- `Transfer.status`: `sending` (ledger call in flight) → `completed` | `failed`; `sending` → `pending` (ledger refused) → `failed` (reverted).
- `Budget.status`: `draft` → `proposed` → `adopted` → `amended` (replaced by a later adopted line of
  its fund, period and category: `budget_amend` or a later budget) | `closed`; `extended` (copied
  from the previous period by `budget_extend`) → `amended` (replaced by the fund's adopted budget) |
  `closed` (with its period).
- `FiscalPeriod.status`: `open` → `closed` → `archived`.
- `AllocationRule.status`, `TaxPolicy.status`: `draft` → `proposed` → `adopted` → `superseded`.
- `TaxDeclaration.status`: `filed` → `assessed` → `settled` | `disputed`.
- `Loan.status`: `active` → `repaid`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `treasury_view`, `ledger_view`, `report_view` | `treasury.view` | read, delegable | Finance sees `ROOT` 1.2M, `ROADS` 180k REALM |
| `treasury_configure`, `token_register`, `nft_token_register` | `treasury.manage` | governed, delegable | Quarterly allocation epochs; register ckUSDC |
| `transfer_create` (from a fund) | `transfer.create` | delegable, governed | `{fund: "ROADS", to: "buildco", amount: 50000}` → proposal under Infrastructure's policy |
| `transfer_revert` | `transfer.delete` | governed, delegable | Cancel a duplicate pending payment |
| `invoice_create` | `treasury.manage` | delegable | Registration fee: 10 REALM for new member Bob |
| `invoice_item_add` | `treasury.manage` | delegable | The sanitation charge joins Alice's pending water invoice as a second line |
| `invoice_check` (own) | `self.invoice_refresh` | delegable | Alice paid `INV-301` → `paid` |
| `invoice_refresh` (any) | `invoice.refresh` | delegable | Finance re-checks all pending invoices |
| `my_invoices` | `self.data_view` | read, delegable | Alice: `INV-301`, 120 REALM, due 31 Dec |
| `fund_create`, `period_open`, `period_close` | `org.manage_budget` | governed, delegable | Create fund `WELFARE`; close `FY2025` |
| `budget_draft`, `budget_propose` (the draft lines of a period together: a fund's, or every fund's), `budget_amend` | `org.manage_budget` | governed, delegable | FY2027's lines drafted, then proposed as one budget → proposal |
| `budget_extend` | `org.manage_budget` | delegable | FY2027 opens: FY2026's adopted lines carry over as `extended`, fund by fund, for the funds with no extended, proposed or adopted line in FY2027 yet; `Conflict` when none is left |
| `allocation_rule_draft`, `allocation_rule_propose` | `org.manage_budget` | governed, delegable | Welfare share from 30% to 35% → proposal |
| `payroll_run` | `org.manage_budget` | governed, delegable | November salaries: 23 seats, 51,200 REALM |
| `loan_create` | `org.manage_budget` | governed, delegable | Borrow 500,000 REALM from Bank A over 10 years → proposal |
| `loan_repay` | `org.manage_budget` | delegable | Finance records a repayment of 80,000 REALM |
| `loan_list` | `treasury.view` | read, delegable | The realm's loans and what is outstanding |
| `report_issue` (with the issuer's `adjustments`, for a report in terms the ledger doesn't keep) | `treasury.manage` | signing, confirm | Finance issues the FY2025 statements |
| `tax_policy_draft`, `tax_policy_propose` | `tax.manage` | governed, delegable | `TAX-POLICY-4` drafted with `property_tax` at 0.5 %, then proposed → realm-wide vote; legislation checks each entry at the draft and again at the proposal |
| `tax_assess` | `tax.assess` | delegable | Annual run: 1,180 property-tax invoices |
| `tax_declare` | `tax.declare` | delegable | `{organization: "clinic-b", period: "2026-Q3", base: "revenue", amount: 182000}` → `INV-412` |
| `payment_account_add`, `payment_account_remove` | `self.data_manage` | confirm | Bob adds his ckBTC address; prepared by a delegate, it waits for his approval |
| `token_force_transfer`, `token_freeze` | `token.force_transfer`, `token.freeze` | signing, governed, confirm | Court-ordered restitution: 500 REALM from Mallory to Alice; freeze Mallory's account meanwhile |

A tax policy's `taxes` are typed entries, so legislation can check them one by one: a rule on
`tax_policy_propose` ranges over the entries of the saved policy the id names, one check per entry with
the entry's fields as its facts, and the same rules run when a draft is saved with `tax_policy_draft`
([layered codex §3.2](../docs/layered-codex.md#32-four-mechanisms)). An entry's `rate` or `amount` is
what it charges when no codex computes it; `tax_assess` asks the active codex for each taxpayer's
amount where it has one to give. A progressive tax, a rate per bracket of the base, is the exact total
over all its brackets, rounded once by the money rule, an exact half away from zero, to the nearest
cent, a multiple of 10^(decimals − 2) smallest units
([layered codex §3.3](../docs/layered-codex.md#33-the-fact-schema-units-rates-money-and-periods));
rounding each bracket's share would move the total by up to half a cent per bracket. On a base of
150.08 under 10 % up to 100.05 and 20 % above, the shares are 10.005 and 10.006 and the tax is 20.01,
the total 20.011 rounded once; bracket by bracket it would be 10.01 + 10.01 = 20.02.
[`conformance/src/money.js`](../conformance/src/money.js) is this rule as code, with the example as
its test.

A budget is proposed per period: `budget_propose` takes the draft lines of the period together, with
`years` when the plan covers more than one period, and legislation reads the totals of the lines it
proposes, `revenue` and `expense`, the sums of `planned` over their `revenue` and `expense` lines, as
facts of the call (derived facts, [layered codex §3.3](../docs/layered-codex.md#33-the-fact-schema-units-rates-money-and-periods));
legislation tells the two forms apart by `fund`. With a `fund`, it proposes that fund's draft lines of
the period, and the fund's owner governs it, under its own policy; without one, every fund's, and the
root governs it, as it governs `loan_create`: the realm's budget as a whole and its borrowing are the
realm's. Creating an owned record is governed by its owner: `fund_create` by the department named, the
root when none is. The lines are fixed when the proposal is filed, by the governed call or by any
proposal that carries it: they are `proposed`, with the proposal, a later `budget_propose` takes only
the `draft` lines left (`Conflict` when there are none), and the execution adopts exactly that
proposal's lines. A proposal that ends without adopting them (`rejected`, `expired`, `withdrawn`,
stopped, or `failed`) returns them to `draft`, with no proposal, so the fund's budget can be proposed
again. When a period opens, `budget_extend` copies, for each fund with no `extended`, `proposed` or
`adopted` line in it yet, the lines of that fund that stood at the previous period's end, `adopted`,
`extended` or `closed` with it, into the new period as `extended`, without a vote, so a budget
extended twice carries over; they hold until an adopted budget of that fund replaces them, which
makes them `amended`, so a category the adopted budget dropped does not come back at the next
extension; a later adopted line of the same fund, period and category amends the earlier one too,
within one adoption as well, where the line drafted later stands, and the spending booked against
the earlier one carries over, so one line stands per fund, period and category and the next
extension carries the newest; adopting one fund's lines neither blocks nor replaces another fund's
extensions; when no fund is left to extend it is refused with `Conflict`, while `draft` lines stand
in no way. An adopted budget is exhaustive for its fund: once a fund has an adopted budget for a
period, a `transfer_create` from it in that period names a category with an adopted `expense` line,
and any other is refused with `Conflict`; a transfer with no category counts as the category
`transfer`; a fund with only extended lines, or with none, spends as before. The ledger's fee for a
payment is exempt: the fee's ledger entry, which the GOS books itself in the category `ledger_fee`,
is a mechanical cost of the payment, not a spending decision. `ledger_fee` is reserved: a
`transfer_create` or `budget_draft` naming it is refused with `InvalidArgument`, budget or not, so
no proposal or extension carries one; every other category, an uncategorised transfer and payroll
included, needs a line once the fund's budget is adopted. Within a fund and period a category is
either `revenue` or `expense`: a draft whose fund, period and category already have a line of the
other kind is refused with `InvalidArgument`, and `budget_extend` leaves out a line whose category
the new period already holds as the other kind. A `budget_propose` whose derived total, `revenue` or
`expense`, is out of Money's range is refused with `InvalidArgument`, like any other fact.

### Invariants

- I-FIN-1: Every transaction's ledger entries balance (Σ debit = Σ credit).
- I-FIN-2: Money moves out of a fund only through `transfer_create` under the fund owner's policy.
- I-FIN-3: An invoice is `paid` only when the ledger shows the amount in its subaccount.
- I-FIN-4: Adopted budgets, allocation rules and tax policies are frozen; changes create a new version.
- I-FIN-5: A closed fiscal period accepts no new entries; corrections go into a restating report.
- I-FIN-6: The realm never moves a member's own funds, except a court-ordered `token_force_transfer` on a realm-issued token (signing, governed).
- I-FIN-7: An invoice has at least one item, and its items sum to its `amount`, which is never negative; a
  line joins only a `pending` invoice.
- I-FIN-8: `Treasury.debt_outstanding` is the sum of the active loans' `outstanding`; a repayment never
  exceeds a loan's.

## 6. Assets: land and NFTs

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Land` | `id`, `x`, `y`, `width`, `height`, `kind`, `owner` (`Entity:id`), `status`, `token_id`, `registered_by`, `assessed_value`, `area` (square metres), `assessed_at`, `assessment_ref`, `metadata` (Json) | A parcel, at most 16×16 cells. What an assessor set for taxes based on it, signing for it: its value in the accounting currency and its area, when, and under which reference in the assessor's register. | `L-17`: 3×2 cells at (12, 40), residential, owner `alice`, `LAND` #4412, assessed at 95,000 REALM and 120 m² |
| `Zone` | `id`, `name`, `kind`, `land` → `Land`, `user` → `User`, `population`, `metadata` (Json) | Either a member's own home cell, an h3 index set with `zone_set` and tied to that `user`, or a zone the realm defines with `zone_define`, such as a district without a canister of its own, named by its id: members name it as their `home_zone`, and `population` counts them. | Cell `871f1d489ffffff`, Alice's home cell; `riverside` "Riverside", a district, population 1,240 |

Certificates (prescriptions, diplomas, permits, titles) are NFTs, not realm entities: the ledger is
the source of truth, and the token's `ggg:` header carries what the realm knows about it. Every NFT the
realm mints carries that header:

| Key | Meaning | Example |
|---|---|---|
| `ggg:v` | header version (`1`) | `1` |
| `ggg:realm`, `ggg:quarter`, `ggg:network` | where the record lives | `agora-capital-id`, `north-quarter-id`, `ic` |
| `ggg:schema` | codex-defined schema, e.g. `health.prescription/1` | `health.prescription/1` |
| `ggg:subject` | `Entity:id` inside that realm | `Contract:C-88` |
| `ggg:issuer`, `ggg:license`, `ggg:signer`, `ggg:prepared_by` | who issued it and under which licence | `Organization:clinic-b`, `LIC-12`, `dr-ana`, `records-bot` |
| `ggg:signer_agent`, `ggg:supervisor` | present only when the signer acted as an agent: `1`, and its supervisor if it has one | `1`, `dr-ana` |
| `ggg:issued_at`, `ggg:expires_at` | validity, in seconds since the epoch | `1792915200`, `1795507200` |
| `ggg:payload_hash`, `ggg:payload_ref` | private content: hash and encrypted pointer only | `sha256:9f2c…`, `user:alice:rx-88` |

Header version 1 keeps its times in seconds, unlike the rest of the model, because tokens already
minted carry it. A version 2 header would move to nanoseconds.

GGG does not define any credential schema; codices declare them. For each schema a codex states the
licence type the issuer needs, the positions that may sign, the NFT collection, whether tokens are
transferable, the only extra keys allowed on the token, and whether credentials stand once their
licence is gone (I-AST-3). The ICRC-7 ledger has no burn, so a revoked credential is frozen with a
`ggg:revoked` reason.
`credential_verify` takes the token's header and frozen flag as read from the ledger.

### Lifecycles

- `Land.status`: `active` → `disputed` → `active`; `active` → `revoked`. A court-ordered transfer changes the owner and keeps `active`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `land_register` | `nft.mint` | governed, delegable | Register `L-17` for Alice after the survey |
| `land_transfer` | `nft.force_transfer` | signing, governed, confirm | Court orders `L-17` moved from Mallory to Alice (normal sales use the ledger) |
| `land_assess` | `land.assess` | signing, confirm | The assessor sets `L-17`'s value at 95,000 REALM and its area at 120 m² |
| `land_list`, `land_map` (a viewport of at most 32×32 cells) | `realm.data_view` | read, delegable | Map of quarter North's parcels |
| `land_mint_nft` | `nft.mint` | delegable | Mint `LAND` #4412 for `L-17` to Alice |
| `land_freeze`, `land_unfreeze` | `nft.freeze` | signing, confirm | Freeze `L-17` during an ownership dispute |
| `zone_define` | `realm.configure` | governed, delegable | Define the district Riverside, which members name as their `home_zone` |
| `zone_set`, `zone_clear` | `self.data_manage` | delegable | Alice sets the cell she lives in as her home cell |
| `credential_issue` | `credential.sign` | signing, confirm | Dr. Ana issues `{schema: "health.prescription/1", holder: "alice", organization: "clinic-b", prepared_by: "records-bot"}` → `CRED` #4412 |
| `credential_revoke` | `credential.sign` | signing, confirm | Revoke a diploma issued in error; the token is frozen as revoked |
| `credential_verify` | — (public) | read | A pharmacy checks `CRED` #4412: valid, issuer licensed, not expired |

### Invariants

- I-AST-1: A credential NFT is minted only if the issuing organization holds an active licence of the
  schema's type, the caller holds an active appointment in a position the schema accepts (an agent
  appointment only where the signing policy allows it), and the codex allows it.
- I-AST-2: Tokens of a non-transferable `NFTToken` never change owner except by a court order.
- I-AST-3: Revoking a licence stops new mints under it; existing credential NFTs follow the codex rule.
- I-AST-4: NFT metadata never contains personal data in clear text.
- I-AST-5: A parcel has exactly one owner.

## 7. Licensing, procedures and requests

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `License` | `id`, `kind` (court, business, professional, health, education, …), `holder` (`Entity:id`: organization or user), `issued_by` → `Department`, `status`, `applied_at`, `decision_due`, `issued_at`, `expires_at`, `evidence_ref`, `conditions` (Json) | Many licences per holder. An application is a licence in `applied`; `decision_due` comes from the `Procedure` of its kind, when one is defined. | `LIC-12`: health, holder Clinic B, issued by Health, active until 2028-10-25 |
| `Procedure` | `id` (the licence kind it governs), `initiated_by`, `matter`, `decision_deadline` (a Period), `silence` (`positive` grants, `negative` refuses), `legislation`, `facts` (Json) | How applications of one kind are decided. Legislation acts on the silence, with a task (§11). | `health`: initiated by the applicant, decided within 3 months, silence positive |
| `Request` | `id`, `kind`, `by` (`Entity:id`), `body` (Json), `filed_at`, `due_at`, `extension_limit`, `status`, `decision`, `reply`, `decided_at` | A request to the realm by a person or a body: a petition, a complaint, a request for information or for one's personal data. The kinds are the realm's; legislation sets `due_at` and says what silence means, recording it as a decision. A `body` or `reply` that holds personal data is an encrypted `Document` reference (I-PRV-1). | `REQ-14`: Bob asks for last year's minor contracts, due in one month, `filed` |

### Lifecycles

- `License.status`: `applied` → `active` | `rejected`; `active` ⇄ `suspended`; `active` |
  `suspended` → `revoked` | `expired`.
- `Request.status`: `filed` → `decided`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `license_apply`, `license_renew` | `license.apply` | delegable | Clinic B applies for a health licence with its dossier |
| `license_decide` | `license.issue` | signing, confirm | A Health officer approves → `LIC-12` active for 2 years |
| `license_suspend`, `license_revoke` | `license.revoke` | signing, confirm | Suspend `LIC-12` pending an inspection |
| `license_list`, `license_verify` | — (public) | read | A patient checks Clinic B: licence active |
| `procedure_define` | `procedure.define` | governed, delegable | Health licences: decided within 3 months, silence positive |
| `procedure_list` | `realm.data_view` | read, delegable | The realm's procedures |
| `request_file` | `request.file` | delegable | Bob files an access-to-information request |
| `request_get` (own) | `self.data_view` | read, delegable | Bob checks `REQ-14` |
| `request_list` | `request.decide` | read, delegable | The clerk lists the requests due this week |
| `request_set_due`, `request_decide` | `request.decide` | delegable | The clerk extends `REQ-14` by a month, then grants it with the list |

### Invariants

- I-LIC-1: Nobody decides a licence for an organization they hold an appointment in, or for themselves.
- I-LIC-2: Only `active`, unexpired licences authorize anything.
- I-LIC-3: A request's `extension_limit` is set once; its `due_at` never moves past it, and a decided
  request is final.

`license_apply` sets the licence's `decision_due` from the `Procedure` of its kind, when one is defined.
What silence past a deadline means is legislation's: a procedure says it, and a task (§11) scheduled for
the deadline records it, as `license_decide` or `request_decide`.

Regulatory reports from licensed providers are department documents ([§13](#13-private-content)) or
codex-defined credential NFTs; GGG has no report entity.

## 8. Justice

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Court` | `id`, `name`, `operator` (`Entity:id`: a department for public courts, an organization for private ones), `level` (first instance, appellate, supreme, specialized), `jurisdiction`, `parent` → `Court`, `status`, `license` → `License` | | North First Instance Court, run by the Justice department; appeals go to Agora Appeals Court |
| `Judge` | `id`, `user` → `User`, `court` → `Court`, `specialization`, `status`, `appointed_at` | | Judge Elena, North First Instance Court, civil |
| `Dispute` | `id`, `claimant` → `User`, `respondent` (`Entity:id`), `subject` (`Entity:id`, e.g. a contract), `title`, `description_ref`, `status`, `case` → `Case` | A complaint before it is accepted. | `D-14`: Bob vs Infrastructure, "building permit refused unfairly", `filed` |
| `Case` | `id`, `court` → `Court`, `plaintiff`, `defendant`, `judges` → `Judge`*, `title`, `dispute` → `Dispute`, `evidence` (Json: encrypted refs and hashes), `status`, `filed_at`, `closed_at` | | `CASE-12` from `D-14`, North First Instance, Judge Elena, `in_progress` |
| `Verdict` | `id`, `case` → `Case`, `issued_by` → `Judge`, `decision`, `reasoning_ref`, `status`, `contract` → `Contract`, `issued_at` | | `CASE-12`: refusal annulled, issue the permit within 15 days |
| `Appeal` | `id`, `case` → `Case`, `verdict` → `Verdict`, `court` → `Court`, `appellant` → `User`, `grounds_ref`, `status`, `decision`, `new_verdict` → `Verdict` | | Infrastructure appeals `CASE-12` to Agora Appeals Court, `under_review` |
| `Penalty` | `id`, `verdict` → `Verdict`, `target` (`Entity:id`), `kind` (fine, restitution, community service, suspension, revocation, injunction, freeze, termination), `amount`, `symbol`, `status`, `due_at`, `executed_at`, `invoice` → `Invoice` | | Mallory: 500 REALM fine for spam, due in 30 days → `INV-520` |

### Lifecycles

- `Dispute.status`: `filed` → `accepted` (creates a `Case`) | `rejected` | `withdrawn`.
- `Case.status`: `filed` → `assigned` → `in_progress` → `verdict_issued` → `closed`;
  `verdict_issued` → `appealed` → `verdict_issued` | `closed`; any open state → `dismissed` |
  `transferred`.
- `Verdict.status`: `draft` → `issued` → `final`; `issued` → `overturned` (appeal granted).
- `Appeal.status`: `filed` → `under_review` → `granted` | `denied`; `filed` → `withdrawn`.
- `Penalty.status`: `pending` → `executed` | `waived`.
- `Court.status`: `active` → `closed`.
- `Judge.status`: `active` → `revoked`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `dispute_file`, `dispute_withdraw` | `dispute.create` | delegable | `{respondent: "Department:infrastructure", title: "Permit refused"}` → `D-14` |
| `dispute_get` (own) | `dispute.view` | read, delegable | Bob checks `D-14` |
| `dispute_list_all` | `dispute.view_all` | read, delegable | The court clerk lists all open disputes |
| `dispute_accept`, `dispute_reject` | `dispute.accept`, `dispute.reject` | signing, confirm | The court accepts `D-14` → `CASE-12` |
| `case_assign` | `dispute.assign` | delegable | Assign Judge Elena to `CASE-12` |
| `evidence_submit` | `dispute.create` (party) | delegable | Bob uploads his building plans, encrypted |
| `evidence_evaluate` | `evidence.evaluate` | signing, confirm | Elena admits the plans as evidence |
| `verdict_draft` | `resolution.draft` | delegable | Elena drafts the verdict |
| `verdict_issue`, `verdict_finalize` | `resolution.issue`, `resolution.finalize` | signing, confirm | Elena issues it; it becomes final when the 14-day appeal window passes |
| `verdict_link_contract`, `verdict_modify_terms` | `resolution.link_contract`, `resolution.modify_terms` | signing, confirm | Link the verdict to contract `C-9` it terminates |
| `appeal_file` | `dispute.create` (party) | delegable | Infrastructure appeals within 14 days |
| `appeal_decide` | `appeal.allow` | signing, confirm | The appeals court denies the appeal |
| `penalty_execute` (the permission depends on the kind: fine and restitution `fine.apply`; suspension and revocation `access.revoke`; termination `contract.terminate`; freeze `instrument.lock`; injunction and community service `enforcement.record`) | `fine.apply`, `access.revoke`, `contract.terminate`, `instrument.lock`, `enforcement.record` | signing, confirm | Mallory's 500 REALM fine → invoice `INV-520` |
| `enforcement_record`, `enforcement_escalate`, `enforcement_notify` | `enforcement.record`, `enforcement.escalate`, `notification.send` | delegable | Record that the permit was issued as ordered |
| `court_create`, `judge_appoint`, `judge_revoke` | `org.create`, `org.appoint` | governed, delegable | Create South First Instance Court; appoint Judge Elena. During setup `judge_appoint` asks each time |
| `resolution_query` | `resolution.query` | read, delegable | All verdicts about building permits since 2026 |

### Invariants

- I-JUS-1: No judge sits on a case in which they, or a department or organization they hold an
  appointment in, is a party. (Guardrail.)
- I-JUS-2: Only judges assigned to a case issue its verdict.
- I-JUS-3: An appeal is heard by a court of higher level than the original.
- I-JUS-4: A penalty executes only after its verdict is final (no pending appeal, appeal window passed).
- I-JUS-5: A court run by an organization operates only under an active court licence.

## 9. Procurement

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Tender` | `id`, `title`, `description`, `requester` → `Department`, `kind`, `procedure`, `estimated_value`, `status`, `opens_at`, `closes_at`, `rubric` (Json: criterion and `weight`), `notices` (each a `Notice`: `journal`, `published_at`, `ref`), `winner` → `Bid`, `contract` → `Contract` | Weights are in hundred-millionths and add up to 100 000 000. `kind` (works, supplies, services) and `procedure` are the realm's words. `notices` records where the tender was published, and legislation reads `published_in`, the journals of the notices, as a fact of `tender_award`. | `T-5` Bike lane works, by Infrastructure, works by open procedure, 600,000 REALM estimated, open 1–30 Nov, rubric: price 60%, quality 40%, noticed in the realm's journal |
| `Bid` | `id`, `tender` → `Tender`, `vendor` → `Organization`, `submitted_at`, `sealed`, `payload_ref`, `payload_hash` (`sha256:` of `price:nonce`), `price` (set at the reveal), `score` | Content is encrypted until the reveal. | BuildCo's bid on `T-5`, sealed until 30 Nov |
| `BidScore` | `id`, `bid` → `Bid`, `evaluator` → `User`, `criterion`, `score`, `scored_at` | | Carla scores BuildCo's quality 8/10 |

The `Event` log records a tender's transitions, and a vendor's record is derived from the tenders
it was awarded.

### Lifecycle

`Tender.status`: `draft` → `open` → `closed` → `evaluation` → `awarded` → `contracted`;
`draft` | `open` → `cancelled`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `tender_create`, `tender_open`, `tender_close`, `tender_cancel` | `tender.manage` | governed, delegable | Infrastructure drafts `T-5`, then opens it |
| `tender_list`, `tender_get` | `realm.data_view` | read, delegable | Open tenders |
| `tender_notice` (in an `External` of kind `journal`, or `realm` for the realm's own; `at` defaults to now and is never in the future) | `tender.manage` | delegable | Infrastructure records that `T-5`'s notice appeared in the realm's journal |
| `bid_submit`, `bid_withdraw` | `bid.submit` | delegable | BuildCo's agent submits an encrypted bid on `T-5` |
| `bids_reveal` | `tender.manage` | governed, delegable | After 30 Nov the 4 bids are decrypted |
| `bid_score` | `bid.evaluate` | signing, confirm | Carla and two colleagues score each bid |
| `tender_award` | `tender.manage` | signing, governed, confirm | Award `T-5` to BuildCo (score 86) → contract `C-9` |

### Invariants

- I-PRC-1: Sealed bid contents are unreadable by anyone, including the requester, until `bids_reveal`
  after `closes_at`.
- I-PRC-2: No evaluator scores a bid from an organization they hold an appointment in. (Guardrail.)
- I-PRC-3: The award goes to the best-scored bid under the published rubric, or the deviation is
  justified and recorded.
- I-PRC-4: Bids are accepted only between `opens_at` and `closes_at`.

## 10. Quarters and federation

A realm can be one canister or a federation of quarters, one of which is the capital. A realm also
takes legislation from other realms, its sync sources, over links both sides vote on
([links between realms](#links-between-realms)).

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Realm` | `id` (`1`), `name`, `manifesto`, `welcome_message`, `status`, `calendar` → `Calendar`, `treasury` → `Treasury`, `accounting_currency`, `accounting_currency_decimals`; federation: `is_quarter`, `is_capital`, `federation_realm_id`, `federation_codex`, `quarter_join_mode`, `sync_sources` (each a `SyncSource`: the realms it takes legislation from); trust: `trusted_principals`, `require_marketplace_approval`, `trusted_approvers`; governance: `voting_threshold`, `voting_quorum` (hundred-millionths, for realm-wide proposals), `casting_vote` → `User` (a member whose yes decides a tie, I-GOV-3); settings: `open_registration`, `logo_url`, `background_image_url`, `installed_version`, `network`, `timezone`, `languages` (BCP 47 tags, the first the default); `member_count` (its members, and on a capital its quarters' as they last reported) | Singleton per canister. An implementation adds its own settings next to these. | Agora: `beta`, capital, currency REALM (8 decimals), open registration off |
| `Calendar` | `id`, `realm` → `Realm`, `epoch`, `fiscal_period`, `voting_window`, `codex_release_cycle`, `benefit_cycle`, `service_payment_cycle`, `license_review_cycle`, `custom_cycles` (Json) | The realm's governance time cycles, as durations. | Voting window 7 days, fiscal period 1 year, licence review every 2 years |
| `Registry` | `id` (name), `description`, `principal_id` | A registry canister the realm is listed in. | `realm-registry`, `ufxgi-…` |
| `Quarter` | `id` (canister id), `name`, `index`, `status`, `population`, `codex_id`, `codex_version`, `compliance`, `last_sync`, `last_activity_at` | Known on the capital. `compliance` is the same flag as a follower's: a quarter not ready when its realm's codex switches is `non_compliant` until it installs. | North: population 1,240, `active`, codex agora 1.4.2, compliant |
| `Forward` | `id`, `subject` (`Entity:id`), `origin`, `destination`, `moved_at`, `signature` | Signed pointer left when a user moves quarter. | Bob moved North → South on 2026-09-01, signed by North |
| `FederalVote` | `id`, `title`, `origin_quarter`, `action` (one operation call, as a proposal's), `rule` (Json), `hash`, `deadline`, `status`, `tally` (Json) | | `FV-3` Adopt tax policy 3: majority of quarters, deadline 15 Nov |
| `FederalVoteLeg` | `id`, `vote` → `FederalVote`, `quarter`, `proposal_id`, `outcome`, `yes`, `no`, `abstain`, `eligible`, `status`, `hash` | One per quarter. | North on `FV-3`: 812 yes, 301 no of 1,240 eligible → passed |
| `FederationMessage` | `id`, `topic`, `source`, `body` (Json), `response` (Json) | | North → capital: population report |
| `SyncSource` | `source` (a realm, by its capital, or a stand-in record: an https URL and the checksum of its content), `name`, `status` | On a follower, in `Realm.sync_sources`: a realm it takes legislation from, with the link's status. A stand-in record stands for a source that runs no realm. | CV, `active`; the EU's record at `https://…/releases.json`, `sha256:…`, `active` |
| `Follower` | `id` (the follower's capital, as text), `capital`, `status`, `layers` (each a `ReportedLayer`), `compliance`, `population`, `reported_at` | On a sync source: a realm that takes legislation from it, with the link's status and the follower's last report. | València on CV: `active`; reported Spain's 2.4.0 and CV's 1.1.0, compliant, population 800,000, on 3 Nov |
| `ReportedLayer` | `version`, `checksum` | One layer a follower runs, as it reports it. It names no source: the sync source finds the layer by its checksum in its own record. | Spain's 2.4.0, `sha256:…` |

There is no central user-to-quarter directory. A user's home quarter is found from their own client
pointer, the quarter index, or a broadcast search, so no canister grows with the population of the
whole federation.

### Lifecycles

- `Realm.status`: `setup` → `alpha` → `beta` → `production` → `deprecation` → `terminated`.
- `Quarter.status`: `setup` → `active` ⇄ `suspended`; `active` → `splitting` | `merging` → `active`.
- `FederalVote.status`: `open` → `passed` | `failed` | `cancelled`.
- `FederalVoteLeg.status`: `open` → `reported`, with `outcome` `passed` or `failed`.
- `SyncSource.status`, `Follower.status` (the link's): `requested` → `active` → `ended`;
  `requested` → `ended`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `quarter_register`, `quarter_deregister`, `quarter_configure` | `quarter.register`, `quarter.deregister`, `quarter.configure` | governed, delegable | Register quarter South |
| `quarter_secede` | `quarter.secede` | governed, delegable | South leaves the federation after its own vote |
| `quarter_join_federation` | `quarter.join_federation` | governed, delegable | The independent realm Harbor joins Agora as a quarter |
| `quarter_directory`, `join_targets` | — (public) | read | Quarters and their populations; the least-populated active quarter a new member joins. `join_targets` takes the `home_zone` the joiner states, if any, and a codex's `compute_realm_join` may use it to keep neighbours together: it is used for the placement and is not part of the reply. A codex only chooses among the quarters the GOS offers it, and the GOS offers by capacity first. `quarter_directory` leaves `QuarterDirectory.zones` null: that field is `quarter_sync`'s, and its zones carry no count |
| `self_change_quarter` | `self.change_quarter` | confirm | Bob moves to South; prepared by a delegate, it waits for his approval |
| `quarter_sync`, `quarter_report` (quarter → capital) | `quarter.sync` | | North reports population 1,240, codex 1.4.2 and 310 members in Riverside to the capital, which keeps the counts for placing new members and returns them in no reply. The capital's reply to `quarter_sync` also carries `zones`, the zones the realm defines (each as `zone_define` takes it: id, name, kind, no population), because the realm's codex defines its districts on the capital alone; a quarter defines the same by id, redefining one it has in place, and keeps the zones it defined itself |
| `federal_vote_propose` | `federal_vote.propose` | confirm | Propose `FV-3`; prepared by a delegate, it waits for the member's approval |
| `federal_vote_cancel` | `federal_vote.manage` | governed, delegable | Withdraw `FV-3` before its deadline |
| `federal_vote_finalize` | — (public) | | After 15 Nov: 3 of 4 quarters in favour → `passed` |
| `federation_message` | `quarter.sync` | | The capital announces codex 1.5.0 to its quarters |
| `sync_source_add`, `sync_source_remove` | `sync_source.manage` | governed, delegable | València votes to take legislation from CV; later it stops taking EMSHI's |
| `follower_accept`, `follower_remove` | `follower.manage` | governed, delegable | CV votes to accept València as a follower |
| `link_notify` (from the capital at the other side of a link) | `link.sync` (held only by the capitals of the realm's links) | | CV tells València their link is `active`; later, València tells CV it `ended` |
| `follower_report` (from a follower's capital, over an active link) | `link.sync` | | València reports to CV the layers it runs, that it is compliant, and its population |
| `follower_list` | `realm.data_view` | read, delegable | CV's followers, with what each runs |

### Time zones

Each quarter is a realm canister with its own `Realm.timezone` (I-ADM-4, §12). It starts on its
capital's zone, copied once when it joins the federation, and after that the zone is the quarter's
own. Only a realm still on `UTC` takes the capital's zone: a realm that already chose one keeps it
when it joins as a quarter. The quarter may change it with `realm_configure`. The realm may also set
it by a realm-wide vote: `quarter_configure` takes a `timezone` for the `quarter` it names, which the
capital sends to the quarter (`quarter.sync`) and the quarter applies. A name that is not an IANA name
of I-ADM-4's shape is refused with `InvalidArgument` before any vote, and so is a `timezone` with no
`quarter`; the capital's own zone is set with `realm_configure`. If the quarter cannot apply the zone,
the call fails and nothing changes. In a federation, the capital's zone is the realm's official time
and a quarter's zone its local time. Realm-wide counts are made on the capital: a `FederalVote` has
one `deadline`, set there once as an instant, and every quarter's leg keeps it.

### Welcome message

Each quarter has its own `Realm.welcome_message`. It starts from its capital's, copied once when the
quarter joins the federation, and only a realm that has none yet (an empty message) takes it: a realm
that already has one keeps it. After that the message is the quarter's own, and the quarter may change it
with `realm_configure`. The realm may also set it by a realm-wide vote: `quarter_configure` takes a
`welcome_message` for the `quarter` it names, which the capital sends to the quarter (`quarter.sync`) and
the quarter applies. A `welcome_message` with no `quarter` is refused with `InvalidArgument`, before any
vote. If the quarter cannot apply it, the call fails and nothing changes.

### Links between realms

A realm takes legislation from the realms it chooses by vote, its **sync sources**, and each of them
accepts it by vote; on the source's side the realm is a **follower**. There is no parent, no tier and
no national code. A source is a realm, named by its capital, or, for a body that runs no realm, a
stand-in record at a public https URL, pinned by the checksum of its content. `sync_source_add` and
`sync_source_remove` are the follower's votes, `follower_accept` and `follower_remove` the source's.
The side whose vote changes a link tells the other side's capital with `link_notify`, and a follower's
capital reports with `follower_report` what it runs, a `ReportedLayer` per layer, its compliance
against that source and its population; the source keeps the last report on the follower's entry. The
layers, compliance and population are the follower's own report; the follower's `codex_status` remains
the authority; the source matches each layer by its checksum in its record, and a layer its record
does not list matches nothing.
Which followers a source counts, for its population or a vote, its own legislation decides by reading
its `Follower` records. A source's legislation may hook `link_notify` (`on_link_notify`, reading the
new status, such as `ended` by the follower) but never guard or forbid it, so a side always learns
that a link ended; and `sync_source_remove` is reserved, so no legislation of the follower can forbid,
guard or hook it, and a realm can always leave
([layered codex §1](../docs/layered-codex.md#1-chapters-use-gggs-operations-directly)).

Operations between realms carry a derived fact, `follower_compliance`, for a source's legislation to
test like an argument: on `transfer_create`, the compliance last reported by the follower that `to`
names (`{kind: "Follower", id: its capital}`) over an active link, `unknown` for any other recipient
or a link not active; on `quarter_report`, the reporting quarter's `compliance`.

Calls between realms are bounded-wait: a call that times out counts as unanswered (the realm cannot be
read, or the notice is sent again).

How a follower installs what a sync source relays is the GOS's business, not the model's; §11 says
what GGG provides. Realms GOS adds three install rules there: a follower checks each layer from above
against the record that vouches for it, its publisher's or the relaying source's; a release is
installed whole; and the paths from several sync sources must form one chain in each domain.

### Invariants

- I-FED-1: A user is a member of exactly one home quarter; elsewhere they are a guest.
- I-FED-2: A federal vote passes only by its published rule over legs reported by every known quarter
  (or the rule's explicit absence policy).
- I-FED-3: Every quarter runs the same federation codex version as the capital, or is flagged as drifting.
- I-FED-4: Calls between quarters are accepted only from registered quarter canisters.
- I-NEST-1: A link is active only after both votes, the follower's `sync_source_add` and the source's
  `follower_accept`, in either order; until then it is `requested`. A stand-in record cannot vote, so
  its link is `active` on the follower's vote alone, and a second `sync_source_add` of the same URL
  pins a new checksum without ending the link; a second one of the same realm while the link is
  `requested` or `active` is `Conflict`. Either side ends a link by its own vote (`sync_source_remove`,
  `follower_remove`): it is `ended`, by that side's capital and at that time, the follower keeps what
  it installed, and a new vote on each side opens a new link.
- I-NEST-2: No cycles: a realm never takes legislation from itself, directly or through other realms.
  Both votes check it, at any remove and over any link not `ended`: `sync_source_add` that the source
  does not take legislation from this realm, `follower_accept` that this realm does not take
  legislation from the follower; and the check runs again when the call applies. A cycle is refused
  with `Conflict`, and a realm that cannot be read fails the check with `Unavailable`: never an open
  link. A vote records the link as `requested` before it checks, so a vote cast at the same time on
  the other side sees it.
- I-NEST-3: Calls between realms go between the capitals of a link and nowhere else. `link_notify`
  and `follower_report` are accepted only from the capital at the other side of a link this realm
  has voted on, and a report only over an `active` link: any other caller is refused with
  `Forbidden`, a report over a link that is not active with `Conflict`. Neither is delegable: the
  caller is the other realm's capital. A notice that a link ended names its sender as `by`, at a
  time not ahead of the receiver's clock by more than a few minutes; any other is refused with
  `InvalidArgument`. A side whose notice is refused because the other has not voted yet loses
  nothing: when the other side votes, its own notice completes the link, and the receiver's reply,
  `active`, tells it so. A notice that is not answered (the call is rejected or times out; a
  `GggError` is an answer) is sent again until it is answered.

## 11. Codex, notifications, outside bodies, tasks and audit

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Codex` | `id` (`name@version`), `version`, `checksum`, `status` (`pending`, `active`, `inactive`, `reverted`), `manifest` (Json, including the signing policy), `capabilities` (Json: operation names), `source` (its code), `installed_at`, `previous` → `Codex` | The realm's policy package. At most one is `active`; a `pending` one is installed and checked, waiting for its time. Methods return its `checksum` (`sha256:<hex>`), never this record. | `agora@1.4.2`, checksum `sha256:4be1…` |
| `Release` | `source`, `version`, `published`, `effective_from`, `commit`, `chapters` (each a `ChapterRef`: `domain`, `checksum`), `calendar`, `notes` (Json) | One release of one layer, as a published record lists it: every chapter of the source, changed or not, by domain and checksum, its calendar's checksum, the commit it was built from, when it was published and from when it is in force. `source` is the layer's source id, opaque text to GGG. | Spain's 2.4.0: tax, procedure and register chapters, calendar `sha256:…`, in force from 1 Jan 2027 |
| `Notification` | `id`, `recipient` (`Entity:id`: user, department or organization), `topic`, `title`, `body`, `href`, `sender`, `visibility`, `read_by` (Json), `at` | | To Alice: "P-7 passed", link `/proposals/P-7` |
| `External` | `id`, `name`, `kind` (authority, journal, lender, …), `channel` | A body outside the realm and outside the Internet Computer. `channel` is how a dispatch reaches it: `manual`, an operator delivers it, or an https URL, a bridge does. A second `external_add` of the same id redefines it. | The statistics office: kind `authority`, channel `manual`; the provincial gazette: kind `journal` |
| `Dispatch` | `id`, `to` → `External`, `topic`, `title`, `body` (Json), `document` → `Document`, `codex`, `queued_at`, `status` | One notice to an outside body, queued by the realm and confirmed by whoever delivered it, with the receipt that proves it. `document` is the document it carries and `codex` the codex it concerns, when either applies. A `body` that holds personal data is an encrypted `Document` reference (I-PRV-1). | To the gazette: the new ordinance's full text, `confirmed` on 12 Nov, bulletin 214 |
| `Task` | `id`, `op`, `args` (Json), `at`, `reason`, `status`, `scheduled_by` (`Entity:id`), `event` → `Event` | One operation scheduled for a time. `event` is the operation's own `Event` once it ran. | `user_set_status` of Bob to `inactive` on 10 Mar 2028, scheduled by the codex: the registration lapses |
| `Event` | `id`, `op`, `user`, `by` (the delegate, when delegated), `grant` (the grant a delegated act ran under), `prepared_by` (the delegate that prepared an act the member approved, origin `confirmed`), `agent` (the caller acted as an agent), `supervisor` (that agent's supervisor), `origin`, `args` (Json, secrets stripped), `result` (Json), `at` | The audit log. Append-only. | `proposal_vote` by `claude-conn` for `alice` under grant `DEL-4` at 09:31 → ok |

Services are not entities: they are provided by licensed organizations. Courts stand on their own,
without a justice-system entity above them.

A `Task` schedules one operation for a time. Multi-step automation beyond that is part of an
implementation, not of the model; what it does goes through operations like any other call.

### Lifecycles

- `Codex.status`: `pending` → `active`; `active` → `inactive` | `reverted`.
- `Dispatch.status`: `queued` → `confirmed` | `failed`.
- `Task.status`: `scheduled` → `run` | `failed` | `cancelled`.

### Signing policy

The active codex's manifest has a `signing` section. It says who may perform `signing`
operations:

| Key | Meaning | Default |
|---|---|---|
| `agents` | The signing permissions an agent may hold, or `all`. | none |
| `delegable` | The signing permissions a `Delegation` may cover, or `all`. | none |
| `supervision` | `required`: every agent appointment has a non-agent supervisor (I-ORG-3). `optional`: it may have none. | `required` |

Without an active codex, or when the section is missing, the defaults apply: only non-agents sign,
nobody signs on another's behalf, and every agent has a supervisor. The policy changes only with the
codex, through `codex_install`, which is governed. `codex_status` returns the active checksum and this policy.

For example, Agora's codex sets `agents: [bid.evaluate]`: an evaluation agent appointed in
Infrastructure may score bids, while `credential.sign` stays with Clinic B's physicians.

Whatever the policy, a signing act records who signed, whether they acted as an agent, their
supervisor, and the grantor when delegated (I-ALL-7).

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `codex_install`, `codex_uninstall` | `codex.install`, `codex.uninstall` | governed, delegable | Install agora 1.5.0 → realm-wide vote |
| `codex_revert` (the codex the active one replaced, or any earlier one by its checksum) | `codex.revert` | governed, delegable | Revert to 1.4.2 when 1.5.0 misbehaves; to 1.3.0, by its checksum, when 1.4.2 does too |
| `codex_activate` (the pending codex, by checksum) | `codex.install` | governed, delegable | Activate the pending 1.5.0 on 1 Jan |
| `codex_status` (the active checksum, health and the signing policy; earlier checksums a page at a time) | `realm.data_view` | read, delegable | `sha256:4be1…`, healthy; agents may hold `bid.evaluate` |
| `legislation_release_publish` | `legislation.publish` | governed, delegable | CV publishes 1.1.0: its chapters' checksums, its calendar's, the commit, in force from 1 Jan 2027 |
| `legislation_releases` (the published record, a page at a time), `legislation_chapter` (the bytes of a chapter, by checksum) | — (public) | read | CV's record: Spain's 2.4.0 as CV installed it, then CV's own 1.0.0 and 1.1.0 |
| `notification_list` (one recipient a page at a time) | `self.data_view` | read, delegable | Alice's notifications, then Civil Registry's. Under a grant, the grantor's own; an office's only under that office's group |
| `notification_read` (mark as read) | `self.data_manage` | delegable | Alice marks "P-7 passed" as read |
| `notification_send` (to a user, department or organization a `Notification`; to an `External` a `Dispatch`; with `translations`, each reader gets their language) | `notification.send` | delegable | Justice notifies Mallory of her fine; Civil Registry tells the statistics office of Bob's registration |
| `external_add` | `external.manage` | governed, delegable | Register the statistics office and the provincial gazette |
| `external_list` | `realm.data_view` | read, delegable | The outside bodies the realm deals with |
| `external_report` | `external.report` | delegable | A clerk enters the statistics office's report of a duplicate registration, with the file as evidence |
| `dispatch_confirm` (one outcome: confirmed, with when and the receipt, or failed, with the reason; a second is `Conflict`) | `dispatch.confirm` | delegable | The clerk confirms the gazette published the ordinance, bulletin 214 |
| `dispatch_list` | `dispatch.confirm` | read, delegable | The outbox: what is queued for delivery |
| `task_schedule`, `task_reschedule`, `task_cancel` | `task.schedule` | delegable | Schedule Bob's lapse for 10 Mar 2028; cancel it when he leaves. A task scheduled under a grant runs only what the grant covers directly, and fails once the grant ends |
| `task_list` | `realm.monitor` | read, delegable | What is scheduled for next month |
| `events` (newest first, and where archived events are kept) | `realm.monitor` | read, delegable | The last 100 audited calls |

A codex may be installed before it is in force: `pending`, installed and checked, until `codex_activate`
names its checksum and makes it active at `at`, or its adopting proposal's `effective_at` does. At most
one codex is `pending` at a time: a second install while one waits is `Conflict`. A hook on
`codex_activate` is the realm's own entry point ([layered codex §3.2](../docs/layered-codex.md#32-four-mechanisms)).

A **revert** restores any earlier codex in the realm's history: `codex_revert` names its checksum, or
none for the one the active codex replaced. A checksum not in the history is `NotFound`; a revert with
nothing to restore is `Conflict`, and so is naming the active codex or a pending one, which are not
earlier codices: a pending codex is activated only by `codex_activate`. A revert filed as a proposal
names the codex it restores, resolved when it is filed, so what is voted on is what runs; a
`proposal_create` carrying a revert that names none is refused with `InvalidArgument`. The restored
codex is `active` again and the one it displaces `reverted`, and a revert never runs
`on_codex_activate`. A GOS reserves its revert operations, so no
legislation can refuse or delay one ([layered codex §1](../docs/layered-codex.md#1-chapters-use-gggs-operations-directly)),
and which rule decides a revert vote is the GOS's: Realms GOS applies the rule recorded with the codex
being restored.

A codex may also be installed as a **release** of a layer: `codex_install` with `Release { source;
version }` installs that release whole, found in the record of one of the realm's active sync sources
(§10), the record that vouches for it; `NotFound` when none lists it. When two active sync sources
list that release with different chapters or calendar, the install is refused with `Conflict`. The
GOS builds the change list from that record. A member files it like any governed call, or as a
`proposal_create` whose action is the call, so anyone with `proposal.create` may propose an install,
and no legislation guard of the follower's own codex runs on that `proposal_create`: the release's
date is the source's legislation's.

A realm **publishes** a release of its own layer with `legislation_release_publish`, governed by the
root: its source id, the version, every chapter's domain and checksum, its calendar's checksum, the
commit it was built from and the date it is in force; `published` is when the publish applies, set by
the realm (for a proposal, when it executes). Every checksum it names is already stored by the realm,
installed or pending (`InvalidArgument` otherwise), so a published release can always be served. A
realm publishes under one source id, the one of its first release, which is not one of the layers it
relays (`InvalidArgument` otherwise), and a version once (`Conflict`): a release is never edited or
removed, and a correction is a new version. `legislation_releases` is the realm's **published
record**: the releases of the layers it relays, top to bottom (the order of the record that vouches
for them), each the release it installed, with its `source`; then its own, oldest first.
`legislation_chapter` returns the bytes of a chapter by its checksum, or none. Both are public:
legislation is public, and the checksum pins the bytes.

Nothing outside the Internet Computer calls a realm, and no realm calls an outside body. An `External`
is such a body. A notice to it is a `Dispatch`, which an operator or a bridge delivers and then gives
one outcome: `confirmed`, with when (`at`, between the dispatch's `queued_at` and now) and the receipt
that proves it, or `failed`, with the reason; a second outcome is `Conflict`. What the body says enters
the realm only through `external_report`, entered by whoever received it, with the evidence. Both write
`Event`s that legislation hooks, so what follows from the date a journal published or an authority
received is legislation's.

A `Task` runs one operation at `at`, with the authority of whoever scheduled it (`scheduled_by`: a
user, a department, the codex), never as the realm's controller, and within the grant it was scheduled
under, if any ([§2](#power-of-attorney)). Every guard and rule runs again when
it does, so a task scheduled under old legislation obeys the legislation in force on its date, and one
that is then refused ends `failed`. The run writes the operation's own `Event`, with origin `task`, which
the task's `event` names; a hook on the operation sees it and reads the origin. There is no `task_run`
operation, and no hook of that name.

### Invariants

- I-EXT-2: A codex can apply only the effects its manifest declares, and cannot weaken a guardrail.
- I-EXT-3: Installing or upgrading codex code requires the realm's trust policy (marketplace
  approval or trusted approvers).
- I-EXT-4: The `Event` log is append-only: no event is edited or deleted. A GOS may move old events
  to archive canisters, as ICRC-3 ledgers do; `events` names them, and each answers `ggg_events` for
  the events it holds.
- I-EXT-5: A task runs with its scheduler's authority (under a grant, [§2](#power-of-attorney)) and
  under the legislation in force when it runs;
  a refused one ends `failed` and changes nothing.
- I-EXT-6: A dispatch is confirmed only by a holder of `dispatch.confirm`, and a report from outside
  enters only through `external_report`: the realm never takes an outside body's word without a
  principal's.

A codex reacts to what happens in the realm (it was installed, a user registered, the realm changed
stage, a user needs a quarter) and answers with operations that the realm applies as itself, with
origin `codex`. Operations it did not declare are refused. A failing codex never fails the call that
triggered it; `codex_status` shows the codex unhealthy until it succeeds again. How a codex is
packaged and run is up to the implementation.

Under `require_marketplace_approval`, code is accepted when its checksum is pinned in
`trusted_approvers` as `sha256:<hex>`, or when the registry it comes from reports it approved by a
trusted approver.

## 12. Realm setup and administration

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `realm_info` | — (public) | read | Agora: `beta`, installed version 0.9.0 |
| `host_install` | `realm.host` (the host only) | | The installer names Alice founder, network `ic`, the registry that lists Agora |
| `host_infrastructure` | `realm.host` (the host only) | | The installer gives Agora its frontend and file registry canisters |
| `setup_state`, `setup_step` | `realm.configure` (founder during `setup`) | delegable | The founder picks codex, token and branding; `setup_step` asks each time for the trust-policy step |
| `setup_launch` | `realm.configure` (founder during `setup`) | | The founder launches: never under a grant, never prepared (I-ID-12) |
| `realm_configure` | `realm.configure` | governed, delegable | Turn on open registration; set the realm's languages |
| `realm_configure_branding` | `realm.configure.branding` | governed, delegable | Logo and primary colour `#1E6B52` |
| `realm_configure_tokens` | `realm.configure.tokens` | governed, delegable | Accounting currency ckUSDC |
| `realm_configure_trust_policy` | `realm.configure.trust_policy` | governed, delegable | Require marketplace approval for new code; during setup it asks each time |
| `realm_register` | `realm.register` | governed, delegable | List Agora in the realm registry |
| `realm_upgrade` | `realm.upgrade` | governed, delegable | Upgrade to release 0.9.1 |
| `realm_monitor` | `realm.monitor` | read, delegable | Cycles 4.2T, memory 310 MB |

A realm is installed by its **host**: the platform that creates its canisters, such as an installer
or a registry. The host is a controller of the canister, or the principal the canister was installed
with (an init argument). Before the founder configures anything, the host calls `host_install` once
with the founder, the network, the registry and whether test features are allowed, then
`host_infrastructure` with the canisters the realm works with. A canister only one GOS uses goes in
`extra`, named `<gos>:<role>`. `setup_state` lists `install` in `todo` until `host_install` has run.

### Invariants

- I-ADM-1: Only the host calls `host_install` and `host_infrastructure`, `host_install` once, and both
  only during `setup`; anyone else gets `Unauthenticated` or `Forbidden`, and a second install or a
  call after launch gets `Conflict`.
- I-ADM-2: During `setup`, only the founder can configure; after `setup_launch`, configuration is governed.
- I-ADM-3: A realm upgrade installs only a release the trust policy accepts: its `sha256:<module_hash>` is pinned, or
  the registry's release wasm has exactly that hash and its namespace is approved by a trusted approver.
- I-ADM-4: `Realm.timezone` is an IANA time zone name, `Area/Location` (up to three parts, such as
  `Europe/Madrid` or `America/Argentina/Buenos_Aires`) or `UTC`. A realm sets its own with
  `realm_configure` and is `UTC` until it does, so `UTC` is the value of a realm that has not yet
  chosen. A realm's setup should ask for a zone. A name of any other shape is refused with
  `InvalidArgument`. It is never taken from another realm, from legislation or from a sync source.
  A quarter of a federation is a realm of its own, and starts from its capital's zone, copied once
  when it joins (`quarter_join_federation`) if it is still on `UTC`, which means it has not chosen; a
  realm that already chose a zone keeps it. After that the zone is the quarter's own (§10).
  Legislation never sets a zone, though its guards may constrain who may change one.

## 13. Private content

Private user data, evidence, sealed bids, credential payloads and department documents are
encrypted on the client before they reach the realm. The realm stores where the ciphertext lives,
its hash, and the keys that let each reader decrypt it, wrapped for that reader.

Keys come from vetKeys, the Internet Computer's threshold key derivation. Content is encrypted
with a data key per **scope**. The scope's managers wrap that data key for each principal who may
read it, using the realm's public key and the principal as the identity (identity-based
encryption). A principal's client then derives its own vetKey, which opens only what was wrapped
for that principal. No canister ever sees a data key or the content.

| Scope | Managed by | Example |
|---|---|---|
| `user:<principal>:…` | that user | `user:alice:address` |
| `dept:<department>:…` | the department's staff | `dept:Health:doc:DOC-1` |
| `realm:…` | the root department's staff | `realm:census-2026` |

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `KeyEnvelope` | `id`, `scope`, `principal`, `wrapped_dek`, `granted_by`, `at` | One scope's data key, wrapped for one principal. | `dept:Health:doc:DOC-1` for `dr-ana`, granted by Health's head |
| `Document` | `id`, `department` → `Department`, `title`, `kind`, `languages` (BCP 47 tags), `ref` (where the ciphertext lives), `hash`, `author`, `at`, `facts` (Json), `public` (the clear content's `ref` and `hash`, once published), `publications` (each a `Publication`: `journal`, `dispatch` → `Dispatch`, `published_at`, `ref`) | A department document. Its key scope is `dept:<department>:doc:<id>`. `kind` (minutes, an ordinance, an award) and `languages` let the realm list what it has and in which language; `facts` is what legislation reads about it when it is shared (its source, whether it was given freely). A published document is `public`: its content in clear, readable by anyone and holding no personal data, and `publications` records where a journal published it. | Health's inspection report `DOC-1`, kind `report`, in `en`, shared with Dr. Ana |

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `crypto_public_key` (the realm's vetKeys public key) | `self.data_manage` | delegable | Alice's client fetches it to wrap her address key for Dr. Ana |
| `crypto_derive_key` (the caller's vetKey, encrypted to a transport key) | `self.data_manage` | confirm | Dr. Ana's client derives the key that opens what was wrapped for her. Prepared by a delegate, it hands over a copy of the key for good, so it waits for her approval |
| `crypto_grant`, `crypto_revoke` (a scope's managers only) | `self.data_manage` | confirm | Alice shares `user:alice:address` with Dr. Ana; revokes it after the visit |
| `crypto_envelope` (the caller's own envelope) | `self.data_manage` | read, delegable | Dr. Ana fetches her envelope for `user:alice:address` |
| `crypto_scopes` (the scopes the caller holds keys for) | `self.data_manage` | read, delegable | Dr. Ana's shared records |
| `crypto_access` (who holds keys for a scope; its managers only) | `self.data_manage` | read, delegable | Alice checks who can read her address |
| `document_store` | `document.manage` | delegable | Health stores the encrypted inspection report; asks each time when it is stored with keys for others |
| `document_share` (with a `recipient`, on a `basis`, with `facts`), `document_revoke`, `document_delete` | `document.manage` | confirm | Health shares the report with Clinic B, basis a public health duty; prepared by a delegate, each waits for the officer's approval |
| `document_publish` (with the clear content's `ref` and `hash`) | `document.manage` | confirm | Health publishes the annual report to everyone; Civil Registry sends the ordinance to the provincial gazette |
| `document_list` (a department's documents, for its staff) | `document.manage` | read, delegable | Health's documents this year |
| `document_get` (the department's staff and key holders; for a published document anyone, signed in or not) | `self.data_view`; — (public) for a published document | read, delegable | Dr. Ana fetches the report's reference and her wrapped key |

A share names its `recipient`, the `User`, `Organization` or `External` the keys are for, and may state
its `basis`: the legal basis and purpose in the realm's own words, the legislation that sets the duty or
task, and whether the data is of a special category. Legislation's rules and guards read them, with the
share's `facts`. Legal bases are documented text, not an enumeration of the model. When the recipient is
an `External`, the wrapped keys are for the principal that delivers to it, the operator or the bridge,
which already handles what it delivers: no trust boundary is added.

`document_publish` makes a document public: it carries the content in clear, its `ref` and `hash`, which
the document's `public` field then holds, and anyone reads the record with `document_get`, signed in or
not. With an `External` journal in `to` it also queues a `Dispatch` to it, whose confirmation fills a
`Publication` with the journal's date and reference. Publication gates nothing: when legislation applies
is its proposal's `effective_at` (I-GOV-5).

### Invariants

- I-PRV-1: The realm never holds private content or an unwrapped data key, only ciphertext
  references, hashes and wrapped keys. One exception: an attribute's `kind` and `value` (§2) are in
  clear, and readable only by the person they belong to (`attribute_list`), by the holders of
  `attribute.review` while it awaits review (`attribute_pending_list`), by the codex and, once and at
  collection, by the delegate of an approved read ([§2](#pending-actions)); the audit log never holds
  them. A request's `body` or `reply` and a dispatch's `body` that hold personal data carry a
  `Document` reference, encrypted, never text in clear, and a published copy (`Document.public`) holds
  no personal data.
- I-PRV-2: Only a scope's managers grant or revoke its keys, or see who holds them.
- I-PRV-3: A key envelope is returned only to the principal it was wrapped for.
- I-PRV-4: Only a published document's `public` copy is readable without a key, by anyone; its
  ciphertext, and everything else, stays as I-PRV-1 says.

## 14. Permissions

The permission keys, grouped by domain. An implementation may add keys of its own for operations
outside the model.

- Identity: `self.join`, `self.update_public_profile`, `self.update_private_data`,
  `self.change_quarter`, `self.invoice_refresh`, `self.data_view`, `self.data_manage`,
  `self.delegate`, `self.confirm` (every user: approving or declining a pending action), `user.add`,
  `user.edit`, `user.delete`, `user.update_status`, `user.view`,
  `invite.manage`, `identity.submit`, `identity.review`, `attribute.submit`, `attribute.review`,
  `role.assign`, `role.revoke`, `permission.grant`.
- Departments: `org.create`, `org.appoint`, `org.expel`, `org.set_policy`, `org.grant_authority`,
  `org.revoke_authority`, `org.manage_budget`, `org.manage_members`.
- Organizations: `organization.add`, `organization.edit`, `organization.delete`.
- Governance: `proposal.create`, `proposal.vote`, `proposal.manage`, `mandate.create`,
  `mandate.assign_executor`, `contract.create_under_mandate`, `governance.update`.
- Finance: `treasury.view`, `treasury.manage`, `transfer.create`, `transfer.delete`,
  `invoice.refresh`, `tax.manage`, `tax.assess`, `tax.declare`,
  `token.force_transfer`, `token.freeze`.
- Assets: `nft.mint`, `nft.force_transfer`, `nft.freeze`, `credential.sign`, `land.assess`.
- Licensing, procedures and requests: `license.apply`, `license.issue`, `license.revoke`,
  `procedure.define`, `request.file`, `request.decide`.
- Justice: `dispute.create`, `dispute.view`, `dispute.view_all`, `dispute.accept`, `dispute.reject`,
  `dispute.assign`, `evidence.evaluate`, `resolution.draft`, `resolution.issue`,
  `resolution.link_contract`, `resolution.modify_terms`, `resolution.finalize`, `resolution.query`,
  `appeal.allow`, `trade.execute`, `fine.apply`, `access.revoke`, `contract.terminate`,
  `resource.reassign`, `instrument.lock`, `notification.send`, `enforcement.escalate`,
  `enforcement.record`.
- Procurement: `tender.manage`, `bid.submit`, `bid.evaluate`.
- Federation: `quarter.sync` (held by registered quarter canisters), `quarter.register`, `quarter.deregister`, `quarter.configure`, `quarter.secede`,
  `quarter.join_federation`, `federal_vote.propose`, `federal_vote.manage`, `realm.register`.
- Links between realms: `sync_source.manage`, `follower.manage`, `link.sync` (held only by the capitals at the other side of the realm's links: nobody grants it, and `all` does not include it).
- Codex: `codex.install`, `codex.uninstall`, `codex.revert`, `legislation.publish`.
- Outside bodies and tasks: `external.manage`, `external.report`, `dispatch.confirm`, `task.schedule`.
- Private content: `document.manage`.
- Administration: `all`, `realm.host` (the host's alone: `all` does not include it), `realm.upgrade`, `realm.configure`, `realm.configure.branding`,
  `realm.configure.infrastructure`, `realm.configure.tokens`,
  `realm.configure.trust_policy`, `realm.data_view`, `realm.monitor`.

There is no permission for raw database writes: everything is an operation.

**Signing permissions** (held by agents and delegated only as the codex's
[signing policy](#signing-policy) allows): `identity.review`, `attribute.review`,
`credential.sign`, `license.issue`, `license.revoke`, `dispute.accept`, `dispute.reject`,
`evidence.evaluate`, `resolution.issue`, `resolution.finalize`, `resolution.link_contract`,
`resolution.modify_terms`, `appeal.allow`, `fine.apply`, `access.revoke`, `contract.terminate`,
`resource.reassign`, `instrument.lock`, `trade.execute`, `nft.force_transfer`, `nft.freeze`,
`token.force_transfer`, `token.freeze`, `bid.evaluate`, `land.assess`.

## 15. Cross-cutting invariants

- I-ALL-1: Every operation enforces its permission and invariants the same way whoever calls it: a
  user, a delegate, an agent, a codex or a replayed proposal.
- I-ALL-2: Guardrails, the rules behind the invariants marked "Guardrail", cannot be weakened by
  governance, codices or anything an implementation adds.
- I-ALL-3: Nobody decides a matter they filed, that was filed on their behalf, or in which a
  department or organization they hold an appointment in is a party.
- I-ALL-4: Every update operation is audited with the caller, the grantor (if delegated), the delegate
  that prepared it (if approved from a pending action) and the outcome.
- I-ALL-5: Personal data never appears in clear text in public state, NFT metadata or the event log.
- I-ALL-6: An operation that fails changes nothing.
- I-ALL-7: A `signing` act records who signed, whether they acted as an agent, their supervisor, the
  grantor when delegated and the delegate that prepared it when approved from a pending action, in
  its `Event` and, for an NFT, in the token's header.

## 16. Decisions

| # | Decision | Outcome |
|---|---|---|
| D1 | Merge `Member` and `GuestUser` into a `User.status` | Rejected: both entities stay |
| D2 | Replace `UserProfile` + `Permission` with a single `Profile` | Rejected: both entities stay |
| D3 | Collapse `Realm`'s columns into Json groups | Rejected: the columns stay, and so do `Calendar` and `Registry` |
| D4 | Replace `LedgerEntry`'s source foreign keys with one `subject` reference | Rejected: the foreign keys stay |
| D6 | Use Internet Computer conventions where the model meets Candid: nanosecond times, `principal`, typed errors, variant statuses, cursor pagination | Accepted |
| D7 | Expose every operation through one generic entry point that takes a name and untyped arguments | Rejected: each operation is a typed Candid method in `ggg.did` |
| D8 | Make extensions part of the model | Rejected: extensions are a Realms GOS feature. Any implementation may add callers of its own, under I-ALL-1 and I-ALL-2 |
| D9 | Forbid agents from signing, as a guardrail | Rejected: the active codex's signing policy decides, defaulting to non-agents only; every signing act records who signed and how (I-ALL-7) |
| D10 | Split GGG into separately adopted standards (GGG-1, GGG-2, …) | Rejected: one GGG, one interface, one version. A realm may hold nothing in a domain; its operations then answer with empty lists and ordinary errors |
| D11 | Leave encrypted content to implementations | Rejected: key envelopes and documents are model entities (§13), with keys from vetKeys |
| D12 | Sessions of a collegiate organ as entities, with operations to open and close one | Rejected: a proposal's `opens_at` and `deadline` are the session |
| D13 | Holidays as realm data | Rejected: they stay in the codex, beside its chapters |
| D14 | Outside bodies as registry entries, or as realms | Rejected: an `External` with a `Dispatch` outbox, confirmed by an operator or a bridge; what they say enters through `external_report` |
| D15 | What a proposal's `threshold` means under a department's m-of-n policy | Decided 8 Nov 2026: it states the rule that decides the proposal and is applied, with one comparison per scope: a realm-wide proposal's yes votes *exceed* the threshold of its basis (votes cast, or all eligible members), a department's *reach* it over its policy's n (D20) (m of n is m/n rounded down: 2 of 3 is 66 666 666); the proposer may only tighten the rule, and the casting vote is the realm's, for a realm-wide proposal only, set by governed configuration (I-GOV-3). Amended 10 Nov 2026 (D31): a department whose policy counts the votes cast takes a majority of them, its yes votes *exceeding* 50 % of the yes and no votes, and its head's casting vote decides a tie in a second vote; under an m-of-n policy the comparison and the absence of a casting vote stay as decided |
| D16 | Personal data in attributes, requests, dispatches and published documents | Decided 8 Nov 2026: an attribute's kind and value are in clear, readable only by the person, the reviewers and the codex; a request's or dispatch's personal content is an encrypted `Document` reference; a published copy holds no personal data (I-PRV-1) |
| D17 | The majority of a proposal that a governed call files | Decided 8 Nov 2026: the scope's default rule; legislation that needs more requires a proposal of its own and may refuse the direct path with a guard (I-GOV-3) |
| D18 | Which vote may carry a governed call on another department's record | Decided 8 Nov 2026: a realm-wide proposal carries any call; a department's only a governed call whose governing department is that department or one below it, checked at creation and again when the action executes (I-GOV-13) |
| D19 | Which department governs a change of parent, `department_delete`, `fund_create` and `budget_propose` | Decided 8 Nov 2026: a change of `parent` is governed by the lowest department that is, or is above, both the old and the new parent (an unknown new parent is `NotFound`), and every other edit by the department itself; `department_delete` by the parent, the root for a top-level department, never the root (`InvalidArgument`) nor a department that owns a fund (`Conflict`); creating an owned record, `fund_create`, by the owner named; `budget_propose` by the owner of the `fund` it names, or by the root when it names none and proposes every fund's lines; its lines are fixed when it files (`proposed`, with the proposal), a later one takes only `draft` lines, its totals are the sums over the lines it proposes, and `budget_extend` and the replacement of extended lines are per fund (§1, §3, §5) |
| D20 | What a department's threshold is measured against | Decided 8 Nov 2026: the policy's n, fixed when the vote opens (`tally.seats`), not the seats filled: the default needs exactly m yes votes whatever the vacancies, a stricter threshold t the next whole number at or above t·n, a direct policy one yes; the seated members (`tally.eligible`) drive the quorum and the end at which everyone has voted, so a vacancy never makes a vote easier (I-GOV-3). Amended 10 Nov 2026 (D31): a department whose policy counts the votes cast measures its threshold against the yes and no votes and its quorum against the policy's n, so there too a vacancy never makes a vote easier |
| D21 | Power of attorney by groups | Decided 8 Nov 2026: a grant names plain-language groups of operations ([`delegation.json`](../delegation.json)), not permissions, so a member reads what they hand over and every GOS and client show the same words; every operation has a tier, and an operation asks each time only if acting without the member would decide where their money or identity points, hand lasting power or keys to someone with no vote to follow, be their personal consent or signature, or take effect at once and be hard to undo; a grant made before groups keeps covering exactly what it did; limits are checked at use ([§2](#power-of-attorney)) |
| D22 | How a delegate proposes a codex install | Decided 8 Nov 2026: as a `proposal_create` whose action is the `codex_install` call, which carries an action and so asks each time: the member approves the exact release before the realm votes. A member who holds `codex.install` may also let a delegate call `codex_install` itself: under `setup` during setup, direct; under `admin` after launch, a governed call filed as a proposal tied to the grant (I-ID-10). No new rule: the tiers decide |
| D23 | How a progressive tax is rounded | Decided 8 Nov 2026: the exact total over all brackets is rounded once, an exact half away from zero, to the nearest cent (a multiple of 10^(decimals − 2) smallest units); never bracket by bracket (§5) |
| D24 | What replaces a fund's extended lines, and what an adopted budget allows | Decided 9 Nov 2026: an adopted budget that replaces a fund's extended lines makes them `amended`, so a category it dropped does not come back at the next extension (`closed` keeps meaning closed with its period); `budget_extend` carries what stood at the previous period's end, adopted, extended or closed with it, leaving out a category the new period holds as the other kind; once a fund has an adopted budget for a period, a transfer from it in a category with no adopted expense line is refused (`Conflict`), a transfer with no category counting as `transfer`, while a fund with only extended lines, or none, spends as before, and the ledger's fee for a payment is exempt; within a fund and period a category is either revenue or expense, a draft of the other kind `InvalidArgument` (§5) |
| D25 | What `codex_revert` restores | Decided 8 Nov 2026: any earlier codex in the history, named by its checksum, or the one the active codex replaced when none is named (`opt CodexRevertArgs`, so existing callers keep working); a revert filed as a proposal names the codex it restores; the active or a pending codex is not an earlier one (`Conflict`); never `on_codex_activate`; which rule decides the vote is the GOS's (§11) |
| D26 | The pending action's hash | Decided 8 Nov 2026: opaque. The GOS computes it over at least the realm, the id, the call, the grantor, the delegate, the grant and the expiry, in a canonical form of its own, with sha256 or a stronger hash; a client sends it back unchanged, so GGG fixes no encoding and each GOS keeps its own ([§2](#pending-actions)) |
| D27 | One generic call for a delegate | Decided 8 Nov 2026: `call_for`, and its query twin `read_for`, take a method's name and Candid-encoded arguments with `on_behalf_of`, and reply the method's own reply, the proposal a governed call filed, or the pending action a `confirm` call became; a refusal is the outer `Err`, so callers have one error path. Few argument records carry `on_behalf_of`, and a field cannot be added to the others without breaking their signatures. D7 stands: every operation keeps its typed method, and the generic call is the delegate's path alone |
| D28 | A call in its confirm form through its own method | Decided 8 Nov 2026: a `confirm` operation, or a `direct` one whose condition holds, called through its own method with `on_behalf_of` is refused with `Forbidden` and a message that says to file it through `call_for`. The method's own reply type has no place for a pending action, and adding one to every such method's reply would break their signatures |
| D29 | How a reviewer reads a pending attribute | Decided 8 Nov 2026: `attribute_pending_list`, a read under `attribute.review`, lists the attributes awaiting review with kind and value in clear, consistent with I-PRV-1, paged by id so that deciding a page skips none; a holder of `attribute.review` on a scope reads and decides only the attributes in it, scope `kind:<kind>` for the kinds that body certifies, and held without a scope every pending attribute of the realm, `attribute_pending_list` and `attribute_review` applying the same scope; the audit events of `attribute_submit` and `attribute_review` keep the attribute's id, and for a review the decision, never its kind or value (§2) |
| D30 | What the fee exemption covers, and what a second adopted line does | Decided 8 Nov 2026: only the fee's ledger entry, which the GOS books itself in the category `ledger_fee`, is exempt from an adopted budget; `ledger_fee` is reserved, a `transfer_create` or `budget_draft` naming it `InvalidArgument`, budget or not, so no proposal or extension carries one; a later adopted line of the same fund, period and category amends the earlier one, within one adoption too, where the line drafted later stands, so one line stands per fund, period and category, `budget_extend` carries the newest and the spending booked against the earlier one carries over (§5) |
| D31 | A department that decides by a majority of the votes cast | Decided 10 Nov 2026: a department's policy may count the votes cast (`Policy.threshold_of` `cast`): the yes votes must exceed the no votes, abstentions counting towards the quorum only, with the policy's quorum of its n; a tie gets a second vote on the same proposal, and a tie in that one is decided by the casting vote of the department's `head`, its chair, copied when the vote opens, so a chair who proposed keeps it and an absent chair's tie rejects. The rule is the department's, never legislation's arithmetic: no hook computes it. A proposer may only tighten it: a higher threshold of the votes cast or quorum, or `eligible`, which adds that the yes votes reach the threshold of n (an absolute majority) and keeps the majority of the votes cast and its tie procedure, so no stated rule passes what the default rejects or would put to a second vote. Amends D15 and D20 (I-GOV-3, I-GOV-14) |
