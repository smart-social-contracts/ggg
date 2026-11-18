# Running a realm

One part of [the GGG model](../README.md#the-model).

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
`codex_activate` is the realm's own entry point ([layered codex §3.2](codex.md#32-four-mechanisms)).

A **revert** restores any earlier codex in the realm's history: `codex_revert` names its checksum, or
none for the one the active codex replaced. A checksum not in the history is `NotFound`; a revert with
nothing to restore is `Conflict`, and so is naming the active codex or a pending one, which are not
earlier codices: a pending codex is activated only by `codex_activate`. A revert filed as a proposal
names the codex it restores, resolved when it is filed, so what is voted on is what runs; a
`proposal_create` carrying a revert that names none is refused with `InvalidArgument`. The restored
codex is `active` again and the one it displaces `reverted`, and a revert never runs
`on_codex_activate`. A GOS reserves its revert operations, so no
legislation can refuse or delay one ([layered codex §1](codex.md#1-chapters-use-gggs-operations-directly)),
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
under, if any ([§2](membership.md#power-of-attorney)). Every guard and rule runs again when
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
- I-EXT-5: A task runs with its scheduler's authority (under a grant, [§2](membership.md#power-of-attorney)) and
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
  collection, by the delegate of an approved read ([§2](membership.md#pending-actions)); the audit log never holds
  them. A request's `body` or `reply` and a dispatch's `body` that hold personal data carry a
  `Document` reference, encrypted, never text in clear, and a published copy (`Document.public`) holds
  no personal data.
- I-PRV-2: Only a scope's managers grant or revoke its keys, or see who holds them.
- I-PRV-3: A key envelope is returned only to the principal it was wrapped for.
- I-PRV-4: Only a published document's `public` copy is readable without a key, by anyone; its
  ciphertext, and everything else, stays as I-PRV-1 says.
