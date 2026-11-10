// The rule that decides a proposal (I-GOV-3), on PocketIC with four members: over the eligible voters a tie
// at the threshold rejects, a clear majority accepts, and absentees count against, where over the votes
// cast they would not; a tie over the votes cast passes only when the realm's configured casting
// member voted yes; a department's threshold is measured against its policy's n, not the seats
// filled; and a plenary that counts the votes cast takes more yes than no with its quorum of n, and puts
// a tie to a second vote, where only the chair's casting vote decides a tie (I-GOV-14). The suite's
// W18 to W20 and W26 cover what is stored; this covers what it decides.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { idlFactory } from '../idl/ggg.js';

const DAY_MS = 24 * 3600 * 1000;
const members = [0, 1, 2, 3].map(() => Ed25519KeyIdentity.generate());
const [alice, bob, carol, dave] = members;

let server;
let pic;
let as;
// A realm of one member, for the vacancies.
let solo;

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const canisterId = await pic.createCanister();
  const wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  const arg = IDL.encode([IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))], [members.map((m) => m.getPrincipal()), []]);
  await pic.installCode({ canisterId, wasm, arg });
  as = (identity) => pic.createActor({ idlFactory, canisterId, sender: identity.getPrincipal() });
  const soloId = await pic.createCanister();
  const initTypes = [IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))];
  const soloArg = IDL.encode(initTypes, [[alice.getPrincipal()], []]);
  await pic.installCode({ canisterId: soloId, wasm, arg: soloArg });
  solo = (identity) => pic.createActor({ idlFactory, canisterId: soloId, sender: identity.getPrincipal() });
});

after(async () => {
  await pic?.tearDown();
  await server?.stop();
});

const tag = (variant) => Object.keys(variant)[0];
const ok = (result) => {
  assert.ok('Ok' in result, `expected Ok, got ${JSON.stringify(result, (_, x) => (typeof x === 'bigint' ? `${x}n` : x))}`);
  return result.Ok;
};

const refusedWith = (result, error) => {
  assert.ok('Err' in result, 'expected Err, got Ok');
  assert.equal(tag(result.Err), error);
};
/** A realm-wide Motion under the realm's rule; `rule` overrides what it says. */
const motion = (rule = {}) => ({
  title: 'A proposal',
  description: '',
  department: [],
  action: { Motion: null },
  kind: [],
  matter: [],
  threshold: [],
  quorum: [],
  threshold_of: [],
  effective_at: [],
  links: [],
  on_behalf_of: [],
  ...rule,
});
/** Files a Motion as Alice, with the realm's rule unless `rule` says otherwise. */
const file = async (rule = {}) => ok(await as(alice).ggg_proposal_create(motion(rule)));
const proposal = async (id) => ok(await as(alice).ggg_proposal_get({ id, cursor: [], limit: [] }))[0].proposal;
/** Every member votes, in order, then the vote has ended. */
const everyone = async (id, choices) => {
  for (const [voter, choice] of [alice, bob, carol, dave].map((m, i) => [m, choices[i]])) await vote(voter, id, choice);
};
const vote = async (voter, id, choice) => ok(await as(voter).ggg_proposal_vote({ proposal: id, choice: { [choice]: null }, on_behalf_of: [] }));
const finalize = async (id) => tag(ok(await as(alice).ggg_proposal_finalize(id)).status);
const pastTheDeadline = async () => {
  await pic.setTime((await pic.getTime()) + 8 * DAY_MS);
  await pic.tick();
};
const eligible = { threshold_of: [{ Eligible: null }] };
const setCastingVote = async (member) =>
  ok(await as(alice).ggg_governance_update({
    voting_window: [],
    voting_threshold: [],
    voting_quorum: [],
    casting_vote: [member ? { Set: member.getPrincipal() } : { Clear: null }],
  }));

test('two yes and two no over the eligible voters is a tie at the threshold, and rejects', async () => {
  const id = await file(eligible);
  await vote(alice, id, 'Yes');
  await vote(bob, id, 'Yes');
  await vote(carol, id, 'No');
  await vote(dave, id, 'No');
  assert.equal(await finalize(id), 'Rejected');
});

test('three yes and one no over the eligible voters exceeds the threshold, and accepts', async () => {
  const id = await file(eligible);
  await vote(alice, id, 'Yes');
  await vote(bob, id, 'Yes');
  await vote(carol, id, 'Yes');
  await vote(dave, id, 'No');
  assert.equal(await finalize(id), 'Accepted');
});

test('two yes with two absent rejects over the eligible voters, and accepts over the votes cast', async () => {
  const overEligible = await file(eligible);
  const overCast = await file();
  for (const id of [overEligible, overCast]) {
    await vote(alice, id, 'Yes');
    await vote(bob, id, 'Yes');
  }
  await pastTheDeadline();
  assert.equal(await finalize(overEligible), 'Rejected');
  assert.equal(await finalize(overCast), 'Accepted');
});

