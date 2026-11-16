# GGG ontology guidelines

**Version:** 0.1.0 (see [Versions](README.md#versions)).

[The model](README.md) says what a realm is made of. This page says **how to decide what belongs in
it**, and what shape a thing takes once it does. It binds nobody's implementation: it is the
reasoning a change to the model has to survive.

Use it when proposing an entity, a field or an operation, and when turning a legislative text into
a codex. When this page and the model disagree, the model is what a GOS implements — and one of
them needs fixing.

## 1. The model holds logic, not labels

GGG implements logic derived from legislative texts. **If something cannot be translated into
logic, GGG does not cover it.**

A field that records what someone asserts, which no rule can check, is not governance. It is a form.
Writing it into the model does not make the realm govern that thing; it makes the realm *store a
claim about* that thing, and leaves the governing to whoever reads the audit log later.

This has a consequence people find uncomfortable, and it is the point: **what GGG does not cover, it
should refuse, not record.** A realm that cannot decide whether an act is lawful should not let the
act through carrying a note that says it is. Either the rule is expressible — then express it — or
it is not, and the act belongs outside the system, recorded as an exception rather than disguised as
compliance.

> *Test.* Name the rule that reads the field and the decision it makes. If no rule can, the field
> does not belong in the model.

## 2. Legislation describes a process; code executes one

Legislation is a **description** of a process. Code is the **execution** of a process.

A description is conditioned by the technological means available when it was written. Registers
were books, so the law says who keeps the book. Notice was paper, so the law says where it is
posted. Identity was a clerk recognising a face, so the law says who appears in person. Those means
are in the text because they were the only means there were.

Therefore **some process descriptions in legislation are suboptimal, or no longer needed, in a
software realm.** A codex that reproduces them faithfully reproduces their limits too: it models the
book rather than the register, the posting rather than the notice.

### What this does not license

It is not permission to skip legal steps. Separate two things in the text:

| | What it is | In a realm |
|---|---|---|
| **The obligation** | what the rule protects: a right, a deadline, a separation of powers, a record that can be audited | binding; the realm must achieve it |
| **The procedure** | the means by which the obligation was achievable with the technology of the day | may be replaced by any means that achieves the obligation at least as well |

> *Test.* Ask what the rule protects. If the means can change without defeating what it protects,
> the means is technology, not law. If you cannot say what it protects, you do not understand the
> rule well enough to implement it — go back to the text.

Two worked distinctions:

- *"Published in the official bulletin within 15 days."* The obligation is public, dated, tamper-evident
  notice within 15 days. Paper is the technology. A realm's journal, signed and verifiable, serves the
  obligation; it does not need to be a bulletin.
- *"Decided by a judge."* The obligation is that a person with standing and independence decides.
  No technology removes that. A realm implements it; it does not optimise it away.

## 3. Model the fact, not the claim about the fact

Where a rule depends on something being true of the world, the model should hold **the thing that
makes it true**, not a party's statement that it is.

A claim is a string someone types about their own conduct. A fact is state the realm holds, written
by an operation that had to be authorised, which a rule can read and a later reader can re-check.
Both can sit in the same operation and look alike in the interface; they are not alike.

Prefer, in this order:

1. **a reference to an entity** the realm already holds (`Contract`, `Mandate`, `License`, `ChapterRef`);
2. **a recorded fact** written when the thing happened, by an operation with its own permission;
3. **a claim** — only where the model has decided, explicitly, that this is outside what it covers,
   and §1 therefore applies.

> *Test.* Could a rule have reached a different answer if the person had typed something else, with
> nothing else about the realm being different? Then it is a claim.

## 4. An entity earns its place by being read

Every entity, field and status should be named by some rule, operation or invariant that reads it.
A field nothing reads is a comment with a schema. It costs every implementation, every interface
version and every migration, and buys a note that a free-text field would have held.

This is why the model's [Decisions](README.md#16-decisions) mostly reject merges: an entity that an
operation genuinely reads is not noise, however small it looks.

## 5. A worked example: the legal basis of a document share

This is the example the guidelines were written from. It shows §1, §3 and §4 in one operation, and
it is still open.

A realm shares an encrypted document with another body. Access control is complete and
cryptographic: the caller needs a permission, must be staff of the document's department, the
recipient must exist, the operation asks the member each time, and sharing hands out wrapped
decryption keys rather than setting a flag. None of that is at issue.

On top of it, the share states a **basis**: under data-protection law, the lawful ground for the
disclosure. It is carried as text — the name of a ground, a purpose, optionally a citation.

What that produces:

| What the sharer states | What happens |
|---|---|
| nothing | refused: a share needs a basis |
| `consent`, between public authorities | refused by the upper layer: consent is not a basis between public authorities |
| `public task`, no citation | refused by the lower layer: name the legislation that sets this public task |
| **an invented ground** | **allowed** — no rule matches it, so nothing denies it |

The last row is §1. The ground is a label, so the rules can only test it against labels they
happen to know, and an unrecognised one falls through every test. Closing the vocabulary does not
fix it: it means an unlawful share must be declared in approved words. The citation requirement has
the same shape one level up — it checks that a string is present, not that it names a norm, nor that
the norm assigns that task to that body.

The same operation already contains the other pattern. The document carries **facts** recorded when
it was stored — state, written by an operation that had to be authorised, which legislation reads
when the document is shared. That is §3's first two tiers, in the same call as a claim.

Applying §3, the grounds separate by whether a realm can hold what makes them true:

| Ground | What would make it true | Verdict |
|---|---|---|
| performance of a contract | a live `Contract` with the subject | expressible |
| legal obligation | the chapter that imposes it (`ChapterRef`) | expressible |
| public task | a `Mandate` assigning the task to the body | expressible |
| consent | a consent record — **no such entity exists in the model** | not expressible yet |
| legitimate interests | a balancing of interests | **not expressible, ever** — §1 applies |

Open questions this leaves, which the model has not decided:

- which grounds GGG covers, and what a share needing an uncovered one does — refuse, or leave the
  system with the fact recorded as an exception;
- whether consent becomes an entity, and what it holds (subject, purpose, given, withdrawn);
- whether a citation becomes a reference rather than a string.

## 6. Applying these when proposing a change

Before adding an entity, field, status or operation:

1. **Name the rule that reads it.** No reader, no addition (§4).
2. **Say what it protects**, in one sentence, in terms of the obligation rather than the procedure (§2).
3. **Check it is a fact, not a claim** — and if it is a claim, say so and justify it under §1 (§3).
4. **Say what happens when the realm cannot decide.** "It is allowed and recorded" is an answer that
   needs defending, not a default (§1).
5. **Write the cases that fail without it**, including one for the thing nobody thought of: the
   unrecognised value, the absent reference, the ground the realm does not cover.

Step 5 is how the example above was found: every case covered a value the rules knew, and none
covered a value they did not.
