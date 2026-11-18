# Quarters and federation

One part of [the GGG model](../README.md#the-model).

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
| `SweepRule` | `fund`, `symbol`, `into` → `Fund`, `keep` | On the capital, in `Treasury.config.sweep`: each quarter moves its `fund`'s money in `symbol`, all but `keep`, into the capital's fund `into` ([sweeps](#sweeps)). | Every quarter's `GENERAL` REALM into the capital's `GENERAL`, keeping 5,000 |
| `Sweep` | `id`, `quarter`, `fund`, `symbol`, `into`, `to`, `epoch`, `amount`, `fee`, `created_at`, `block`, `status`, `reason`, `reported_at` | One move of one fund's money from a quarter to the capital, kept by both: on the quarter as `id`, on the capital as `<quarter>/<id>`. `to` is the capital's account it is sent to and `block` the ledger's block index; `amount` reaches the capital, `fee` is the ledger's, paid by the quarter. | North's `SW-14`: 182,400 REALM of `GENERAL` for November into the capital's `GENERAL`, block 90,113, `booked` |

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
- `Sweep.status`, on the quarter: `sending` (its ledger transfer is in flight, or its outcome is not
  known) → `sent` (the ledger gave its block) → `booked` (the capital booked it); `sending` →
  `failed` (the ledger refused it: nothing moved) | `needs_check` (no answer within the ledger's
  deduplication window); `needs_check` → `sent` | `failed` (`sweep_resolve`). On the capital a sweep
  is only ever `booked`.

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
| `quarter_sweep` (on a quarter) | `treasury.manage` | delegable | North sweeps now, rather than at the end of its treasury epoch: 182,400 REALM of `GENERAL` to the capital |
| `quarter_sweep_report` (quarter → capital) | `quarter.sync` | | North tells the capital that `SW-14` moved 182,400 REALM in block 90,113; the capital books it into `GENERAL` |
| `sweep_resolve` (on a quarter) | `treasury.manage` | governed, delegable | Finance found `SW-15`'s transfer in block 90,877 after the ledger was down for a day: `sent` |
| `sweep_list` | `treasury.view` | read, delegable | North's sweeps this year; on the capital, every quarter's |

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

### Sweeps

Money paid in a quarter, such as a household's property tax paid in its home quarter, is the
quarter's until it is swept into the capital's funds, where the realm's budget is. The capital decides
what is swept: its `SweepRule`s, set by the governed `treasury_configure` with `sweep` (a realm that
is not a capital refuses them with `InvalidArgument`). A rule is known by its `fund` and `symbol`, the
quarter's fund and token: a capital names each pair once (`InvalidArgument` for two rules on the
same), `into` is one of the capital's funds and `symbol` one of the tokens it registered (`NotFound`
otherwise), and the rules given replace the earlier ones. `quarter_sync` sends the rules to each quarter,
as it sends the zones, together with `to`, the capital's account that receives sweeps; the quarter
keeps the last ones it received.

A quarter sweeps at the end of each of its treasury epochs (`Treasury.config.epoch`), and whenever
`quarter_sweep` asks it to. For each rule, it moves to `to` the fund's balance in `symbol`, as its
books hold it (`Fund.balances`), less `keep` and less the ledger's fee; when that leaves nothing, or the
quarter has no such fund or token, nothing is swept. Each sweep is recorded before any money moves, `sending`, with its `epoch` (the
start of the treasury epoch it belongs to) and its `created_at`. Its ledger transfer is an ICRC-1
`icrc1_transfer` whose `memo` is the sweep's `id` (UTF-8, at most 32 bytes) and whose
`created_at_time` is its `created_at`, fixed, like its `to`, `amount` and `fee`, when the sweep is
recorded. Every attempt sends exactly that transfer, so a ledger that has already applied it answers
with the block it applied it in (`Duplicate`), and the money moves once (I-FED-5).

- **The ledger gives a block:** the sweep is `sent`. The quarter books it and reports it to the
  capital with `quarter_sweep_report`; the capital books it into `into`, once, and the sweep is
  `booked` (I-FED-7). If the capital does not answer, the money is already on its account and only
  its books wait: the quarter reports again at each later sweep until the capital answers.
- **The ledger refuses the transfer** (too little money, a wrong fee): nothing moved. The sweep is
  `failed`, with the ledger's error as its `reason`, and the next epoch sweeps again.
- **The ledger does not answer:** the outcome is unknown. The quarter sends the same transfer again
  at its next sweep, but only while the ledger would still recognise it as a repeat (I-FED-6). Past
  that, the sweep is `needs_check` and is never sent again. A person who has looked at the ledger
  settles it with `sweep_resolve`: the block they found makes it `sent`, none makes it `failed`.

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
([layered codex §1](codex.md#1-chapters-use-gggs-operations-directly)).

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
- I-FED-5: A quarter records at most one sweep per rule and treasury epoch, the one that contains
  the sweep's `created_at`, whether the end-of-epoch timer or `quarter_sweep` asked, and starts no
  sweep for a rule while an earlier one of that rule is `sending` or `needs_check`. A sweep's ledger
  transfer is fixed when it is recorded: every attempt sends the same `icrc1_transfer`, with `memo`
  its `id` and `created_at_time` its `created_at`, so its money moves at most once. `quarter_sweep`
  on a realm that is not a quarter is `Conflict`.
- I-FED-6: A quarter sends a sweep's transfer again only until 23 hours after its `created_at`, an
  hour inside the 24-hour window in which an ICRC-1 ledger recognises a repeat (the reference
  ledger's transaction window). A sweep whose outcome is still unknown then, or that the ledger
  answers with `TooOld`, is `needs_check` and is never sent again. `sweep_resolve`, governed by the
  owner of the swept fund, settles only a `needs_check` sweep (`Conflict` otherwise): with the
  `block` found on the ledger it is `sent`, without one `failed`.
- I-FED-7: A sweep is booked exactly once on each side, linked so the two reconcile: the quarter
  books it when it is `sent`, `amount` out of `fund` in the category `sweep` and `fee` in
  `ledger_fee`; the capital books it when it is reported, `amount` into `into` in the category
  `sweep`. Each entry names the sweep (`LedgerEntry.sweep`), and both sides keep its `block`.
  `quarter_sweep_report` is accepted only from a registered quarter (I-FED-4, else `Forbidden`) and
  only for a `sent` sweep with a `block` (else `InvalidArgument`) whose `into` is a fund of the
  capital (else `NotFound`). A second report of a booked sweep returns the capital's record; one
  that differs from it is `Conflict`. The capital books on the
  registered quarter's word: it does not look the block up on the ledger, so a quarter's report is
  what it books. The quarter's and the capital's money together change only by the ledger's fee, and
  no fund goes below zero: a sweep takes at most what its fund holds above `keep` and the fee.
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
