# Land, licences, justice and procurement

One part of [the GGG model](../README.md#the-model).

## 6. Assets: land and NFTs

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Land` | `id`, `x`, `y`, `width`, `height`, `kind`, `owner` (`Entity:id`), `status`, `token_id`, `registered_by`, `assessed_value`, `area` (square metres), `assessed_at`, `assessment_ref`, `metadata` (Json), `zones` → `Zone`* | A parcel, at most 16×16 cells. `zones` are the zones it lies in, such as a planning area (I-AST-6). What an assessor set for taxes based on it, signing for it: its value in the accounting currency and its area, when, and under which reference in the assessor's register. | `L-17`: 3×2 cells at (12, 40), residential, owner `alice`, `LAND` #4412, assessed at 95,000 REALM and 120 m² |
| `Zone` | `id`, `name`, `kind`, `land` → `Land`, `user` → `User`, `population`, `metadata` (Json) | Either a member's own home cell, an h3 index set with `zone_set` and tied to that `user`, or a zone the realm defines with `zone_define`, such as a district without a canister of its own, or a planning area, named by its id: members name a district as their `home_zone`, and `population` counts them; a parcel lies in a planning area by its `zones` (I-AST-6). | Cell `871f1d489ffffff`, Alice's home cell; `riverside` "Riverside", a district, population 1,240 |

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
| `land_zone_set` | `realm.configure` | governed, delegable | Put `L-17`, and the parcels around it, in the Seafront planning area |
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
- I-AST-6: A parcel lies in at most 8 zones, each one the realm defines (`zone_define`) and named once.
  `land_zone_set` replaces the list (`NotFound` for an unknown parcel or zone, `InvalidArgument` for
  more than 8 or a zone named twice), so a plan's area is the parcels that list its zone, and a new
  plan reaches the parcels it covers without touching a licence. A `Zone` has no list of parcels: the
  boundary of a plan is the registry's, and GGG keeps only which parcels it was told lie inside.

## 7. Licensing, procedures and requests

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `License` | `id`, `kind` (court, business, professional, health, education, …), `holder` (`Entity:id`: organization or user), `issued_by` → `Department`, `status`, `applied_at`, `decision_due`, `issued_at`, `expires_at`, `evidence_ref`, `conditions` (Json), `land` → `Land` | Many licences per holder. An application is a licence in `applied`; `decision_due` comes from the `Procedure` of its kind, when one is defined. `land` is the parcel it is for, when it is for one (I-LIC-4). | `LIC-12`: health, holder Clinic B, issued by Health, active until 2028-10-25 |
| `Procedure` | `id` (the licence kind it governs), `initiated_by`, `matter`, `decision_deadline` (a Period), `silence` (`positive` grants, `negative` refuses), `legislation`, `facts` (Json) | How applications of one kind are decided. Legislation acts on the silence, with a task (§11). | `health`: initiated by the applicant, decided within 3 months, silence positive |
| `Request` | `id`, `kind`, `by` (`Entity:id`), `body` (Json), `filed_at`, `due_at`, `extension_limit`, `status`, `decision`, `reply`, `decided_at` | A request to the realm by a person or a body: a petition, a complaint, a request for information or for one's personal data. The kinds are the realm's; legislation sets `due_at` and says what silence means, recording it as a decision. A `body` or `reply` that holds personal data is an encrypted `Document` reference (I-PRV-1). | `REQ-14`: Bob asks for last year's minor contracts, due in one month, `filed` |

### Lifecycles

- `License.status`: `applied` → `active` | `rejected`; `active` ⇄ `suspended`; `active` |
  `suspended` → `revoked` | `expired`.
- `Request.status`: `filed` → `decided`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `license_apply`, `license_renew` | `license.apply` | delegable | Clinic B applies for a health licence with its dossier; Alice applies for a building licence for `L-17` |
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
- I-LIC-4: A licence may be for a parcel: `license_apply` names the `land`, which must exist
  (`NotFound`), and a licence's `land` never changes. The decision on it sees the parcel's `zones` as
  the derived fact `zones` of `license_decide` (none when it names no parcel), so legislation of the
  `planning` domain can refuse or condition the decisions on a plan's parcels, for as long as the plan
  says (its dates are the chapter's), and `license_suspend` and `license_revoke` stay as they are.

`license_apply` sets the licence's `decision_due` from the `Procedure` of its kind, when one is defined.
What silence past a deadline means is legislation's: a procedure says it, and a task (§11) scheduled for
the deadline records it, as `license_decide` or `request_decide`.

Regulatory reports from licensed providers are department documents ([§13](running.md#13-private-content)) or
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
| `Tender` | `id`, `title`, `description`, `requester` → `Department`, `kind`, `procedure`, `estimated_value`, `status`, `opens_at`, `closes_at`, `rubric` (Json: criterion and `weight`), `notices` (each a `Notice`: `journal`, `published_at`, `ref`), `lots` (each a `Lot`), `winner` → `Bid`, `contract` → `Contract` | Weights are in hundred-millionths and add up to 100 000 000. `kind` (works, supplies, services) and `procedure` are the realm's words. `notices` records where the tender was published, and legislation reads `published_in`, the journals of the notices, as a fact of `tender_award`. A tender with `lots` is awarded lot by lot; its `winner` and `contract` are then empty, and each lot has its own (I-PRC-5). | `T-5` Bike lane works, by Infrastructure, works by open procedure, 600,000 REALM estimated, open 1–30 Nov, rubric: price 60%, quality 40%, noticed in the realm's journal |
| `Lot` | `id`, `title`, `estimated_value`, `status` (`open`, `awarded`, `void`), `winner` → `Bid`, `contract` → `Contract` | One part of a tender, awarded on its own, kept in the tender's `lots`. `id` is the realm's own word for it (`1`, `A`, `north`), named once in the tender; the model gives a lot no classification of its own, since what a lot is belongs to its `title` and to the legislation that reads it. | `T-5`'s lot `2`, the bike racks, 40,000 REALM estimated, awarded to BuildCo, contract `C-10` |
| `Bid` | `id`, `tender` → `Tender`, `vendor` → `Organization`, `submitted_at`, `sealed`, `payload_ref`, `payload_hash` (`sha256:` of `price:nonce`), `price` (set at the reveal), `score`, `lot` | Content is encrypted until the reveal. A bid prices one lot, when the tender has lots (I-PRC-5). | BuildCo's bid on `T-5`, sealed until 30 Nov; on `T-6`, its bid for lot `2` |
| `BidScore` | `id`, `bid` → `Bid`, `evaluator` → `User`, `criterion`, `score`, `scored_at` | | Carla scores BuildCo's quality 8/10 |

The `Event` log records a tender's transitions, and a vendor's record is derived from the tenders
it was awarded.

### Lifecycle

`Tender.status`: `draft` → `open` → `closed` → `evaluation` → `awarded` → `contracted`;
`draft` | `open` → `cancelled`; a tender with lots goes from `evaluation` to `awarded` or `cancelled`
once no lot is `open`, and on to `contracted` as its awarded lots are contracted (I-PRC-5).
`Lot.status`: `open` → `awarded` | `void`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `tender_create`, `tender_open`, `tender_close`, `tender_cancel` | `tender.manage` | governed, delegable | Infrastructure drafts `T-5`, then opens it |
| `tender_list`, `tender_get` | `realm.data_view` | read, delegable | Open tenders |
| `tender_notice` (in an `External` of kind `journal`, or `realm` for the realm's own; `at` defaults to now and is never in the future) | `tender.manage` | delegable | Infrastructure records that `T-5`'s notice appeared in the realm's journal |
| `bid_submit`, `bid_withdraw` | `bid.submit` | delegable | BuildCo's agent submits an encrypted bid on `T-5` |
| `bids_reveal` | `tender.manage` | governed, delegable | After 30 Nov the 4 bids are decrypted |
| `bid_score` | `bid.evaluate` | signing, confirm | Carla and two colleagues score each bid |
| `tender_award` | `tender.manage` | signing, governed, confirm | Award `T-5` to BuildCo (score 86) → contract `C-9`; award lot `2` of `T-6` to its best-scored bid |
| `tender_lot_void` | `tender.manage` | governed, delegable | Lot `3` of `T-6` drew no acceptable bid: it is left void |

### Invariants

- I-PRC-1: Sealed bid contents are unreadable by anyone, including the requester, until `bids_reveal`
  after `closes_at`.
- I-PRC-2: No evaluator scores a bid from an organization they hold an appointment in. (Guardrail.)
- I-PRC-3: The award goes to the best-scored bid under the published rubric, or the deviation is
  justified and recorded.
- I-PRC-4: Bids are accepted only between `opens_at` and `closes_at`.
- I-PRC-5: A tender is one procurement, or is divided into lots, which `tender_create` names in
  `lots`: at most 64, each with an `id` named once in the tender, a `title` and an optional
  `estimated_value` (`InvalidArgument` otherwise). A bid prices one lot, so a vendor bidding on
  three lots submits three bids: `bid_submit` names the `lot` when the tender has lots and names
  none when it has none (`InvalidArgument`). Each lot is awarded on its own: `tender_award` names
  the lot and, as I-PRC-3 says, goes to the best-scored revealed bid of that lot, so lots of one
  tender may go to different vendors; a `bid` it names must be a bid of that lot
  (`InvalidArgument`). `tender_lot_void` leaves a lot with no award, for lack of a bid or of an
  acceptable one. Both need the tender in `evaluation` and the lot `open`, else `Conflict`. A lot's
  contract may be made once the lot is `awarded`: `contract_create` names the tender and the `lot`
  (`Conflict` for a lot that is not awarded, or for a second contract), and names a lot only with
  its tender (`InvalidArgument`). Once no lot is `open`, the tender is `cancelled` if every lot is
  `void`, else `awarded`, and `contracted` once every awarded lot has its contract. With lots, the
  tender's own `winner` and `contract` stay empty and each `Lot` holds its own. The model holds no
  classification code or portal field of a lot: a realm that needs one keeps it in an extension,
  keyed by the lot.
- I-PRC-6: A contract may be a call-off under a framework agreement that another body holds, so that
  a realm buys under an agreement it did not tender: `framework` on `contract_create` names a
  `holder`, an `External` of this realm (a province, a ministry) or another realm, by its capital; a
  `reference`, the agreement's number or title in the holder's own words or, for a realm, the
  tender's id there (1 to 128 code points, else `InvalidArgument`); and its `winners`, the ids of
  this realm's organizations that the agreement was awarded to, at most 32 (`InvalidArgument` for
  more), empty when the realm does not know them. The realm checks what it holds: an `External`
  holder is one it knows (`NotFound` otherwise); a realm holder is not the realm itself, whose own
  tender is the contract's `tender` (`InvalidArgument`); and, when `winners` is not empty, one of
  the contract's parties is an organization among them (`InvalidArgument`). It does not check, and
  cannot, what only the holder knows: that the agreement exists, that it is in force and covers this
  purchase, that its ceiling is not reached, that the winners listed are the holder's. `framework`
  is the claim of the realm that made the contract, which a reader or a codex guard weighs against
  the holder's own records. It adds no payment rule: the contract's `value` bounds its payments
  (I-FIN-11). The framework is set when the contract is made and `contract_amend` never changes it.
