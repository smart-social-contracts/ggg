# GGG-1: Realm core

| | |
|---|---|
| Status | Draft |
| Interface | [GGG-1.did](GGG-1.did) |
| Model | [§2 Identity and membership](../model/README.md#2-identity-and-membership), [§4 Governance](../model/README.md#4-governance), [§12 Realm setup and administration](../model/README.md#12-realm-setup-and-administration) |
| Requires | [ICRC-10](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md), and the [shared conventions](README.md#conventions-shared-by-all-ggg-standards) |

## Summary

GGG-1 is the part of the model every GOS has: the realm's public profile, its members, and
proposals with their votes. A wallet, a dashboard, a hosting platform or another realm can use any
GGG GOS through it, whatever language the GOS is written in and however it governs itself.

It binds seven model operations, plus one read that exposes part of another's result:

| Method | Model operation | Permission in the model |
|---|---|---|
| `ggg1_realm_info` | `realm_info` | public |
| `ggg1_user_get` | `user_get` (and `me` for the caller's own record) | `user.view` |
| `ggg1_user_list` | `user_list` | `user.view` |
| `ggg1_proposal_get` | `proposal_get` | `realm.data_view` |
| `ggg1_proposal_votes` | the votes returned by `proposal_get` | `realm.data_view` |
| `ggg1_proposal_list` | `proposal_list` | `realm.data_view` |
| `ggg1_proposal_create` | `proposal_create` (delegable) | `proposal.create` |
| `ggg1_proposal_vote` | `proposal_vote` (delegable) | `proposal.vote` |

Each method follows its model operation: the same checks, the same effects, the same invariants.
This document only adds what the model leaves to the wire. Every other operation in these sections
(withdrawing, opening, finalizing and executing proposals, mandates, contracts, invites, profiles,
delegations) belongs to later standards, and is reachable today through [GGG-2](GGG-2.md).

## Methods

### `icrc10_supported_standards`

Lists `ICRC-10`, `GGG-1` and every other standard the canister implements. For GGG-1 the URL is
`https://github.com/smart-social-contracts/ggg/blob/main/standards/GGG-1.md`.

### `ggg1_realm_info`

```candid
ggg1_realm_info : () -> (Realm) query;
```

The realm's public profile, from the model's `Realm` entity. Anyone may call it, including anonymous
callers, and it never fails.

- `name` MUST NOT be empty.
- `status` is the realm's lifecycle: `Setup`, then `Alpha`, `Beta`, `Production`, `Deprecation` and
  `Terminated`.
- `accounting_currency` is null until the realm has chosen one.
- `implementation` names the GOS, not the realm: `name` is a stable identifier such as `realms-gos`
  or `monad-gos`, and `version` is the model's `installed_version`. Both MUST NOT be empty. It is for
  display and support. Callers MUST NOT use it to decide what to call; that is what
  `icrc10_supported_standards` is for.
- `member_count` counts members whose status is `Active`, when the realm keeps that total.

### `ggg1_user_get`, `ggg1_user_list`

```candid
ggg1_user_get : (principal) -> (UserGetResult) query;
ggg1_user_list : (ListArgs) -> (UserListResult) query;
```

A `Member` joins the model's `Member` and `User`: membership status and join date, with the user's
public card (nickname, avatar, home quarter, profiles).

`ggg1_user_get` returns `Ok(null)` for a principal that has never been a member, and the anonymous
principal is never one. Both methods need `user.view` and answer `Forbidden` without it, except that
`ggg1_user_get` MUST always answer for the caller's own principal, as `me` does.

### `ggg1_proposal_get`, `ggg1_proposal_votes`, `ggg1_proposal_list`

```candid
ggg1_proposal_get : (text) -> (ProposalGetResult) query;
ggg1_proposal_votes : (ProposalVotesArgs) -> (ProposalVotesResult) query;
ggg1_proposal_list : (ProposalListArgs) -> (ProposalListResult) query;
```

`ggg1_proposal_get` returns one proposal, or `Ok(null)` for an id that doesn't exist.

- `department` is the proposal's scope. Null means realm-wide, the model's root department.
- `action` is what accepting it does: a `Motion` does nothing on-chain, an `Operation` runs a model
  operation once, and `Code` adopts codex code whose `checksum` is `sha256:` followed by the
  lower-case hex digest.
- `threshold_bps` is the share of the Yes and No votes that must be Yes, and `quorum_bps` the share
  of eligible voters who must vote, Abstain included. The model keeps them in percent; 50 % is
  `5000`.
- `tally` counts the votes so far, and `eligible` the voters eligible for the proposal's scope when
  the GOS knows it.
- `result` is what the action returned once the proposal was executed or failed.

`ggg1_proposal_votes` lists a proposal's votes in pages, or only the vote of `voter` when it is set.
It returns `NotFound` for an unknown proposal.

`ggg1_proposal_list` lists proposal summaries in pages. Descriptions are left out, as the model
requires for records with large parts. When `status` is set, only proposals with that status are
listed.

### `ggg1_proposal_create`

```candid
ggg1_proposal_create : (ProposalCreateArgs) -> (ProposalCreateResult);
```

Files a proposal and returns its id. The new proposal is `Draft` or `Voting`; voting lasts the
realm's voting window.

- An anonymous caller receives `Unauthenticated`.
- An unknown `department` returns `NotFound`.
- An `Operation` action whose `op` the realm doesn't have returns `InvalidArgument`, so that no vote
  is ever held on something that can't run.
- An action kind the GOS doesn't accept returns `Unsupported`.
- `on_behalf_of` files it for a grantor, under the model's delegation rules. A GOS without
  delegation answers `Unsupported` when it is set.

### `ggg1_proposal_vote`

```candid
ggg1_proposal_vote : (ProposalVoteArgs) -> (ProposalVoteResult);
```

Casts the caller's vote, or the grantor's with `on_behalf_of`, and returns it as recorded. As in the
model, there is one vote per voter per proposal, and voting again before the deadline replaces the
earlier vote.

- An anonymous caller receives `Unauthenticated`.
- An unknown proposal returns `NotFound`.
- A proposal that isn't `Voting`, or whose deadline has passed, returns `Conflict`.
- A caller who isn't eligible for the proposal's scope (I-GOV-2) receives `Forbidden`.
- A delegated vote records the grantor as `voter` and the delegate as `cast_by`. Otherwise `cast_by`
  is null or the voter.

## How the current implementations map to GGG-1

This section is informative.

| GGG-1 | Realms GOS (Python) | Monad GOS (Motoko) |
|---|---|---|
| `ggg1_realm_info` | `realm_info` | `get_realm_state` and `get_setup_state`; `Setup` until `complete_setup` |
| `ggg1_user_get`, `ggg1_user_list` | `user_get`, `user_list`, `me` | principals with a recorded dues payment, `Inactive` once their dues lapse |
| `ggg1_proposal_get`, `ggg1_proposal_votes` | `proposal_get` | `get_proposal`, `get_vote` |
| `ggg1_proposal_list` | `proposal_list` | `list_proposals` (its offset becomes the cursor) |
| `ggg1_proposal_create` | `proposal_create` | `submit_proposal`, with `Code` actions from `code_url` and `code_checksum` |
| `ggg1_proposal_vote` | `proposal_vote` | `cast_vote`, which has to allow a second vote to replace the first |
| statuses | the same names, in lower case | `pending_vote` → `Draft`, `voting` → `Voting`, `approved` → `Accepted`, `no_quorum` → `Rejected` |
| times | seconds, multiplied by 10⁹ | already nanoseconds, except `voting_deadline` (ISO text) |
| GOS-specific data | extra fields such as `realms_gos_tally_required` | extra fields such as `monad_gos_org_scope` |

## Open questions

1. **Proposal order.** UIs usually want the newest proposals first. Should `ggg1_proposal_list`
   take an `order` argument, or should the model fix newest-first?
2. **`Proposal.on_behalf_of` in the model.** The model lists it, but Realms GOS stores the proposer
   there when a delegate files, so it doesn't say who the delegate was. GGG-1 leaves it out until
   the model says what it holds.
3. **Booleans in `Value`.** ICRC-3 `Value` has no boolean or null; GGG encodes a boolean as `Nat` 0
   or 1. The alternative is a GGG value type with `Bool` added.
4. **Proposal ids.** GGG-1 uses opaque text, as the model does. A `nat` would be smaller and
   sortable, but some GOS key proposals by name.
