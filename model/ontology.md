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

## 3. Faithful is not correct: scrutinise the logic

**The logic of a rule does not always make sense.** Legislative texts are amended by different
hands over decades. They contain rules that contradict each other, rules whose conditions can never
be met, rules that produce absurd results at the edges, and rules left behind by the repeal of what
they referred to. A text is not a specification that was reviewed before it shipped.

Code is unforgiving in a way prose is not. A human applying an incoherent rule notices and asks.
Code applies it, every time, at scale, instantly — so **transcribing a rule faithfully can entrench
a defect that was harmless while a person stood between the text and the outcome.** Fidelity to the
text is not the goal; a realm that governs correctly is.

So every rule gets analysed before it is written:

- What does it produce at the edges — zero, empty, the boundary date, the maximum?
- Does it contradict another rule in the same codex, or one in a layer above?
- Are its conditions reachable at all?
- Does it still refer to something that exists?

### Scrutiny is not amendment

The codex author does not have authority to improve the law. Finding a defect does **not** license
quietly implementing what the rule should have said. That is legislating, and it is worse than the
defect, because it is invisible.

What scrutiny produces is a **finding, raised openly**: a question back to whoever holds the text,
a recorded decision, or a refusal to implement until it is settled. A deviation that is visible and
argued is governance. A deviation that is tidy and silent is a bug with good manners.

> *Test.* If someone compared the text with the codex, would every difference between them be one
> you could point to and justify?

## 4. Prevention is better than regulation

If a rule exists to stop something, and the realm can make that something **impossible**, the
apparatus the text builds around it has nothing left to do.

Legislation regulates what it cannot prevent. The text assumes the prohibited act is available — a
council *can* set a rate above the cap, a file *can* be disclosed without a ground — so it provides
for detection, challenge, correction and penalty after the fact. All of that is machinery for a
world in which the act happens and is then dealt with.

Code is not in that world. A realm can make the act unexecutable, and then there is no breach to
detect.

In the live `eu/es` layer the cap on an urban IBI rate is a `forbid` on `tax_policy_propose`
(`TRLRHL Art. 72.3`). An excessive rate is not levied and then corrected on appeal: the proposal
that would set it is refused, so the rate never exists to be challenged. The parts of the statute
that exist to catch an excessive rate after it is charged govern a case the realm cannot produce.

### What prevention does not excuse

**It has to be total.** Prevention inside the realm says nothing about the world outside it. If the
act can still happen on paper, in a body the realm does not run, or before the realm existed, then
detection is still live and dropping it is a hole, not a simplification.

**A refusal is still a record.** "It cannot happen" is not the same as "nothing is known about the
attempt". Where what the rule protects is that attempts are visible — an auditable trail, a
reportable count, a pattern someone is meant to notice — the refusal has to be recorded, not merely
enforced in silence.

> *Test.* Can the realm make the act unexecutable everywhere the rule reaches? Then the detection
> and penalty around it is dead code. Only here? Then keep both.

## 5. Where the text and the code differ, the text prevails

Sections 2 to 4 all license a codex to depart from the shape of the text: to replace a procedure, to
refuse a defective rule, to prevent instead of punish. They need one backstop, and this is it.
**The legislation is the authority. The codex is a reading of it.**

In case of ambiguity, conflict or doubt, the legislation prevails over the code. Concretely:

- An ambiguity is settled by reading the text again, never by appealing to what the code already
  does. "The realm does it this way" is not an argument about what the legislation requires.
- A codex that turns out to diverge is **wrong**: a defect to fix in the codex, not a feature of the
  realm to live with. Every realm must be correctable without the text changing.
- Where the text genuinely admits two readings, the codex takes one and **records which**, so the
  choice can be revisited later. Ambiguity is not a licence to take the convenient reading — take
  the one that serves what the rule protects (§2), and say that you did.
- A reader who wants to know what the rule *is* reads the provision. The codex shows them how it is
  executed here, and never stands in for it.

This is what keeps §3 honest. Scrutiny may refuse to implement and may raise a finding. It may never
promote the code to the authority.

> *Test.* If the provision and the codex disagree, which one changes? The codex. Always.

## 6. Every rule cites the provision it comes from

A rule in a codex that does not say where it came from cannot be audited. §3 asks whether the code
matches the text and §5 says the text wins; neither question can even be put without knowing which
text. **So every member of a chapter carries a reference to the part of the legislation it
implements.**

The model already provides for it: every mark takes `legislation="..."`, and so does a forbid.

```python
@extension(legislation="Ley Orgánica 3/2018 Art. 8")
def check_document_share(self, args): ...
```

