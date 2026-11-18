# Permissions, invariants and decisions

One part of [the GGG model](../README.md#the-model).

## 14. Permissions

The permission keys, grouped by the part of the model they belong to. An implementation may add keys of its own for operations
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
  `mandate.assign_executor`, `contract.create_under_mandate`, `contract.amend`, `governance.update`.
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
[signing policy](running.md#signing-policy) allows): `identity.review`, `attribute.review`,
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
| D10 | Split GGG into separately adopted standards (GGG-1, GGG-2, …) | Rejected: one GGG, one interface, one version. A realm may hold nothing in a part of the model; its operations then answer with empty lists and ordinary errors |
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
| D21 | Power of attorney by groups | Decided 8 Nov 2026: a grant names plain-language groups of operations ([`delegation.json`](../delegation.json)), not permissions, so a member reads what they hand over and every GOS and client show the same words; every operation has a tier, and an operation asks each time only if acting without the member would decide where their money or identity points, hand lasting power or keys to someone with no vote to follow, be their personal consent or signature, or take effect at once and be hard to undo; a grant made before groups keeps covering exactly what it did; limits are checked at use ([§2](membership.md#power-of-attorney)) |
| D22 | How a delegate proposes a codex install | Decided 8 Nov 2026: as a `proposal_create` whose action is the `codex_install` call, which carries an action and so asks each time: the member approves the exact release before the realm votes. A member who holds `codex.install` may also let a delegate call `codex_install` itself: under `setup` during setup, direct; under `admin` after launch, a governed call filed as a proposal tied to the grant (I-ID-10). No new rule: the tiers decide |
| D23 | How a progressive tax is rounded | Decided 8 Nov 2026: the exact total over all brackets is rounded once, an exact half away from zero, to the nearest cent (a multiple of 10^(decimals − 2) smallest units); never bracket by bracket (§5) |
| D24 | What replaces a fund's extended lines, and what an adopted budget allows | Decided 9 Nov 2026: an adopted budget that replaces a fund's extended lines makes them `amended`, so a category it dropped does not come back at the next extension (`closed` keeps meaning closed with its period); `budget_extend` carries what stood at the previous period's end, adopted, extended or closed with it, leaving out a category the new period holds as the other kind; once a fund has an adopted budget for a period, a transfer from it in a category with no adopted expense line is refused (`Conflict`), a transfer with no category counting as `transfer`, while a fund with only extended lines, or none, spends as before, and the ledger's fee for a payment is exempt; within a fund and period a category is either revenue or expense, a draft of the other kind `InvalidArgument` (§5) |
| D25 | What `codex_revert` restores | Decided 8 Nov 2026: any earlier codex in the history, named by its checksum, or the one the active codex replaced when none is named (`opt CodexRevertArgs`, so existing callers keep working); a revert filed as a proposal names the codex it restores; the active or a pending codex is not an earlier one (`Conflict`); never `on_codex_activate`; which rule decides the vote is the GOS's (§11) |
| D26 | The pending action's hash | Decided 8 Nov 2026: opaque. The GOS computes it over at least the realm, the id, the call, the grantor, the delegate, the grant and the expiry, in a canonical form of its own, with sha256 or a stronger hash; a client sends it back unchanged, so GGG fixes no encoding and each GOS keeps its own ([§2](membership.md#pending-actions)) |
| D27 | One generic call for a delegate | Decided 8 Nov 2026: `call_for`, and its query twin `read_for`, take a method's name and Candid-encoded arguments with `on_behalf_of`, and reply the method's own reply, the proposal a governed call filed, or the pending action a `confirm` call became; a refusal is the outer `Err`, so callers have one error path. Few argument records carry `on_behalf_of`, and a field cannot be added to the others without breaking their signatures. D7 stands: every operation keeps its typed method, and the generic call is the delegate's path alone |
| D28 | A call in its confirm form through its own method | Decided 8 Nov 2026: a `confirm` operation, or a `direct` one whose condition holds, called through its own method with `on_behalf_of` is refused with `Forbidden` and a message that says to file it through `call_for`. The method's own reply type has no place for a pending action, and adding one to every such method's reply would break their signatures |
| D29 | How a reviewer reads a pending attribute | Decided 8 Nov 2026: `attribute_pending_list`, a read under `attribute.review`, lists the attributes awaiting review with kind and value in clear, consistent with I-PRV-1, paged by id so that deciding a page skips none; a holder of `attribute.review` on a scope reads and decides only the attributes in it, scope `kind:<kind>` for the kinds that body certifies, and held without a scope every pending attribute of the realm, `attribute_pending_list` and `attribute_review` applying the same scope; the audit events of `attribute_submit` and `attribute_review` keep the attribute's id, and for a review the decision, never its kind or value (§2) |
| D30 | What the fee exemption covers, and what a second adopted line does | Decided 8 Nov 2026: only the fee's ledger entry, which the GOS books itself in the category `ledger_fee`, is exempt from an adopted budget; `ledger_fee` is reserved, a `transfer_create` or `budget_draft` naming it `InvalidArgument`, budget or not, so no proposal or extension carries one; a later adopted line of the same fund, period and category amends the earlier one, within one adoption too, where the line drafted later stands, so one line stands per fund, period and category, `budget_extend` carries the newest and the spending booked against the earlier one carries over (§5) |
| D31 | A department that decides by a majority of the votes cast | Decided 10 Nov 2026: a department's policy may count the votes cast (`Policy.threshold_of` `cast`): the yes votes must exceed the no votes, abstentions counting towards the quorum only, with the policy's quorum of its n; a tie gets a second vote on the same proposal, and a tie in that one is decided by the casting vote of the department's `head`, its chair, copied when the vote opens, so a chair who proposed keeps it and an absent chair's tie rejects. The rule is the department's, never legislation's arithmetic: no hook computes it. A proposer may only tighten it: a higher threshold of the votes cast or quorum, or `eligible`, which adds that the yes votes reach the threshold of n (an absolute majority) and keeps the majority of the votes cast and its tie procedure, so no stated rule passes what the default rejects or would put to a second vote. Amends D15 and D20 (I-GOV-3, I-GOV-14) |
| D32 | How proposals are grouped and found | Decided 10 Nov 2026: by `tags`, free text in the realm's own words, at most 16 of 1 to 64 code points each, compared exactly and never normalised (clients send NFC), set at creation and replaced while a draft; `proposal_list` filters by any of them. No fixed vocabulary: `kind` and `matter` stay one value each (I-GOV-15) |
| D33 | How a contract changes after it is made | Decided 10 Nov 2026: `contract_amend`, governed by the contract's owner (its mandate's executor, else its tender's requester, else the root), replaces its value, its split over fiscal periods and its dates, keeping its id and everything else; each amendment is a `ContractAmendment` with the terms before and after, the proposal that carried it and when; a terminated or fulfilled contract is not amended, nor its value set below what has been paid on it, no payment takes a contract above its value (I-FIN-11), and `contract_get` reads a contract with its amendments (I-GOV-16) |
| D34 | How a party is told apart from a company | Decided 10 Nov 2026: `Organization.kind`, one of `company`, `party`, `union`, `association` and `other`; no class of its own for a party. `other` is needed: a foundation, a cooperative or a public body is none of the four, and a kind added to the list later would break every reader of `Organization`. Set at registration, changed by `organization_edit`, `other` when absent or older (I-ORG-9) |
| D35 | How spending moves through its stages | Decided 10 Nov 2026: two facts, no new class. A budget line's `reserved` and `committed` money beside `planned` and `actual`, moved by the governed `budget_stage`, with its available credit, `planned - reserved - committed - actual`, never negative: a transfer that would take a line above `planned` is refused, since spending without available credit is void. A transfer is charged when the obligation is recognised, and may be `scheduled`, owed by a due date, paid later with `transfer_pay` and cancelled only by the governed `transfer_revert`. `budget_list` and `transfer_list` read them (I-FIN-9, I-FIN-10) |
| D36 | How money paid in a quarter reaches the capital's funds | Decided 10 Nov 2026: the quarter pushes it. The capital sets the sweep rules by vote (`treasury_configure`: a quarter's fund and token, the capital's fund, what the quarter keeps) and sends them with `quarter_sync`; each quarter sweeps at the end of its treasury epochs, or on `quarter_sweep`, one recorded sweep per rule and epoch whose ICRC-1 `memo` and `created_at_time` are fixed, so a retry never moves money twice; it reports each sweep to the capital (`quarter_sweep_report`), which books it once; both keep its block. An outcome still unknown 23 hours after it was sent, inside the ledger's 24-hour deduplication window, is never resent: the sweep is `needs_check` until a person resolves it (`sweep_resolve`). The capital pulling from each quarter was rejected: it makes the capital call every quarter each epoch, where quarters already push with `quarter_sync` (I-FED-5 to I-FED-7) |
| D37 | How a tender is divided into lots | Decided 11 Nov 2026: a tender may name lots (`Tender.lots`, each with an id the realm chooses, a title and an estimated value); a bid prices one lot (`Bid.lot`), each lot is awarded on its own (`tender_award` names it) or left void (`tender_lot_void`), and each awarded lot yields its own contract (`Contract.lot`), so one tender yields several contracts, to different vendors if the bids say so. Lots are only lots: the model stays neutral about jurisdictions and holds no CPV, portal or other register field; a realm that needs one keeps it in an extension (I-PRC-5) |
| D38 | How a contract is a call-off under another body's framework agreement | Decided 11 Nov 2026: `Contract.framework` names the holder of the agreement (an `External` of the realm, or another realm by its capital), its reference there and, when known, the organizations it was awarded to. The realm checks only what it holds: the holder is known, is not the realm itself, and a party of the contract is among the winners listed; whether the agreement exists, is in force or covers the purchase is the holder's, so the field is the realm's claim for a reader or a guard to weigh (I-PRC-6) |
| D39 | How planning legislation reaches a licence | Decided 11 Nov 2026: the domain `planning` (urban planning), and the least GGG needs for a plan's suspension of licences: a parcel's `zones` (`land_zone_set`, a plan's area being a `Zone` the realm defines), the parcel a licence is for (`License.land`), and the derived fact `zones` of `license_decide`. No plan, boundary or suspension entity: the plan and its dates are the chapter's, GGG keeps which parcels lie in which zone (I-AST-6, I-LIC-4) |
