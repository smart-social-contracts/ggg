# GGG conformance suite

Checks that a canister implements [`ggg.did`](../ggg.did) as the [model](../model/README.md) says.
It runs against any canister id, on mainnet or on a local replica.

```bash
npx ggg-conformance --canister <id>                          # read-only, on mainnet
npx ggg-conformance --canister <id> --network local          # on a local replica
npx ggg-conformance --canister <id> --writes --member-pem me.pem
```

Without `--writes`, the suite makes queries, plus update calls that a compliant canister refuses
without changing anything. With `--writes` and a member's key, it also files a Motion proposal
titled "GGG conformance check …", votes on it twice and withdraws it. Every update is also called
anonymously, and every update that takes `on_behalf_of` on behalf of a stranger, with arguments
generated from `ggg.did`, expecting both to be refused; the generic call `ggg_call_for` is tried on
behalf of a stranger and carrying a member-only operation, expecting a refusal too. Use a test realm,
or a realm where that is acceptable.

When the member holds active grants from two members, one to propose and one to vote, the suite also
files a motion for the first and expects a vote for the second on it to be refused: a delegate never
votes on what it filed. Reads run as the member when one is given, because a GOS may refuse reads
that need a model permission to anonymous callers. Every list is walked page by page and sent a
malformed cursor, and every lookup by id is asked for an id that doesn't exist, so a realm with
nothing in a domain is
checked too.

Each check reports one outcome:

| Outcome | Meaning |
|---|---|
| `PASS` | The canister meets the rule. |
| `FAIL` | It breaks a MUST. The command exits with 1. |
| `WARN` | It breaks a SHOULD. |
| `SKIP` | The check could not run: no data, no member key, `--writes` off, or the caller was refused. |

`--json` prints every result.

## Developing

```bash
npm install
npm run idl     # regenerate idl/ggg.js and fixture/Ggg.mo from ggg.did; needs didc
npm run facts   # regenerate ../facts.json, the fact schema, from ggg.did
npm test        # check ggg.did against the model, and run the suite against the fixture on PocketIC
```

The test files run one at a time. `@dfinity/pic` names a server's port file after the parent process,
which every test file shares, so servers started together overwrite each other's port file and tests
fail with "fetch failed" or "Instance was deleted".

`MOC` and `MOTOKO_CORE` default to the copies that ship with dfx, and `DIDC` to a `didc` on the
path.

- `idl/ggg.js` is the JavaScript binding generated from `ggg.did`.
- `test/model.test.js` fails when an entity's fields in `ggg.did` differ from the model, or a `ggg_`
  method is not a model operation.
- `test/domains.test.js` fails when `domains.json` is malformed or differs from the table in
  `docs/layered-codex.md`.
- `test/facts.test.js` fails when `facts.json` differs from what `scripts/facts.js` generates from
  `ggg.did`, or when the kinds table in `docs/layered-codex.md` differs from it.
- `test/delegation.test.js` fails when `delegation.json` misses a method of `ggg.did` or lists one twice,
  names an unknown tier, group or condition, or disagrees with the model's `delegable` and `confirm` flags.
- `test/rules.test.js` runs the fixture with four members and checks what a proposal's stated rule
  decides (model I-GOV-3): over the eligible voters a tie rejects, a majority accepts, absentees count
  against; in a department that counts the votes cast, abstentions count towards the quorum of its n
  only, and a tie gets a second vote, where the chair's casting vote decides (I-GOV-14).
- `test/tags.test.js` runs the fixture with two members and checks proposal tags (model I-GOV-15): a
  list filters by any of several tags, exactly, together with a status, and only the member a draft
  was filed for replaces its tags.
- `test/contracts.test.js` runs the fixture with two members and checks contract amendments (model
  I-GOV-16, I-FIN-11): a split adds up to the value, an amendment keeps the contract's id and records
  its terms before and after with the proposal that carried it, a terminated contract is never
  amended, payments never exceed a contract's value, and no amendment sets it below what was paid.
- `test/organizations.test.js` runs the fixture with two members and checks organization kinds (model
  I-ORG-9): `other` when none is given, changed only by the organization's admins, and a list by kind.
- `test/spending.test.js` runs the fixture with one member and checks spending stages (model I-FIN-9,
  I-FIN-10): a line's reserved and committed money, transfers charged to it and refused past it with
  a message that names the line and the shortfall, and scheduled transfers paid or cancelled.
- `test/sync.test.js` runs three fixtures that take legislation from one another and checks the links
  between realms (model I-NEST-1 to 3) and the published record (model §11).
- `test/codex.test.js` installs codices the fixture holds and checks `codex_revert` (model §11): the one
  the active codex replaced, any earlier one by checksum, an unknown one `NotFound`.
- `test/attributes.test.js` submits and reviews attributes and checks who reads them (model §2,
  I-PRV-1): the reviewers see the pending ones, the person their own, and the audit log never holds a
  kind or a value.
- `src/money.js` is the money rule as code (model §5, layered codex §3.3), shipped with the package so a
  GOS can check its own arithmetic against it; `test/money.test.js` runs the model's progressive-tax
  example.
- `fixture/Ggg.mo` holds the Motoko types generated from `ggg.did`.
- `fixture/main.mo` is a minimal Motoko GOS: members, five departments, proposals, links between realms
  and a published record, and every other domain empty. The build checks its interface against
  `ggg.did` with `didc check`, and the tests expect it to pass every check.
- `fixture/broken.mo` breaks GGG on purpose, and the tests expect the checks to fail.
