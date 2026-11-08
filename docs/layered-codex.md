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
  a Cedar action is named after the operation (`tax_policy_propose`). A forbid that ranges over a list
  (§3.2) names the Cedar action `<operation>.<list>` (`tax_policy_propose.taxes`), and its facts are the
  element's fields. The model's fact schema types each argument, so a GOS can validate the generated
  Cedar. A few facts are not arguments: a GOS computes each from its own records when the operation is
  called, deterministically, and the fact schema (§3.3) declares it as `derived`, with what it is:
  `published_in` of `tender_award`, the journals of the tender's notices; `revenue` and `expense` of
  `budget_propose`, the period's totals.
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
model lacks. Each is added at the scope below; some are narrowed, and some stay in the codex. Every
addition is in the [model](../model/README.md) and `ggg.did`; the model's sections say how it behaves.

### 3.1 Entities, fields and operations

**Added as proposed:**

- a proposal's **kind, matter and majority basis**: `Proposal.kind`, `matter`, `threshold_of` (over the
  votes cast, or over every eligible voter) and `casting_vote`. A majority is a property of the
  proposal, not a forbid on `proposal_finalize`: the proposer may state a stricter rule than the realm's
  or the department's, never a weaker one, and a guard on `proposal_create` requires the majority the
  matter needs. A realm-wide proposal's yes votes exceed the threshold of the basis, a department's reach
  it over the eligible seats; the casting vote is the scope's, set by governed configuration, never the
  proposer's. A proposal a governed call files takes the scope's default rule, so legislation that needs
  more requires a proposal of its own and may refuse the direct path with a guard (model I-GOV-3);
- **outside bodies**: `External` parties with a `Dispatch` outbox (`external_add`, `dispatch_confirm`,
  `dispatch_list`). An outside body is not a realm; a dispatch to it is a plain notice that gates
  nothing, confirmed by the operator or bridge that delivered it;
- **scheduled operations**: `Task`, with `task_schedule`, `task_reschedule` and `task_cancel`. A task
  runs with its scheduler's authority, and every guard and rule runs again when it does;
- a forbid that **ranges over a list** (§3.2);
- the codex **computes each amount** (§3.2);
- a codex **installed before it is in force** (§3.2): `CodexStatus` `Pending` and `codex_activate`;
- **certified attributes** on a person: `Attribute`, with `attribute_submit` and `attribute_review`,
  verified as identities are;
