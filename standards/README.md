# GGG standards

GGG (Generalized Global Governance) is the architecture a Governance Operating
System (GOS) is built for. These standards define how a GOS canister on the
Internet Computer is called: by its own frontend, by other GOS, by hosting
platforms such as gos.earth, by wallets and by tools.

What a realm is made of, its entities, operations, lifecycles, invariants and
permissions, is defined once, in the [GGG model](../model/README.md). Each
standard binds part of that model to a Candid interface. A GOS can be written in
any language. What makes it a GGG GOS is that it implements the standards it
claims and passes their conformance tests.

| Standard | Title | Model | Status | Interface |
|---|---|---|---|---|
| [GGG-1](GGG-1.md) | Realm core: the realm, members, proposals, votes | parts of §2, §4, §12 | Draft | [GGG-1.did](GGG-1.did) |
| [GGG-2](GGG-2.md) | Operations by name | every operation | Draft | [GGG-2.did](GGG-2.did) |

GGG-1 is required. Every other standard is optional.

The remaining domains of the model each get a typed standard. Until one exists,
its operations are reachable through GGG-2:

| Standard | Model | Status |
|---|---|---|
| GGG-3 | §2 Identity and membership: profiles, permissions, invites, identities, delegations | Not drafted |
| GGG-4 | §3 Departments and organizations | Not drafted |
| GGG-5 | §4 Governance: the proposal lifecycle, mandates, contracts | Not drafted |
| GGG-6 | §5 Finance | Not drafted |
| GGG-7 | §6 Assets: land and NFTs | Not drafted |
| GGG-8 | §7 Licensing | Not drafted |
| GGG-9 | §8 Justice | Not drafted |
| GGG-10 | §9 Procurement | Not drafted |
| GGG-11 | §10 Quarters and federation | Not drafted |
| GGG-12 | §11 Codex, extensions, notifications, events, documents | Not drafted |
| GGG-13 | §12 Realm setup and administration, including how a hosting platform installs a realm and hands it over | Not drafted |

## Conventions shared by all GGG standards

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are used as described
in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

### Method names

The method that binds model operation `x` in standard GGG-N is `gggN_x`, for
example `ggg1_proposal_vote` for `proposal_vote`. A method that exposes part of an
operation's result on its own is named after it (`ggg1_proposal_votes`). This
follows the ICRC convention (`icrc1_transfer`): several standards live on one
canister without name clashes, and a method name says which standard defines it
and which operation it runs.

A method follows its model operation: the same permission, flags, checks,
effects and invariants. A standard only adds what the model leaves to the wire.

A GOS MAY expose any other method. Methods outside these standards MUST NOT use
a `ggg` prefix.

### Discovery

Every GGG GOS MUST implement
[ICRC-10](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md):

```candid
icrc10_supported_standards : () -> (vec record { name : text; url : text }) query;
```

The list MUST include `ICRC-10`, `GGG-1` and every other GGG standard the GOS
implements, each with the URL of its specification. Callers decide what to call
from this list, not from which implementation a canister runs.

### Types

