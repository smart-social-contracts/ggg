# Members, departments and organizations

One part of [the GGG model](../README.md#the-model).

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
  ([§11](running.md#signing-policy)) lets a codex make a signing permission direct instead; by default none is.
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
| `Organization` | `id` (name), `description`, `status`, `admins` → `User`*, `kind` (`company`, `party`, `union`, `association`, `other`) | An external party. Its admins manage its representatives. `kind` tells a party or a union from a company (I-ORG-9). | Clinic B: `active`, admin `dr-ana`, `company`; the Harbour Party: `party` |
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
| `appoint`, `appoint_acting`, `appointment_end` | `org.appoint` | governed, delegable | Appoint Carla planning officer; Bob acts as clerk while Dana is on leave. During setup an appointment asks each time |
| `department_expel` | `org.expel` | governed, delegable | Expel a member from Infrastructure after a misconduct verdict |
| `authority_grant`, `authority_revoke` | `org.grant_authority`, `org.revoke_authority` | governed, delegable | Finance grants Infrastructure spending on `ROADS`; during setup `authority_grant` asks each time |
| `organization_register` | `organization.add` | delegable | Dr. Ana registers Clinic B, a `company`, and becomes its admin |
| `organization_edit` | `organization.edit` (its admins) | delegable | Clinic B updates its description and adds an admin; a residents' group registered as `other` becomes an `association`; asks each time when it changes the admins |
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
- I-ORG-9: An organization's `kind` is `company`, `party`, `union`, `association` or `other`, which is
  every organization that is none of the four. `organization_register` sets it, `other` when none is
  given, and `organization_edit` changes it like the organization's other fields. An organization
  registered before kinds existed reads `other` until an edit sets it. `organization_list` filters by
  it. The kind is what the organization declares; the realm does not check it, so legislation that
  treats a party differently should not take it as proof.
