// The life of a proposal with an effective_at, driven on PocketIC with its own clock.
// The fixture decides a vote after its deadline (7 days), or earlier once both members have voted, so
// the tests move the clock forward.
//
// A GOS may settle a proposal as its vote ends, or run an accepted action in the same step as the
// finalize, or leave it for proposal_execute (I-GOV-12). The tests go through finalize, finalizeAndRun
// and runScheduled, which accept all three; this fixture finalizes, and leaves the action for
// proposal_execute. A GOS that settles as a vote ends runs a stopper then, so the tests finalize a
// target before the votes on the proposal that stops it, and cast the votes on a late stop only after
// its target has run.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { idlFactory } from '../idl/ggg.js';

const DAY_MS = 24 * 3600 * 1000;
const DAY_NS = BigInt(DAY_MS) * 1_000_000n;

const alice = Ed25519KeyIdentity.generate();
const bob = Ed25519KeyIdentity.generate();

let server;
let pic;
let as;

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const canisterId = await pic.createCanister();
  const wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  const arg = IDL.encode([IDL.Vec(IDL.Principal)], [[alice.getPrincipal(), bob.getPrincipal()]]);
  await pic.installCode({ canisterId, wasm, arg });
  as = (identity) => pic.createActor({ idlFactory, canisterId, sender: identity.getPrincipal() });
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

const nowNs = async () => BigInt(await pic.getTime()) * 1_000_000n;
const wait = async (days) => {
  await pic.setTime((await pic.getTime()) + days * DAY_MS);
  // A GOS that settles proposals with timers may need a round for each timer a timer sets.
  for (let round = 0; round < 5; round++) await pic.tick();
};

const motion = { Motion: null };
const stopping = (id) => ({ Call: { method: 'ggg_proposal_stop', arg: new Uint8Array(IDL.encode([IDL.Text], [id])) } });

/**
 * Files a proposal as Alice, with Alice voting yes, and Bob too when `everyone` is set (then every
 * eligible member has voted). `days` is when it takes effect, counted from now. `department` is the
 * proposal's scope.
 */