- **typed tax entries**: a saved `TaxPolicy` holds a `taxes` list, so a forbid on `tax_policy_propose`
  can range over the policy's entries. The same forbids run when a draft is saved with
  `tax_policy_draft`, whose `taxes` is required (a breaking change of 0.2.0: a draft states its entries;
  the brackets of a progressive tax go in an entry's `facts` and the codex computes each amount);
- **invoice items**: `InvoiceItem`, `Invoice.items` and `facts`, and `invoice_item_add` on a pending
  invoice, so a charge legislation adds joins the same invoice;
- a contract's and a tender's **kind** and **procedure**, a tender's `estimated_value` and `notices`
  (`tender_notice`), and `Contract.tender`; `published_in`, the journals of a tender's notices, is a
  derived fact of `tender_award` (§1);
- **requests**, and the **access-to-information request**: one `Request` entity, with `request_file`,
  `request_set_due` and `request_decide`; the kinds are the realm's;
- **publication in an outside journal**: `document_publish`, a dispatch, which gates nothing; the
  journal's date and reference fill `Document.publications` when the dispatch is confirmed;
- **reports from outside**: `external_report`, entered by whoever received the report, with the
  evidence;
- an identity's **kind, category and expiry**: `Identity.category` and `expires_at`; the standard kinds
  are documented text, and `kind` stays text;
- a document's **kind and languages**; the **languages of a realm and of a user**: `Document.kind` and
  `languages`, `Realm.languages`, `User.language`, and `translations` on `notification_send`;
- a **district without a canister**: a `Zone` the realm defines with `zone_define`, `User.home_zone`
  (stated at join, changed with `user_edit`) and `Zone.population`;
- a procedure's **deadline and silence**: `Procedure`, `procedure_define` and `License.decision_due`. A
  deadline is a `Period` (§3.3), not a `Duration`.

**Narrowed:**

- an **assessed value**, with an area beside it: `Land.assessed_value`, `area`, `assessed_at` and
  `assessment_ref`, set by `land_assess`;
- **borrowing** (lower priority): `Loan`, `loan_create`, `loan_repay` and `Treasury.debt_outstanding`;
  the money moves outside the realm, GGG records the debt;
- the **basis and facts of a share** of personal data: `basis {legal_basis, purpose, legislation,
  special_category}`, `recipient` (a reference to any entity) and `facts` on `document_share`, and
  `Document.facts`. Legal bases are documented text, not an enumeration of the model;
- **budget totals and years**: `budget_propose` proposes a period's lines together, with `years`; the
  totals `revenue` and `expense` are derived facts of the call (§1); `budget_extend` and
  `ReportIssueArgs.adjustments` are added; the stability report and `net_lending` stay codex
  conventions.

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
  fields as facts, and the Cedar engine sees one request per element, on the Cedar action
  `<operation>.<list>` (`tax_policy_propose.taxes`), whose facts are the element's type. The same forbids
  run when a draft is saved, on `tax_policy_draft.taxes`. The element is a `TaxEntry`: `code`, `kind`,
  `subject`, `rate`, `amount` and `facts`; the fact schema (§3.3) lists both actions with those facts.
- **`CodexStatus` `Pending` and `codex_activate`.** A codex can be installed, checked and ready
  before it is in force: `Pending`. `ggg_codex_activate { codex; at }` makes it active, and its hook
  `on_codex_activate` is the realm's own entry point (§1). With `effective_at` on proposals (§6) the
  switch happens at the proposal's time, so no chapter needs to call `codex_activate`; `Pending` is
  what the install uses while it waits.
- **`check=` on a setting** is a feature of the GOS's codex library, not of GGG.

### 3.3 The fact schema: units, rates, money and periods

**The fact schema is [`facts.json`](../facts.json),** released with `ggg.did` and generated from it
(`npm run facts` in `conformance/`; a conformance test keeps the two equal). It has one entry per Cedar
action: every operation, named as the operation, with its facts, which are the operation's arguments as
`ggg.did` types them; and every list of records among those arguments as an action of its own,
`<operation>.<list>`, whose facts are the element's fields (§3.2). `tax_policy_propose.taxes` ranges
over the saved policy's entries, since that operation's own argument is only the policy's id. An
operation whose argument is a single value has one fact, `id`, the record it acts on (`user`, `scope`,
`data`, `transport_key`, `source` or `step` where the value is not an id). Each fact gives its Candid type, whether it is
optional, and what the schema adds: its `kind`, `min`, `max` and allowed `values` (a variant's tags).
The kinds are the named aliases of `ggg.did`:

| Kind | Aliases | Candid | Unit | Range |
|---|---|---|---|---|
| `ratio` | `Ratio`, `Rate` | `nat`, `nat` | hundred-millionths | `Ratio` 0 to 100 000 000 (100 %); `Rate` 0 to 10 000 000 000 (100 times that) |
| `money` | `Money`, `SignedMoney` | `nat`, `int` | the token's smallest unit (Token.decimals) | `Money` 0 to 9 007 199 254 740 991 (2^53 − 1); `SignedMoney` −9 007 199 254 740 991 to 9 007 199 254 740 991, for a discount line |
| `area` | `Area` | `nat` | square metres | 0 to 9 223 372 036 854 775 807 |
| `timestamp` | `Timestamp` | `nat64` | nanoseconds since 1970-01-01 UTC | 0 to 9 223 372 036 854 775 807 |
| `duration` | `Duration` | `nat64` | nanoseconds | 0 to 9 223 372 036 854 775 807 |
| `period` | `Period` | `record { count : nat; unit : PeriodUnit }` | a count of one calendar unit | `count` 0 to 1 000 000; `unit` one of `Day`, `WorkingDay`, `Month`, `Year` |

A `Ratio` is a quorum, threshold, share or weight; a `Rate` is a tax rate or a coefficient, which
legislation takes above 100 %. Every fact has a finite range: a plain `nat`, and a `nat64` outside a
kind, run to 9 223 372 036 854 775 807, the largest Cedar `Long`, so a GOS can always bound arithmetic on
facts (rule 9 of the `F` language). **Ranges are enforced:** a call with a value outside its fact's
range is refused with `InvalidArgument`, and the analysis assumptions rest on that. `TaxEntry.kind` and
`subject` are text, with documented examples and no allowed values in the schema, so a realm names its
own; `TaxEntry.facts` is a `Value`, which a forbid cannot read, so a rule on a fact inside it is a guard.
A fact that is not an argument is marked `derived`, with what the GOS computes it from (§1).

- **A fact's unit is declared by its schema entry,** never by a suffix in its name: `rate`, not
  `rate_bp`.
- **So are its range and its allowed values,** where it has them. A Cedar schema cannot state them, so
  a GOS's analysis tools take them from `facts.json` as assumptions about every request, which hold
  because a GOS refuses a value outside its range.
- **Every ratio is an integer in hundred-millionths** (`Ratio`, and `Rate` above 100 %): 100 % is 100 000 000, 1 % is 1 000 000 and
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
  the money kind of its fact schema (`Money`), so every implementation rounds the same way. Money is
  an integer in the token's smallest unit, so a cent is 10^(decimals − 2) of them and the rounded
  result is a multiple of it; the token's `decimals` is on `Token`, where chapters can read it. Another
  rule is added only when a piece of legislation needs it.
- **A `Period` is a count and a unit:** `PeriodUnit = variant { Day; WorkingDay; Month; Year }`, both
  in `ggg.did` (§7 for `WorkingDay`). A deadline is a `Period`, not a `Duration` in nanoseconds: three months is
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
is never taken from another realm, from legislation or from a sync source. Timestamps stay UTC
nanoseconds everywhere; the UI shows the realm's official time. The name has the shape
`Area/Location` (up to three parts), or is `UTC`, which is also the value until the realm sets one,
so a realm's setup should ask for a zone. GGG holds the name only. Converting to the realm's local
day (for a daily journal issue or a working-day count) is the GOS's job.

**A quarter of a federation** is a realm canister with its own zone, and is the one case where a
starting value comes from elsewhere, and only from inside its own realm:

- A new quarter starts on its capital's zone, copied once when it joins the federation
  (`quarter_join_federation`). Only a realm still on `UTC` takes it; a realm that already chose a
  zone keeps it when it joins as a quarter. After that the zone is the quarter's own.
- The quarter may change it with `realm_configure`.
- The realm may set it by a realm-wide vote: `quarter_configure` on the capital takes a `timezone`
  for the `quarter` it names, which the capital sends to the quarter (`quarter.sync`) and the quarter
  applies. A malformed name is refused with `InvalidArgument` before any vote. `quarter_configure`
  takes a `welcome_message` for the `quarter` it names, in the same way (model §10).
- In a federation, the capital's zone is the realm's official time, and a quarter's zone is its
  local time. Realm-wide counts are made on the capital: a federal vote has one `deadline`, set there
  once as an instant, and every quarter's leg keeps it. Effective times (below) are exact UTC
  instants, so they are the same moment in every quarter.
- Legislation never sets a zone. Its guards (`check_<op>`) may constrain who may change one, like
  those of any governed operation.

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
  soon as it can only be accepted: its yes votes reach its threshold of the eligible seats (`m` under
  the policy's own rule, more under a stricter one the proposer stated), every veto holder has voted
  and none of them against, and its quorum is met. Only an acceptance ends a department vote this
  early: until its deadline, or until every eligible member has voted, a `no` can still be replaced,
  even when the threshold is out of reach, and a veto holder yet to vote keeps it open. The end at which every
  eligible member has voted can still reject, and a realm-wide vote has no such early end. When it is
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

`PeriodUnit = variant { Day; WorkingDay; Month; Year }` and `Period = record { count : nat; unit : PeriodUnit }`
are in `ggg.did`, and the [model's conventions](../model/README.md#1-conventions) define them.

A **working day** is a day that is neither a weekend day nor a holiday in **the realm's calendar**,
taken in **the realm's time zone** (§6; for a matter of one quarter alone, the quarter's). Much
legislation counts deadlines in working days, and Spain's
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