The [model's conventions](../model/README.md#1-conventions) apply. In Candid:

- **Time** is `nat64` nanoseconds since 1970-01-01 UTC, as returned by `ic0.time`,
  and an unset time is `opt`.
- **Principals** are Candid `principal`, never text.
- **Identifiers** of records are `text`. Callers MUST treat them as opaque.
  Implementations SHOULD keep them under 64 bytes.
- **References** to any entity are `record { kind : text; id : text }`, where
  `kind` is the model's entity name (`Organization`).
- **Amounts and counts** are `nat`. There are no floating-point numbers.
  Ratios are basis points: 10 000 = 100 %.
- **Statuses** are variants whose tags are the model's values in `CamelCase`:
  `in_progress` is `InProgress`.
- **Generic values** use the ICRC-3 `Value` type (`Nat`, `Int`, `Text`, `Blob`,
  `Array`, `Map`). It has no boolean or null:
  - booleans are encoded as `Nat` 0 or 1;
  - an absent value is a missing `Map` key.

### Fields an implementation adds

A GOS MAY add fields of its own to the records it returns, for data the model
doesn't have. Their names MUST start with the implementation's name
(`realms_gos_tally_required`, `monad_gos_org_scope`), so they can never clash with
a field a later version of the standard adds. Under Candid subtyping, callers
built for the standard ignore them.

A GOS MAY also accept extra argument fields of its own, named the same way. They
MUST be `opt`, so that callers who don't know them can leave them out.

### Results and errors

A method that can refuse a call returns `variant { Ok : T; Err : GggError }`.
It does not trap. A trap is for bugs, not for refusals.

```candid
type GggError = variant {
  NotFound;
  Unauthenticated;
  Forbidden : record { permission : opt text; message : text };
  InvalidArgument : text;
  Conflict : text;
  Unsupported : text;
  Unavailable : text;
  GenericError : record { error_code : nat; message : text };
};
```

| Error | Meaning |
|---|---|
| `NotFound` | A record the call depends on does not exist. A lookup by id returns `Ok(null)` instead. |
| `Unauthenticated` | The caller is anonymous and the call needs an identity. |
| `Forbidden` | The caller is identified but not allowed. `permission` names what is missing, when the GOS has named permissions, so a UI can say what to ask for. |
| `InvalidArgument` | The arguments are malformed or out of range. |
| `Conflict` | The call contradicts the current state, for example a vote on a closed proposal. |
| `Unsupported` | This GOS does not offer what was asked, for example delegation, or an unknown operation name. |
| `Unavailable` | The realm cannot serve the call now, for example during setup or while frozen. |
| `GenericError` | Anything else. `error_code` values are implementation-specific. |

`message` and text payloads are for people. Callers MUST NOT parse them.

A read is refused with `Unauthenticated` or `Forbidden` when the caller lacks
the permission its model operation needs. An anonymous caller MUST receive
`Unauthenticated` from every method that changes state, unless a standard says
otherwise.

### Lists

Every method that returns many records is paginated. Its argument has:

```candid
cursor : opt text;   // null for the first page
limit  : opt nat32;  // null for the implementation's default page size
```

and its page has:

```candid
items : vec T;
next  : opt text;    // the cursor for the following page, null on the last page
```

- The implementation MAY return fewer items than `limit`, and MAY cap `limit`.
  Each page MUST fit within the Internet Computer's instruction and reply-size
  limits however large the realm grows.
- When `next` is not null, `items` MUST NOT be empty.
- Cursors are opaque and MAY expire. An expired or malformed cursor returns
  `InvalidArgument`.
- The order is set by the implementation but MUST be stable. Walking every page
  while nothing changes MUST return each record exactly once.

No GGG method returns a whole collection.

### Consent messages

An implementation SHOULD implement
[ICRC-21](https://github.com/dfinity/wg-identity-authentication/blob/main/topics/ICRC-21/icrc_21_consent_msg.md)
for its GGG update methods, and then list `ICRC-21` in
`icrc10_supported_standards`. A wallet can then show a member exactly what they
are signing, such as "Vote Yes on proposal 42: Fund the library", instead of an
opaque call.

### Status and versioning

A standard is either **Draft** or **Final**:

- **Draft**: anything may change.
- **Final**: the standard only changes in ways existing callers and implementations
  still accept under Candid subtyping:
  - a new method;
  - a new `opt` field in an argument record;
  - a new field in a returned record.

Anything else is a new standard with a new number.

Callers built for a Final standard will reject a variant tag they don't know in
a reply. So an implementation MUST NOT return a variant tag that is not in the
version it declares, and a new status in a model lifecycle reaches a Final
standard only through a new standard.

While a standard is a Draft, each revision that implementations build against is
tagged in this repository as `ggg-N-draft.R`, for example `ggg-1-draft.1`. A GOS
that implements a draft lists the tagged URL in `icrc10_supported_standards`:

```text
https://github.com/smart-social-contracts/ggg/blob/ggg-1-draft.1/standards/GGG-1.md
```

The conformance suite is tagged with the same revisions. Once the standard is
Final, the URL is the one on `main`.

### Conformance

"GGG-N compliant" means that the canister:

- lists GGG-N in `icrc10_supported_standards`;
- passes the GGG-N checks of the [conformance suite](../conformance/README.md).

The suite runs against any canister id, on a local replica or on mainnet.