test('a tie over the votes cast rejects without a casting vote, and passes only when the configured casting member voted yes', async () => {
  const tie = async (id, castersChoice) => {
    await vote(alice, id, 'Yes');
    await vote(bob, id, 'No');
    await vote(carol, id, castersChoice);
    await vote(dave, id, castersChoice === 'Yes' ? 'No' : 'Yes');
    return finalize(id);
  };
  assert.equal(await tie(await file(), 'Yes'), 'Rejected');

  await setCastingVote(carol);
  const withCarol = await file();
  assert.equal((await as(alice).ggg_proposal_get({ id: withCarol, cursor: [], limit: [] })).Ok[0].proposal.casting_vote[0].toText(), carol.getPrincipal().toText());
  assert.equal(await tie(withCarol, 'Yes'), 'Accepted');
  assert.equal(await tie(await file(), 'No'), 'Rejected');

  // The rule is fixed at creation: clearing the setting changes no open proposal.
  const before = await file();
  await setCastingVote(null);
  assert.equal(await tie(before, 'Yes'), 'Accepted');
  assert.equal(await tie(await file(), 'Yes'), 'Rejected');

  const stranger = Ed25519KeyIdentity.generate();
  const refused = await as(alice).ggg_governance_update({ voting_window: [], voting_threshold: [], voting_quorum: [], casting_vote: [{ Set: stranger.getPrincipal() }] });
  assert.ok('Err' in refused && tag(refused.Err) === 'InvalidArgument', 'a casting vote names an active member');
});

test("a department's threshold is m of its policy's n, whatever seats are filled", async () => {
  // The council decides 2 of 3, and all four members may vote: two yes votes carry it, as m, though
  // they are half of the votes; one does not: it is less than m, though a quarter of the four seated.
  const council = { department: ['council'] };
  const carried = await file(council);
  await everyone(carried, ['Yes', 'Yes', 'No', 'No']);
  assert.equal(await finalize(carried), 'Accepted');
  const p = await proposal(carried);
  assert.equal(p.threshold, 66_666_666n);
  assert.deepEqual([p.tally.seats, p.tally.eligible], [[3n], [4n]]);
  const lost = await file(council);
  await everyone(lost, ['Yes', 'No', 'No', 'No']);
  assert.equal(await finalize(lost), 'Rejected');

  // A stricter threshold counts over the same n: 100 % needs three yes votes, not all four.
  const strict = { ...council, threshold: [100_000_000n] };
  const carriedStrictly = await file(strict);
  await everyone(carriedStrictly, ['Yes', 'Yes', 'Yes', 'No']);
  assert.equal(await finalize(carriedStrictly), 'Accepted');
  const short = await file(strict);
  await everyone(short, ['Yes', 'Yes', 'No', 'No']);
  assert.equal(await finalize(short), 'Rejected');

  // Weaker than the policy is refused: a lower threshold, or counting over the votes cast.
  refusedWith(await as(alice).ggg_proposal_create(motion({ ...council, threshold: [50_000_000n] })), 'InvalidArgument');
  const overTheVotesCast = motion({ ...council, threshold_of: [{ Cast: null }] });
  refusedWith(await as(alice).ggg_proposal_create(overTheVotesCast), 'InvalidArgument');
});

test("a department's quorum counts over its seated members, however many seats its policy has", async () => {
  // The council's 60 % quorum is of the four seated, three votes, where over its policy's three seats
  // two would do: two yes votes reach m but, with two absent, the quorum is not met.
  const quiet = await file({ department: ['council'] });
  await vote(alice, quiet, 'Yes');
  await vote(bob, quiet, 'Yes');
  await pastTheDeadline();
  assert.equal(await finalize(quiet), 'Rejected');
  const heard = await file({ department: ['council'] });
  await vote(alice, heard, 'Yes');
  await vote(bob, heard, 'Yes');
  await vote(carol, heard, 'No');
  await pastTheDeadline();
  assert.equal(await finalize(heard), 'Accepted');
});

