# Governance

One part of [the GGG model](../README.md#the-model).

## 4. Governance

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Proposal` | `id`, `title`, `description`, `proposer` → `User`, `on_behalf_of`, `prepared_by` (the delegate, when the proposer approved it from a pending action, §2), `department` → `Department` (scope; root = realm-wide), `kind`, `matter`, `action` (nothing for a motion; one operation call with its arguments; or codex code ref + checksum), `status`, `opens_at`, `deadline`, `effective_at`, `threshold`, `quorum` (both in hundred-millionths), `threshold_of` (`cast` or `eligible`), `casting_vote` → `User`, `majority_of_cast`, `tally` (Json), `first_vote` (Json), `result` (Json), `links`, `tags` | `kind` and `matter` say what the proposal is (a change of legislation, a budget) and what it decides, in the realm's own words, for legislation to read. `threshold`, `quorum`, `threshold_of`, `casting_vote` and `majority_of_cast` are the rule that decides it (I-GOV-3), fixed when the vote opens; the casting vote is the scope's, the realm's for a realm-wide proposal or the head of a department that counts the votes cast, never the proposer's. `first_vote` is the count of a first vote that tied, when a second one followed (I-GOV-14). A link is `replaces` or `relates to` another proposal, fixed at creation. `links` is optional in `proposal_create`: absent means none. `tags` are the realm's own words for grouping proposals (an area, a district, a kind of act), set at creation and replaced while a draft; `proposal_list` filters by them (I-GOV-15). | `P-7` Bike lane on Main St, scope Infrastructure, action `transfer_create` 50,000 REALM to BuildCo, `voting` until 8 Nov, threshold 2/3 of Infrastructure's 3 policy seats, tags `mobility`, `district-3` |
| `Vote` | `id`, `proposal` → `Proposal`, `voter` → `User`, `cast_by`, `choice` (`yes`, `no`, `abstain`), `cast_at` | One per voter per proposal; may be replaced until the vote ends. A second vote (I-GOV-14) starts with none: the first vote's are in the audit log. | Alice votes `yes` on `P-7`, cast by `claude-conn` |
| `Mandate` | `id`, `title`, `scope` (Json), `max_value`, `symbol`, `executor` → `Department`, `proposal` → `Proposal`, `status`, `expires_at` | An authorization to act, granted by governance. Contracts under it are worth at most `max_value` in `symbol`, when set. | Infrastructure may contract road works up to 200,000 REALM until 2027-06-30 (from `P-4`) |
| `Contract` | `id`, `title`, `parties` (Json list of `Entity:id`), `mandate` → `Mandate`, `kind`, `procedure`, `tender` → `Tender`, `value`, `symbol`, `terms_ref`, `terms_hash`, `status`, `starts_at`, `ends_at`, `split` (Json list of `period`, `amount`), `lot`, `framework` | Agreement between parties, possibly under a mandate. `value` is what the realm commits, in `symbol`; `split` spreads it over fiscal periods (I-GOV-16). `kind` (works, supplies, services) and `procedure` are the realm's words; a contract made from a tender names it and takes its kind and procedure, and, when the tender has lots, the `lot` it was awarded under (I-PRC-5). `framework` names the framework agreement it is a call-off under, held by another body (I-PRC-6). `contract_amend` changes its value, split and dates and keeps its id, each change recorded as a `ContractAmendment`. | `C-9`: Agora × BuildCo, bike lane works, 50,000 REALM, Dec–Mar, from tender `T-5`, terms `sha256:4be1…`, 30,000 in FY2026 and 20,000 in FY2027; `C-14`: the realm's electricity, a call-off under the province's agreement `AM-2025/04` |
| `ContractAmendment` | `id`, `contract` → `Contract`, `before` (Json: `value`, `split`, `starts_at`, `ends_at`), `after` (Json, the same), `proposal` → `Proposal`, `at` | One amendment of a contract, never edited or removed (I-GOV-16). `proposal` is the one that carried it, absent when the governing department decided directly. | `C-9` re-spread by `P-31` on 23 Jan: 10,000 in FY2026 and 40,000 in FY2027 |

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
| `proposal_set_tags` | `proposal.create` (own) | delegable | Bob tags his draft `P-8` `parks` and `district-2` |
| `proposal_vote` | `proposal.vote` | delegable | `{proposal: "P-7", choice: "yes", on_behalf_of: "alice"}` → `V-31` |
| `proposal_open`, `proposal_finalize`, `proposal_execute` | `proposal.manage` | delegable | After the deadline: 412 yes, 120 no, quorum met → `accepted`; execute pays BuildCo. The Council's 15 yes, 15 no and 3 abstentions are a tie: finalizing opens its second vote |
| `proposal_stop` | `proposal.manage` | governed, delegable | `P-12`, scoped to Infrastructure, is scheduled for 1 Dec; under Infrastructure's policy a vote (`P-15`) calls `proposal_stop` on it and it ends `withdrawn` |
| `proposal_get`, `proposal_list` | `realm.data_view` | read, delegable | Open proposals in quarter North; the proposals tagged `district-2` or `district-3` |
| `proposal_linked_from` | `realm.data_view` | read, delegable | The proposals that link to `P-7`: `P-9` replaces it, `P-11` and `P-12` relate to it |
| `mandate_create`, `mandate_revoke` | `mandate.create` | governed, delegable | Grant Infrastructure the road-works mandate (via `P-4`) |
| `mandate_assign_executor` | `mandate.assign_executor` | governed, delegable | Make Infrastructure the mandate's executor |
| `contract_create` | `contract.create_under_mandate` | confirm | Sign `C-9` with BuildCo under the road-works mandate. Prepared by a delegate, it waits for the member's approval: it binds the realm to an outside party at once |
| `contract_terminate` | `contract.terminate` | signing, confirm | End `C-9` after BuildCo misses two milestones (court order) |
| `contract_amend` | `contract.amend` | governed, confirm | Re-spread `C-9`: 10,000 REALM in FY2026 and 40,000 in FY2027, ending in June 2027 → proposal `P-31` of Infrastructure. Prepared by a delegate, it waits for the member's approval: it changes what the realm owes an outside party |
| `contract_get` | `realm.data_view` | read, delegable | `C-9` with its two amendments, oldest first |
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
- I-GOV-15: A proposal's `tags` are text in the realm's own words: at most 16, each 1 to 64 Unicode
  code points (`València` is 8, whatever its bytes or UTF-16 units), with no control character
  (U+0000 to U+001F, U+007F to U+009F) and no whitespace (Unicode `White_Space`) at either end, none
  named twice, else `InvalidArgument`. Tags are compared exactly: equal only when their code points
  are, so `Parks` and `parks` are two tags. GGG never normalises a tag; clients SHOULD send it in NFC,
  since the same word in another normalisation form is another tag. They are set by `proposal_create`
  (absent means none) and replaced only while the proposal is a `draft`, by its proposer or for the
  member it was filed for, with `proposal_set_tags` (`Conflict` once it is open, `Forbidden` for
  another's); they are not part of what is voted on. `proposal_list` with `tags` lists only the
  proposals that carry at least one of them, together with any `status` it names; absent or empty
  means any. More than 16 tags is `InvalidArgument`, and so is a tag of more than 64 code points
  (none can have been set, so none could match). With `tags` and a `status` together a page may be
  short, even empty, with `next` set: the proposals that match both can be far apart in the list, so
  a GOS may stop after checking as many as a call can bear, and a client follows `next` (the one
  exception to a page never being empty when `next` is set, in *Lists*).
- I-GOV-16: A contract's `split`, when not empty, names each fiscal period once, at most 64 of them,
  and its amounts add up to `value`; a period is named as a budget line names it, and need not be
  open yet. `contract_amend` replaces the terms it is given, of `value`, `split`, `starts_at` and
  `ends_at` (an empty `split` clears it), and nothing else: the contract's id, parties, `symbol`,
  terms document and status stay. The amended terms meet the rules of a new contract: a non-empty
  split adds up to the new value, so a spread contract that changes its value needs a new split;
  `starts_at` is not after `ends_at`; under a mandate, the value stays within its `max_value` and
  `ends_at` within its term (I-GOV-4). An amendment that breaks them, or changes no term, is refused
  with `InvalidArgument`. A `terminated` or `fulfilled` contract is never amended, and neither is its
  `value` set below what has been paid on it (both `Conflict`), each checked again when a proposal
  executes the call. What has been paid on a contract is defined in I-FIN-11. Its governing
  department is the contract's owner (§1). Each amendment is recorded as a `ContractAmendment`, with the terms
  before and after, the proposal that carried it (absent when the call applied at once) and when it
  applied; amendments are never edited or removed, and `contract_get` lists them oldest first, a
  page at a time.
