# What GGG provides for a layered codex

A realm's legislation can come from several sources at once: the bodies above it, a body beside it,
and its own. Realms GOS runs such legislation as a **layered codex**: one Python chapter per source
and domain, each pinned by checksum, installed by vote and switched all at once. The layered codex
itself (its layout, marks, change list, install task, revert floor and official journal) belongs to
Realms GOS and is documented there:
[The layered codex](https://github.com/smart-social-contracts/realms-gos/blob/main/docs/codices/layered-codex.md).

This page is the other half: what the GGG model provides so that any GOS can run one. Chapters use
GGG's operations directly, so most of what they need is already in the model. The rest is a list of
additions, each with its issue. Nothing here is specific to Realms GOS; another GOS that implements
these additions can run the same chapters.

The word is **legislation**, in the model, the Candid interface and the docs.

---

## 1. Chapters use GGG's operations directly

There is no catalogue of "slots" between a codex and GGG. A chapter's members are named after GGG
operations, and GGG's arguments, events and entities are the whole interface:

| Kind | Name | Runs | Gets | Returns |
|---|---|---|---|---|
| hook | `on_<operation>` | after GGG has done the operation | the operation's `Event`: user, args, result, time | nothing; queues GGG operations as effects |
| guard | `check_<operation>` | before the operation | the operation's args | allow, or a refusal with a reason |
| compute | `compute_<operation>` | during the operation, when GGG asks | what the operation passes (for `tax_assess`: an entry and a subject) | what the operation asks for (for `tax_assess`: invoice items) |
| forbid | a Cedar rule on `<operation>` | before the operation, by the Cedar engine | the operation's args as **facts** | forbid |

- **Facts are arguments.** A forbid's facts are the operation's arguments, as the model defines them;
  a Cedar action is named after the operation (`tax_policy_propose`). The model's fact schema types
  each argument, so a GOS can validate the generated Cedar.
- **Effects are operations.** A hook changes nothing itself. It queues GGG operations, which the GOS
  runs as the realm, under the same permissions as any caller.
- **Entity reads are read-only.** A chapter may read entities (`Member`, `Land`, `TaxPolicy`); it
  never writes one.
- **Reserved operations.** `sync_source_remove` (§4) may not be forbidden, guarded or hooked by any
  codex, so no legislation can stop a follower from leaving. A GOS reserves its own revert operations
  the same way.

The two entry points of a realm's own legislation are ordinary members of these kinds:

- `on_codex_activate`: the hook on `codex_activate` (§3.2). It runs once per realm when a codex
  becomes active, not once per quarter, and not on a revert.
- `compute_realm_join`: asked during `realm_join` for the quarter a new member goes to.

---

## 2. The domain list ([ggg#1](https://github.com/smart-social-contracts/ggg/issues/1))

A **domain** is a subject of legislation, such as `tax` or `water`. (It is not one of the sections of
the model.) The list of domains is [`domains.json`](../domains.json): for each domain, its `id` and a
one-line `description`. A chapter is one source's legislation in one domain, so the domain ids are the
chapter file names.

| Domain | What its legislation covers |
|---|---|
| `realm` | The realm's own entry points and settings: joining, activating a codex, its quarters. |
| `tax` | Taxes, their rates, exemptions and assessment. |
| `procedure` | Administrative procedure: deadlines, silence, notices and working days. |
| `register` | Registers of residents and others that the realm keeps, and who is told of an entry. |
| `local_regime` | How local government works: its organs, ordinances and public comment. |
| `water` | Water supply, sanitation and their tariffs. |
| `data_protection` | Personal data: the legal bases for sharing it and the duties that follow. |
| `language` | Official languages, and the languages of documents and services. |
| `treasury` | Budgets, funds, the allocation of revenue and payments. |
| `federation` | Relations with other realms: sync sources, followers and quarters. |

Later: `immigration`, `education`, `social_security`, `defense`, and so on.

- **An id** is lowercase letters and underscores, starting with a letter (`data_protection`), so it is
  a file name and, in CamelCase, a class name (`DataProtection`).
- **The list has GGG's version, none of its own.** One GGG, one version: `domains.json` is released
  with the model, `ggg.did` and the conformance suite as a tag of this repository (`v0.1.0`). A tool
  that reads the list names the GGG version it read it from.
- **The list only grows.** An id is never renamed, reused or removed, because chapters are named after
  it. Adding a domain is a minor release; rewording a description is a patch.
- **A chapter's domain must be in the list.** The tools that read a codex refuse a chapter in any other.

---

## 3. What real legislation needs ([ggg#2](https://github.com/smart-social-contracts/ggg/issues/2))

Writing real municipal and regional legislation as chapters found entities, fields and operations the
model lacks. Each is added at the scope below; some are narrowed, and some stay in the codex.

### 3.1 Entities, fields and operations

**Added as proposed:**

- a proposal's **kind, matter and majority basis**. A majority is a property of the proposal, not a
  forbid on `proposal_finalize`;
- **outside bodies**: `External` parties with a `Dispatch` outbox. An outside body is not a realm; a
  dispatch to it is a plain notice that gates nothing;
- **scheduled operations**;
- a forbid that **ranges over a list** (§3.2);
- the codex **computes each amount** (§3.2);
- a codex **installed before it is in force** (§3.2);
- **certified attributes** on a person;
- **typed tax entries**: a saved `TaxPolicy` holds a `taxes` list, so a forbid on `tax_policy_propose`
  can range over the policy's entries. The same forbids run when a draft is saved with
  `tax_policy_draft`;
- **invoice items**;
- a contract's and a tender's **kind**;
- **requests**, and the **access-to-information request**;
- **publication in an outside journal**: a dispatch, which gates nothing;
- **reports from outside**;
- an identity's **kind, category and expiry**;
- a document's **kind and languages**; the **languages of a realm and of a user**;
- a **district without a canister**: `Zone`, and `User.home_zone`;
- a procedure's **deadline and silence**. A deadline is a `Period` (§3.3), not a `Duration`.

**Narrowed:**

- an **assessed value**, with an area beside it;
- **borrowing** (lower priority);
- the **basis and facts of a share** of personal data: `basis {legal_basis, purpose, legislation,
  special_category}`, `recipient` (a reference to any entity) and `facts`. Legal bases are documented
  text, not an enumeration of the model;
- **budget totals and years**: totals, `years`, `budget_extend` and `ReportIssueArgs.adjustments` are
  added; the stability report and `net_lending` stay codex conventions.

**Not added:**

- an **incident** entity: folded into requests and outside bodies;
- **sessions of a collegiate organ**, with operations to open and close one: a proposal's `opens_at`
  and `deadline` already are the session;
- **holidays**: they stay in the codex, as a `calendar.json` beside the chapters;
- **record facts** (population, capital status and the like): the links between realms are their own
  addition (§4), and the world facts stay in the codex as settings of the realm's own layer. GGG is
  not a general data store.

No layer of legislation names a department of a lower layer.

### 3.2 Four mechanisms

- **The `compute_<operation>` hook kind.** During an operation, GGG asks the codex for what it cannot
  know itself: the invoice items of each subject of a tax entry, the quarter of a new member. The
  operation passes its inputs and uses what comes back.
- **A forbid that ranges over a list.** `tax_policy_propose` carries only a policy id; the rule
  concerns each entry of the saved policy. The forbid is evaluated once per element, with the element's
  fields as facts, and the Cedar engine sees one request per element.
- **`CodexStatus` `Pending` and `codex_activate`.** A codex can be installed, checked and ready
  before it is in force: `Pending`. `ggg_codex_activate { codex; at }` makes it active, and its hook
  `on_codex_activate` is the realm's own entry point (§1). With `effective_at` on proposals (§6) the
  switch happens at the proposal's time, so no chapter needs to call `codex_activate`; `Pending` is
  what the install uses while it waits.
- **`check=` on a setting** is a feature of the GOS's codex library, not of GGG.

### 3.3 The fact schema: units, rates, money and periods

- **A fact's unit is declared by its schema entry,** never by a suffix in its name: `rate`, not
  `rate_bp`.
- **Every ratio is an integer in hundred-millionths:** 100 % is 100 000 000, 1 % is 1 000 000 and
  0.123456 % is 123 456. One scale covers tax rates, quorum, thresholds, shares and weights alike.
  Integers inside, decimals for people: a GOS shows `0.123456 %`, and a chapter writes a rate as the
  legislation does. Integers because there is one form for every value, so checksums are stable;
  nothing is parsed; and Cedar compares integers natively, while its decimal type has only four digits
  after the point. The model's ratio fields ([conventions](../model/README.md#1-conventions)) are
  on this scale since [ggg#9](https://github.com/smart-social-contracts/ggg/issues/9), a breaking
  change.
- **Money is rounded by one rule:** wherever money is computed from a rate, the result is rounded to
  the nearest cent, and an exact half is rounded away from zero (2.345 becomes 2.35, and −2.345
  becomes −2.35), as euro legislation requires (Regulation (EC) 1103/97 Art. 5). GGG states it with
  the money kind of its fact schema, so every implementation rounds the same way. Another rule is
  added only when a piece of legislation needs it.
- **A `Period` is a count and a unit:** `PeriodUnit = variant { Day; WorkingDay; Month; Year }`
  (§7 for `WorkingDay`). A deadline is a `Period`, not a `Duration` in nanoseconds: three months is
  three months, whatever the days. Periods compare only within one unit: comparing two units, such as
  45 days against 30 working days, fails closed, with no conversion through the calendar. A codex's
  settings are the GOS's, but their values use GGG's Period units and no others, and no setting shares
  a name with a GGG fact.

---

## 4. Links between realms ([ggg#3](https://github.com/smart-social-contracts/ggg/issues/3))

A realm chooses by vote the realms it takes legislation from, its **sync sources**, and each of them
accepts it by vote. There is no parent, no tier and no national code. This is its own issue, not part
of ggg#2.

| Part | What |
|---|---|
| `Realm.sync_sources` | the realms this one syncs from, each with its link status |
| `Follower` | on a sync source: a realm that syncs from it, with its link status and its last report |
| `sync_source_add`, `sync_source_remove` | the follower's side: ask to sync from a realm, stop syncing from it. `sync_source_remove` is reserved (§1) |
| `follower_accept`, `follower_remove` | the sync source's side: accept a follower, end a link |
| `link_notify` | an operation of ggg#3 between the two sides of a link. The event a sync source's legislation hooks when a follower leaves is named in ggg#3 |
| `follower_report`, `follower_list` | a follower reports what it runs; a sync source lists its followers |
| `ReportedLayer { version; checksum }` | what a follower reports per layer it runs, with its compliance against that source and its population. It does not send the layer's source: the sync source finds the layer by its checksum in its own record |
| `Quarter.compliance` | the same flag on a realm's own quarters |
| `legislation_releases`, `legislation_chapter` | a sync source's published record: its releases, and the releases of every layer it relays; the bytes of a chapter, so a follower can fetch them from the source's capital |
| `follower_compliance` | a fact on operations between realms, such as a transfer to a follower, so a sync source's legislation can test it |

The invariants, in words:

- **A link is active only after both votes:** the follower's vote to add the sync source and the
  sync source's vote to accept it.
- **No cycles:** no realm syncs from itself, directly or through other realms.
- **Calls between realms go between the capitals** of an active link, and nowhere else.

How a follower installs what a sync source relays is the GOS's business, not the model's. Realms GOS
adds three install rules there: a follower checks each layer from above against the record that
vouches for it (the publisher's, or the relaying source's); a release is installed whole; and the
paths from several sync sources must form one chain in each domain.

---

## 5. Proposal links ([ggg#4](https://github.com/smart-social-contracts/ggg/issues/4))

A proposal can link to another: **replaces** (this proposal takes the place of an earlier one) and
**relates to** (a plain reference, both ways). A proposal's action never changes once it exists; to
change a codex change list, the proposer withdraws the proposal and creates a new one that replaces
it, so voters see what the new proposal supersedes and the old one points forward to it.

`Proposal` carries `links : vec ProposalLink`, and `ProposalCreateArgs` takes
`links : opt vec ProposalLink`, so absent means none and callers built before links existed keep
working. A `ProposalLink` is a `kind` (`Replaces` or `RelatesTo`) and a proposal id. The rules:

- Links are fixed at creation, like the action. No operation edits them.
- A link names an existing proposal, once. A `Replaces` target must be a `Withdrawn` proposal filed for
  the same member (the grantor when `on_behalf_of` is set, else the proposer), so withdrawing first
  and replacing second keeps the history honest and nobody can claim another's withdrawn proposal.
  `RelatesTo` has no condition.
- A withdrawn proposal is replaced once: a second `Replaces` of it is refused with `Conflict`. If the
  replacement is withdrawn too, a new proposal replaces the replacement, not the first one: in a
  chain A ← B ← C, `replaced_by` of A stays B.
- A proposal has at most 16 links of its own, so a reply never outgrows the Internet Computer's limits.
  The links to it from other proposals are not limited, and are read a page at a time.
- The other side of a link is readable: `ggg_proposal_get` gives the one proposal that replaces this
  one (`replaced_by`), and `ggg_proposal_linked_from` pages every proposal that links to it, oldest
  first. `Replaces` there reads "replaced by", and `RelatesTo` is a reference both ways.
- Codex guards see `links` as a fact of `proposal_create`, like every argument.

---

## 6. `Realm.timezone` ([ggg#5](https://github.com/smart-social-contracts/ggg/issues/5)) and `effective_at` ([ggg#6](https://github.com/smart-social-contracts/ggg/issues/6))

**`Realm.timezone`** is an IANA time zone name such as `Europe/Madrid`. Each realm sets its own; it
is never inherited from a layer or a sync source. Timestamps stay UTC nanoseconds everywhere; the UI
shows the realm's official time. The name has the shape `Area/Location` (up to three parts), or is
`UTC`, which is also the value until the realm sets one, so a realm's setup should ask for a zone. GGG
holds the name only. Converting to the realm's local day (for a daily journal issue or a working-day
count) is the GOS's job.

**`effective_at`** is an optional UTC timestamp on `ProposalCreateArgs` and `Proposal`: the exact
time the proposal takes effect. It must lie after the time of the call that creates the proposal,
or the call is refused with `InvalidArgument`. The rules:

- Once accepted, the proposal's action executes at that time, not when the vote closes. This holds
  for every kind of proposal: a treasury transfer, a codex install or update, a setting, any call.
  Without it, the action executes on acceptance, as today.
- It is part of what voters approve, so it is fixed at creation like the action. **It never moves
  after acceptance.** If the time proves too early, another proposal stops the scheduled one, and a
  new proposal sets the right date; proposers leave a margin.
- While it waits, the proposal's status is `ExecutionScheduled`, between `Accepted` and `Executed`: a
  proposal with an action, accepted with an `effective_at` still ahead, goes straight on to it, and
  `proposal_execute` is refused with `Conflict` until that time. A motion has nothing to execute: it
  stays `Accepted`, and `proposal_execute` refuses it before and after `effective_at`.
- Another proposal can stop a scheduled one before its time with `proposal_stop`. It is governed by the
  department that owns the scheduled proposal (its scope; the root for a realm-wide one), under that
  department's policy. Under a policy that is not direct, calling it files a proposal of that
  department, so its vote stops the scheduled one; under a direct policy the call applies at once. It
  ends the scheduled proposal as `Withdrawn`, without executing it, and is refused with `Conflict` for
  a proposal in any other status. A stop proposal that runs after its target is no longer scheduled
  ends `Failed`.
- A vote that ends after `effective_at` does not execute: the proposal ends `Expired`, whatever was
  decided, and the proposer submits a new one. A vote ends at its deadline, or earlier at the moment
  every eligible member has voted. The vote of a department under an m-of-n policy may also end as
  soon as it can only be accepted: it has `m` approvals, every veto holder has voted and none of them
  against, and its quorum is met. Only an acceptance ends a department vote this early: until its
  deadline, or until every eligible member has voted, a `no` can still be replaced, even when `m`
  approvals are out of reach, and a veto holder yet to vote keeps it open. The end at which every
  eligible member has voted can still reject, and realm-wide votes are unchanged. When it is
  finalized doesn't matter: a vote that ended before `effective_at` does
  not expire. Finalized before `effective_at` the proposal is scheduled, even if its `deadline` is
  later, and finalized after it the proposal is accepted and its action executes at once. A GOS may do
  that in the same step as `proposal_finalize`, which then replies `Executed` or `Failed`, or settle
  the proposal itself when the vote ends, or leave it `Accepted` for `proposal_execute`; the model
  allows all three (I-GOV-12).
- When several proposals are scheduled for the same moment, no order is specified.
- Codex guards see it as a fact of `proposal_create`, so legislation can require a minimum delay. This
  is how a statutory wait is expressed: for an ordinance, a guard requires `effective_at` to lie at
  least fifteen working days after the vote can close, and the proposer leaves a margin, because the
  statute counts from the authorities' receipt of the communication (§7). The time comes from the
  proposal, never from a publication in a journal or gazette.

---

## 7. The `WorkingDay` unit ([ggg#7](https://github.com/smart-social-contracts/ggg/issues/7))

`PeriodUnit = variant { Day; WorkingDay; Month; Year }`.

A **working day** is a day that is neither a weekend day nor a holiday in **the realm's calendar**,
taken in **the realm's time zone** (§6). Much legislation counts deadlines in working days, and Spain's
does so by default (Ley 39/2015 Art. 30.2): at least thirty working days of public comment on a new
ordinance before the final vote (Ley 7/1985 Art. 49), or an ordinance that takes effect fifteen
working days after the higher authorities receive it (Ley 7/1985 Art. 65.2).

- GGG names the unit only. Realms count it, because counting needs the realm's own calendar of
  weekend days and holidays.
- A realm whose legislation does not use working days never uses the unit.
- A GOS that counts working days fails closed when its calendar has no entries for a year the count
  reaches: a wrong legal deadline is worse than a clear error.
- A Period in working days compares only with another in working days (§3.3). It is never converted
  to calendar days, or the other way round.

---

## 8. Nothing else

The marks (`fixed`, `extension`, `overridable`), the layered codex and its layout, the change list,
the install task and its rules, the revert floor and the official journal belong to the GOS. GGG
provides the operations and events the chapters name, the additions above, and nothing more.