async function file({ action = motion, days = null, everyone = false, department = null } = {}) {
  const effective_at = days === null ? [] : [(await nowNs()) + BigInt(days * DAY_MS) * 1_000_000n];
  const id = ok(await as(alice).ggg_proposal_create({
    title: 'A proposal',
    description: '',
    department: department ? [department] : [],
    action,
    kind: [],
    matter: [],
    threshold: [],
    quorum: [],
    threshold_of: [],
    effective_at,
    links: [],
    on_behalf_of: [],
  }));
  for (const voter of everyone ? [alice, bob] : [alice]) {
    ok(await as(voter).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
  }
  return id;
}

const get = async (id) => ok(await as(alice).ggg_proposal_get({ id, cursor: [], limit: [] }))[0].proposal;
const status = async (id) => tag((await get(id)).status);
const execute = (id) => as(bob).ggg_proposal_execute(id);
const RAN = ['Executed', 'Failed'];

/**
 * The proposal after a finalize that the GOS refused with Conflict: it settled the proposal as its vote
 * ended (I-GOV-12), so the proposal already shows how it ended.
 */
async function settledAlready(id, refused) {
  refusedWith(refused, 'Conflict');
  const settled = await get(id);
  assert.notEqual(tag(settled.status), 'Voting', `${id} was refused a finalize, but its vote is open`);
  return settled;
}

/** Returns the proposal once its vote is closed: as finalize replies, or as the GOS had already settled it. */
async function finalizeProposal(id) {
  const finalized = await as(bob).ggg_proposal_finalize(id);
  return 'Ok' in finalized ? finalized.Ok : settledAlready(id, finalized);
}
const finalize = async (id) => tag((await finalizeProposal(id)).status);

/** The proposal, which has run its action already: a later proposal_execute is a Conflict. */
async function alreadyRan(proposal) {
  assert.ok(RAN.includes(tag(proposal.status)), `${proposal.id} is ${tag(proposal.status)}`);
  refusedWith(await execute(proposal.id), 'Conflict');
  return proposal;
}

/**
 * Finalizes a proposal whose effective_at, if it has one, has come by now, and returns the proposal once
 * the action has run. A finalize that settles it now replies Accepted, and proposal_execute runs the
 * action, or Executed or Failed, and a later proposal_execute is a Conflict. A finalize refused with
 * Conflict means the GOS settled it as the vote ended, perhaps before its effective_at, and then it
 * shows Executed or Failed, or ExecutionScheduled until the GOS runs it, which runScheduled follows.
 */
async function finalizeAndRun(id) {
  const finalized = await as(bob).ggg_proposal_finalize(id);
  if ('Err' in finalized) {
    const settled = await settledAlready(id, finalized);
    return tag(settled.status) === 'ExecutionScheduled' ? runScheduled(id) : alreadyRan(settled);
  }
  if (tag(finalized.Ok.status) === 'Accepted') return ok(await execute(id));
  return alreadyRan(finalized.Ok);
}

/**
 * Returns the proposal whose action was scheduled, once its effective_at has come and the action has
 * run: by proposal_execute, or by the GOS itself, which then refuses proposal_execute with Conflict.
 */
async function runScheduled(id) {
  const executed = await execute(id);
  if ('Ok' in executed) return executed.Ok;
  refusedWith(executed, 'Conflict');
  const proposal = await get(id);
  assert.ok(RAN.includes(tag(proposal.status)), `${id} is ${tag(proposal.status)}, but its effective_at has come`);
  return proposal;
}

/** Both members vote yes. */
async function approve(id) {
  for (const voter of [alice, bob]) ok(await as(voter).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
}

test('effective_at is stored with the proposal and never changes', async () => {
  const id = await file({ days: 30 });
  const before = (await get(id)).effective_at;
  assert.equal(before.length, 1);
  assert.ok(before[0] > (await nowNs()) + 29n * DAY_NS);
  await wait(8);
  await finalize(id);
  assert.deepEqual((await get(id)).effective_at, before);
});

test('an effective_at that is not in the future is refused', async () => {
  const args = {
    title: 'Late',
    description: '',
    department: [],
    action: motion,
    kind: [],
    matter: [],
    threshold: [],
    quorum: [],
    threshold_of: [],
    links: [],
    on_behalf_of: [],
  };
  refusedWith(await as(alice).ggg_proposal_create({ ...args, effective_at: [1n] }), 'InvalidArgument');
  refusedWith(await as(alice).ggg_proposal_create({ ...args, effective_at: [await nowNs()] }), 'InvalidArgument');
});

test('an accepted proposal with an action waits as ExecutionScheduled and executes at effective_at, not before', async () => {
  const target = await file({ action: stopping('0'), days: 40 });
  const stopper = await file({ action: stopping(target), days: 10 });
  await wait(8);
  assert.equal(await finalize(target), 'ExecutionScheduled');
  assert.equal(await finalize(stopper), 'ExecutionScheduled');
  refusedWith(await execute(stopper), 'Conflict');
  assert.equal(await status(stopper), 'ExecutionScheduled');
  await wait(3);
  assert.equal(tag((await runScheduled(stopper)).status), 'Executed');
  assert.equal(await status(stopper), 'Executed');
  // The target was scheduled for later, and the stopper's action ended it.
  assert.equal(await status(target), 'Withdrawn');
  refusedWith(await execute(target), 'Conflict');
});

test('without an effective_at, an accepted proposal with an action executes at once, and can stop a scheduled one', async () => {
  // The target is scheduled before the stopper's vote ends: a GOS that settles as the vote ends runs the stopper then.
  const target = await file({ action: stopping('0'), days: 60, everyone: true });
  assert.equal(await finalize(target), 'ExecutionScheduled');
  const stopper = await file({ action: stopping(target), everyone: true });
  const executed = await finalizeAndRun(stopper);
  assert.equal(tag(executed.status), 'Executed');
  assert.deepEqual(executed.result.map(tag), ['Reply']);
  assert.equal(await status(target), 'Withdrawn');
  await wait(60);
  refusedWith(await execute(target), 'Conflict');
  assert.equal(await status(target), 'Withdrawn');
});

test('proposal_stop replies Done without an id, and is refused when nothing is scheduled', async () => {
  const scheduled = await file({ action: stopping('0'), days: 40, everyone: true });
  await wait(1);
  assert.equal(await finalize(scheduled), 'ExecutionScheduled');
  assert.deepEqual(ok(await as(bob).ggg_proposal_stop(scheduled)), { Done: [] });
  assert.equal(await status(scheduled), 'Withdrawn');

  const open = await file();
  refusedWith(await as(bob).ggg_proposal_stop(open), 'Conflict');
  refusedWith(await as(bob).ggg_proposal_stop('no-such-proposal'), 'NotFound');
  refusedWith(await as(Ed25519KeyIdentity.generate()).ggg_proposal_stop(open), 'Forbidden');
  assert.equal(await status(open), 'Voting');
});

test('a motion stays Accepted, with or without an effective_at, and proposal_execute refuses it', async () => {
  const plain = await file();
  const dated = await file({ days: 30 });
  await wait(8);
  assert.equal(await finalize(plain), 'Accepted');
  assert.equal(await finalize(dated), 'Accepted');
  refusedWith(await execute(plain), 'Conflict');
  refusedWith(await execute(dated), 'Conflict');
  await wait(23);
  refusedWith(await execute(dated), 'Conflict');
  assert.equal(await status(dated), 'Accepted');
});

test('a vote that ends after effective_at expires the proposal, whatever was decided', async () => {
  const deadline = await file({ action: stopping('0'), days: 3 }); // the 7-day deadline is after effective_at
  const lastVote = await file({ action: stopping('0'), days: 3 }); // the last member votes after effective_at
  await wait(4);
  ok(await as(bob).ggg_proposal_vote({ proposal: lastVote, choice: { Yes: null }, on_behalf_of: [] }));
  await wait(5);
  assert.equal(await finalize(lastVote), 'Expired');
  assert.equal(await finalize(deadline), 'Expired');
  refusedWith(await execute(deadline), 'Conflict');
  refusedWith(await execute(lastVote), 'Conflict');
});

test('a finalizer who waits cannot expire a vote that ended before effective_at', async () => {
  const target = await file({ action: stopping('0'), days: 60, everyone: true });
  assert.equal(await finalize(target), 'ExecutionScheduled');
  const decided = await file({ action: stopping(target), days: 3, everyone: true }); // the vote ends on day 0
  await wait(4); // before the 7-day deadline, after effective_at
  assert.equal(tag((await finalizeAndRun(decided)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
});

test('once every eligible member has voted the vote has ended: no vote is accepted or replaced', async () => {
  const id = await file({ everyone: true });
  for (const voter of [alice, bob]) {
    refusedWith(await as(voter).ggg_proposal_vote({ proposal: id, choice: { No: null }, on_behalf_of: [] }), 'Conflict');
  }
  assert.deepEqual((await get(id)).tally, { yes: 2n, no: 0n, abstain: 0n, eligible: [2n] });
  assert.equal(await finalize(id), 'Accepted');
});

test('a proposal is finalized once', async () => {
  const id = await file({ everyone: true });
  assert.equal(await finalize(id), 'Accepted');
  refusedWith(await as(bob).ggg_proposal_finalize(id), 'Conflict');
  assert.equal(await status(id), 'Accepted');
});

test('in a department vote a no can be replaced, though two approvals are out of reach', async () => {
  const id = await file({ department: 'council' }); // the council decides 2 of 3; Alice votes yes
  ok(await as(alice).ggg_proposal_vote({ proposal: id, choice: { No: null }, on_behalf_of: [] })); // only Bob's yes is left
  assert.equal(await status(id), 'Voting');
  await approve(id);
  assert.equal(await finalize(id), 'Accepted');
});

test('a vote can be finalized early once every eligible member has voted, and is then scheduled', async () => {
  const target = await file({ action: stopping('0'), days: 40, everyone: true });
  const stopper = await file({ action: stopping(target), days: 3, everyone: true });
  const partial = await file({ action: stopping('0') });
  await wait(1);
  refusedWith(await as(bob).ggg_proposal_finalize(partial), 'Conflict'); // only Alice has voted
  assert.equal(await finalize(target), 'ExecutionScheduled');
  assert.equal(await finalize(stopper), 'ExecutionScheduled');
  refusedWith(await execute(stopper), 'Conflict');
  await wait(2.5);
  assert.equal(tag((await runScheduled(stopper)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
});

test('a vote that ended before effective_at but is finalized after it is accepted and executes at once', async () => {
  const target = await file({ action: stopping('0'), days: 60 });
  const late = await file({ action: stopping(target), days: 8 }); // the vote ends on day 7, effective on day 8
  await wait(9);
  await finalize(target); // ExecutionScheduled, or Withdrawn when the GOS has already run `late` by itself
  assert.equal(tag((await finalizeAndRun(late)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
});

test('a proposal decided before effective_at is scheduled, though its deadline is not far off', async () => {
  const id = await file({ action: stopping('0'), days: 8 });
  await wait(7.5);
  assert.equal(await finalize(id), 'ExecutionScheduled');
});

test('proposal_stop follows the policy of the department that owns the proposal', async () => {
  // The root decides alone, so a stop of a realm-wide proposal applies at once (above). The council
  // decides 2 of 3, so a stop of one of its proposals files a proposal of the council instead.
  const target = await file({ action: stopping('0'), days: 40, everyone: true, department: 'council' });
  await wait(1);
  assert.equal(await finalize(target), 'ExecutionScheduled');

  const filedId = ok(await as(bob).ggg_proposal_stop(target)).Proposed;
  assert.ok(filedId, 'a stop under a policy that is not direct files a proposal');
  assert.equal(await status(target), 'ExecutionScheduled');
  const filed = await get(filedId);
  assert.deepEqual(filed.department, ['council']);
  assert.equal(filed.action.Call.method, 'ggg_proposal_stop');
  assert.deepEqual(IDL.decode([IDL.Text], filed.action.Call.arg), [target]);

  // Once the council's proposal is accepted and executed, the scheduled proposal ends.
  await approve(filedId);
  assert.equal(tag((await finalizeAndRun(filedId)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');

  // Nothing is filed for a proposal that is not scheduled.
  const open = await file({ department: 'council' });
  refusedWith(await as(bob).ggg_proposal_stop(open), 'Conflict');
});

test('a stop proposal that runs after its target executed, or was withdrawn, ends Failed', async () => {
  const stopProposal = async (target) => ok(await as(bob).ggg_proposal_stop(target)).Proposed;
  // A GOS may run a stop proposal as its vote ends, so the votes on a late stop are cast only once its target
  // is no longer scheduled; finalizeAndRun then gets it run, whichever way the GOS settles.
  const failed = async (id) => {
    const ran = await finalizeAndRun(id);
    assert.equal(tag(ran.status), 'Failed');
    assert.deepEqual(ran.result.map(tag), ['Error']);
  };

  // The target takes effect before the stop proposal is finalized. Everything here is a council
  // proposal, so no council vote has to stop a realm-wide proposal (ggg#15).
  const far = await file({ action: stopping('0'), days: 60, everyone: true, department: 'council' });
  const executing = await file({ action: stopping(far), days: 3, everyone: true, department: 'council' });
  await wait(1);
  await finalize(far);
  assert.equal(await finalize(executing), 'ExecutionScheduled');
  const lateStop = await stopProposal(executing);
  await wait(2.5);
  assert.equal(tag((await runScheduled(executing)).status), 'Executed');
  await approve(lateStop);
  await failed(lateStop);
  assert.equal(await status(executing), 'Executed');

  // Another stop proposal ended the target first.
  const target = await file({ action: stopping('0'), days: 40, everyone: true, department: 'council' });
  assert.equal(await finalize(target), 'ExecutionScheduled');
  const first = await stopProposal(target);
  const second = await stopProposal(target);
  await approve(first);
  await approve(second);
  assert.equal(tag((await finalizeAndRun(first)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
  await failed(second);
  assert.equal(await status(target), 'Withdrawn');
});