test('a vacancy never makes a vote easier: with one member seated, a 2-of-3 council carries nothing', async () => {
  const id = ok(await solo(alice).ggg_proposal_create(motion({ department: ['council'] })));
  ok(await solo(alice).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
  // The one member has voted, so the vote has ended: one yes of the policy's three is not m.
  assert.equal(tag(ok(await solo(alice).ggg_proposal_finalize(id)).status), 'Rejected');
  const p = ok(await solo(alice).ggg_proposal_get({ id, cursor: [], limit: [] }))[0].proposal;
  assert.deepEqual([p.tally.seats, p.tally.eligible, p.tally.yes], [[3n], [1n], 1n]);
});

// The plenary has five seats and decides by a majority of the votes cast, with half of its seats
// voting (three votes) and Alice, the first member, as its chair.
const plenary = { department: ['plenary'] };

test('a plenary that counts the votes cast is carried by more yes than no, abstentions aside', async () => {
  const carried = await file(plenary);
  const p = await proposal(carried);
  assert.equal(tag(p.threshold_of), 'Cast');
  assert.deepEqual([p.threshold, p.quorum, p.majority_of_cast, p.tally.seats], [50_000_000n, 50_000_000n, [true], [5n]]);
  assert.equal(p.casting_vote[0].toText(), alice.getPrincipal().toText(), "the casting vote is the head's");
  // Two yes of five seats: not m of n, but more yes than no.
  await everyone(carried, ['Yes', 'Yes', 'No', 'Abstain']);
  assert.equal(await finalize(carried), 'Accepted');
  const oneYes = await file(plenary);
  await everyone(oneYes, ['Yes', 'Abstain', 'Abstain', 'Abstain']);
  assert.equal(await finalize(oneYes), 'Accepted');
  const lost = await file(plenary);
  await everyone(lost, ['Yes', 'No', 'No', 'Abstain']);
  assert.equal(await finalize(lost), 'Rejected');
});

test("a plenary's quorum counts over its policy's n, not the members seated", async () => {
  // Half of the four seated is two votes, half of the five seats three.
  const quiet = await file(plenary);
  await vote(alice, quiet, 'Yes');
  await vote(bob, quiet, 'Yes');
  const heard = await file(plenary);
  await vote(alice, heard, 'Yes');
  await vote(bob, heard, 'Yes');
  await vote(carol, heard, 'Abstain');
  await pastTheDeadline();
  assert.equal(await finalize(quiet), 'Rejected');
  assert.equal(await finalize(heard), 'Accepted');
});

test("a tie in the plenary gets a second vote, and only a tie in that one is the chair's to decide", async () => {
  /** Ties a first vote, with the chair voting yes, and returns the proposal as its second vote opens. */
  const tied = async () => {
    const id = await file(plenary);
    const first = await proposal(id);
    await everyone(id, ['Yes', 'No', 'Yes', 'No']);
    const second = ok(await as(alice).ggg_proposal_finalize(id));
    assert.equal(tag(second.status), 'Voting', "the chair's yes does not decide a first tie");
    assert.deepEqual([second.first_vote[0].yes, second.first_vote[0].no], [2n, 2n]);
    assert.deepEqual([second.tally.yes, second.tally.no, second.tally.abstain], [0n, 0n, 0n]);
    assert.equal(second.deadline[0] - second.opens_at[0], first.deadline[0] - first.opens_at[0], 'the second vote lasts as long as the first');
    const detail = ok(await as(alice).ggg_proposal_get({ id, cursor: [], limit: [] }))[0];
    assert.equal(detail.votes.length, 0, 'every member votes again');
    return id;
  };

  const chairYes = await tied();
  await everyone(chairYes, ['Yes', 'No', 'Abstain', 'Abstain']);
  assert.equal(await finalize(chairYes), 'Accepted');

  const chairNo = await tied();
  await everyone(chairNo, ['No', 'Yes', 'Abstain', 'Abstain']);
  assert.equal(await finalize(chairNo), 'Rejected');

  const decided = await tied();
  await everyone(decided, ['No', 'Yes', 'Yes', 'Abstain']);
  assert.equal(await finalize(decided), 'Accepted', 'a second vote that does not tie is decided by its majority');

  const chairAway = await tied();
  await vote(bob, chairAway, 'Yes');
  await vote(carol, chairAway, 'No');
  await vote(dave, chairAway, 'Abstain');
  await pastTheDeadline();
  assert.equal(await finalize(chairAway), 'Rejected', 'without the chair, a second tie rejects');
});

test("a proposer tightens the plenary's rule, never loosens it", async () => {
  // An absolute majority, three of the five seats, on top of more yes than no.
  const absolute = { ...plenary, threshold_of: [{ Eligible: null }] };
  const short = await file(absolute);
  const p = await proposal(short);
  assert.deepEqual([tag(p.threshold_of), p.majority_of_cast], ['Eligible', [true]]);
  await everyone(short, ['Yes', 'Yes', 'No', 'Abstain']);
  assert.equal(await finalize(short), 'Rejected');
  const reached = await file(absolute);
  await everyone(reached, ['Yes', 'Yes', 'Yes', 'No']);
  assert.equal(await finalize(reached), 'Accepted');

  // A higher quorum: four of the five seats.
  const quorate = await file({ ...plenary, quorum: [80_000_000n] });
  await everyone(quorate, ['Yes', 'Yes', 'No', 'Abstain']);
  const unquorate = await file({ ...plenary, quorum: [80_000_000n] });
  await vote(alice, unquorate, 'Yes');
  await vote(bob, unquorate, 'Yes');
  await vote(carol, unquorate, 'No');
  await pastTheDeadline();
  assert.equal(await finalize(quorate), 'Accepted');
  assert.equal(await finalize(unquorate), 'Rejected');

  refusedWith(await as(alice).ggg_proposal_create(motion({ ...plenary, threshold: [40_000_000n] })), 'InvalidArgument');
  refusedWith(await as(alice).ggg_proposal_create(motion({ ...plenary, quorum: [40_000_000n] })), 'InvalidArgument');
});