The field is optional in code and validated only as a string. This principle says fill it, and says
what filling it well means:

- **Cite the provision, not the instrument.** "Ley 39/2015" names a whole statute and
  helps nobody; `Ley 39/2015 Art. 21.3` can be opened and compared with the code beside it.
- **Cite everything the rule implements**, where it implements more than one provision
  (`TRLRHL Arts. 61, 65, 71 and 74`).
- **Where a member implements no provision** — scaffolding, a helper, a default that a layer below
  will replace — say so explicitly, so that an empty citation means "nobody filled this in" and
  nothing else.

This is already the practice rather than an aspiration: all 19 marked members in the live `eu/es`
layer carry a citation, one each.

The payoff is for the reader, not the author. A realm's codex is public. A rule shown with its
provision beside it lets any citizen take what the realm executes and check it against the
legislation that authorises it — which is the audit that §3 and §5 depend on, and which is only
available if the reference is there.

> *Test.* Can a reader open what the citation names and see this rule in it? A citation they have to
> go searching from is not a reference.

## 7. GGG is common ground; the particular goes in a layer

**GGG holds what holds nearly everywhere.** It is the architecture a realm anywhere in the world is
built on, so a rule only makes it into the model if realms across most of the world would recognise
it. Everything particular to a jurisdiction belongs in a **codex layer** — that is what layers are
for, each adding to the one above it.

Roughly:

| Where | What belongs there |
|---|---|
| **The GGG model** | that a realm has departments, that a decision has a scope and a tally, that a document can be shared with someone, that acts are recorded and auditable |
| **A codex layer** | which majority carries a motion here, which grounds make a disclosure lawful here, what a register must contain here, which holidays stop a clock here |

This is not only tidiness. Region-specific logic in the model is a cost paid by every realm that
does not share the region: an interface version, a field to populate, a concept to explain, and a
vocabulary that quietly implies a legal system they are not under.

> *Test.* Does the rule, the field, or the vocabulary name a jurisdiction's statute, agency, or
> legal categories — directly, or through values only that jurisdiction uses? Then it is a layer,
> not the model.

The test catches vocabulary as readily as rules: a field called `legal_basis` sounds universal, but
if its values are the paragraphs of one region's statute, the universality is in the name only.

The test rules out borrowing a jurisdiction's **structure**, not only its categories. Every legal
system divides its legislation, and no two divide it alike: German statutes run
`Buch > Abschnitt > Titel > §`, Spanish ones `libro > título > capítulo > sección > artículo`, the
US Code `Title > Chapter > Section`. The same word does not even keep its rank -- a Spanish
`sección` sits below a `capítulo`, while a section of a UK Act is the provision itself. Naming one
of those divisions in the model would imply a mapping between them that does not exist. So GGG
names the **subject** legislation is about, which every jurisdiction has, and stays out of naming
the divisions a source organises its own text into, which none of them share. A layer is free to
mirror its own structure inside a chapter.

## 8. Model the fact, not the claim about the fact

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

## 9. An entity earns its place by being read

Every entity, field and status should be named by some rule, operation or invariant that reads it.
A field nothing reads is a comment with a schema. It costs every implementation, every interface
version and every migration, and buys a note that a free-text field would have held.

This is why the model's [Decisions](README.md#16-decisions) mostly reject merges: an entity that an
operation genuinely reads is not noise, however small it looks.

## 10. Applying these when proposing a change

Before adding an entity, field, status or operation:

1. **Name the rule that reads it.** No reader, no addition (§9).
2. **Say what it protects**, in one sentence, in terms of the obligation rather than the procedure (§2).
3. **Show you have scrutinised it**: the edges, the contradictions, the unreachable conditions — and
   raise what you found rather than quietly correcting it (§3). If you departed from the text, say
   where, and keep the text as the reference (§5).
4. **Ask whether it can be prevented instead of regulated** — and if it can, whether the prevention
   reaches everywhere the rule does (§4).
5. **Cite the provision** it implements, precisely enough to open (§6).
6. **Check it would be recognised nearly everywhere.** If it names one jurisdiction's law, or carries
   its vocabulary, it is a layer (§7).
7. **Check it is a fact, not a claim** — and if it is a claim, say so and justify it under §1 (§8).
8. **Say what happens when the realm cannot decide.** "It is allowed and recorded" is an answer that
   needs defending, not a default (§1).
9. **Write the cases that fail without it**, including one for the thing nobody thought of: the
   unrecognised value, the absent reference, the ground the realm does not cover.

Step 9 is how the example above was found: every case covered a value the rules knew, and none
covered a value they did not.
