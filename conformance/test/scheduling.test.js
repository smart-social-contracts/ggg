// The life of a proposal with an effective_at, driven on PocketIC with its own clock; which proposal
// may carry a call on another's records (I-GOV-13); and which department governs a change to a
// department or a budget (model §1, D19).
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
  const arg = IDL.encode([IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))], [[alice.getPrincipal(), bob.getPrincipal()], []]);
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
 * Files a proposal as Alice and returns the reply. `days` is when it takes effect, counted from now.
 * `department` is the proposal's scope.
 */
async function create({ action = motion, days = null, department = null } = {}) {
  const effective_at = days === null ? [] : [(await nowNs()) + BigInt(days * DAY_MS) * 1_000_000n];
  return as(alice).ggg_proposal_create({
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
    tags: [],
    on_behalf_of: [],
  });
}

/**
 * Files a proposal as Alice, with Alice voting yes, and Bob too when `everyone` is set (then every
 * eligible member has voted).
 */
async function file({ everyone = false, ...proposal } = {}) {
  const id = ok(await create(proposal));
  for (const voter of everyone ? [alice, bob] : [alice]) {
    ok(await as(voter).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
  }
  return id;
}

/**
 * An action a department's proposal may carry (I-GOV-13): a stop of one of that department's own
 * proposals, here one that is never run. A realm-wide proposal may carry a stop of anything, even of
 * a proposal that does not exist, so those use stopping('0').
 */
const ownStop = async (department) => stopping(await file({ department }));

/** The department_edit arguments that move a department under `parent`, or give it a description. */
const move = (department, parent) => ({ department, parent: [parent], description: [], kind: [], head: [] });
const describe = (department, description) => ({ department, parent: [], description: [description], kind: [], head: [] });
const department = async (id) => ok(await as(alice).ggg_department_get({ id, cursor: [], limit: [] }))[0].department;
const argType = (method) => idlFactory({ IDL })._fields.find(([name]) => name === method)[1].argTypes[0];
const calling = (method, args) => ({ Call: { method, arg: new Uint8Array(IDL.encode([argType(method)], [args])) } });
const editing = (args) => calling('ggg_department_edit', args);
const budget = (period, fund = null) => ({ period, years: [], fund: fund ? [fund] : [] });
const fundArgs = (fund, department = null) => ({ fund, name: [], kind: [], department: department ? [department] : [] });
const lineArgs = (fund, period) => ({ fund, period, category: 'works', kind: { Expense: null }, planned: 1_000n });

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
    tags: [],
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
  assert.deepEqual((await get(id)).tally, { yes: 2n, no: 0n, abstain: 0n, eligible: [2n], seats: [] });
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
  const target = await file({ action: await ownStop('council'), days: 40, everyone: true, department: 'council' });
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
  // proposal: a council vote may not stop a realm-wide one (I-GOV-13).
  const far = await file({ action: await ownStop('council'), days: 60, everyone: true, department: 'council' });
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
  const target = await file({ action: await ownStop('council'), days: 40, everyone: true, department: 'council' });
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

test("a department's proposal cannot carry a stop of a realm-wide scheduled proposal", async () => {
  // The council's vote is a few seats', not the realm's (I-GOV-13).
  const realmWide = await file({ action: stopping('0'), days: 40, everyone: true });
  await wait(1);
  assert.equal(await finalize(realmWide), 'ExecutionScheduled');
  refusedWith(await create({ action: stopping(realmWide), department: 'council' }), 'Forbidden');
  assert.equal(await status(realmWide), 'ExecutionScheduled');
});

test("a realm-wide proposal stops a department's scheduled proposal", async () => {
  const target = await file({ action: await ownStop('council'), days: 40, everyone: true, department: 'council' });
  await wait(1);
  assert.equal(await finalize(target), 'ExecutionScheduled');
  const stopper = await file({ action: stopping(target), everyone: true });
  assert.equal(tag((await finalizeAndRun(stopper)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
});

test("a parent department's proposal stops a scheduled proposal of a department below it; a sibling's cannot", async () => {
  // Roads and parks are committees under the council.
  const target = await file({ action: await ownStop('roads'), days: 40, everyone: true, department: 'roads' });
  await wait(1);
  assert.equal(await finalize(target), 'ExecutionScheduled');
  refusedWith(await create({ action: stopping(target), department: 'parks' }), 'Forbidden');
  const stopper = await file({ action: stopping(target), everyone: true, department: 'council' });
  assert.equal(tag((await finalizeAndRun(stopper)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
});

test('a proposal whose department no longer governs its call when it runs ends Failed', async () => {
  const target = await file({ action: await ownStop('roads'), days: 40, everyone: true, department: 'roads' });
  const stopper = await file({ action: stopping(target), days: 3, everyone: true, department: 'council' });
  await wait(1);
  assert.equal(await finalize(target), 'ExecutionScheduled');
  assert.equal(await finalize(stopper), 'ExecutionScheduled');
  // Roads moves out from under the council before the stop runs: the council's vote no longer reaches it.
  assert.deepEqual(ok(await as(bob).ggg_department_edit(move('roads', 'root'))), { Done: [] });
  assert.deepEqual((await department('roads')).parent, ['root']);
  await wait(2.5);
  const ran = await runScheduled(stopper);
  assert.equal(tag(ran.status), 'Failed');
  assert.deepEqual(ran.result.map(tag), ['Error']);
  assert.equal(await status(target), 'ExecutionScheduled');
  // Back under the council, for the tests that follow.
  ok(await as(bob).ggg_department_edit(move('roads', 'council')));
  assert.deepEqual((await department('roads')).parent, ['council']);
});

test('a department edits itself under its own policy: alone at once, 2 of 3 through a proposal that replays the edit', async () => {
  assert.deepEqual(ok(await as(bob).ggg_department_edit(describe('roads', 'Roads and bridges.'))), { Done: [] });
  assert.equal((await department('roads')).description, 'Roads and bridges.');

  const filedId = ok(await as(bob).ggg_department_edit(describe('council', 'The town council.'))).Proposed;
  const filed = await get(filedId);
  assert.deepEqual(filed.department, ['council']);
  assert.equal(filed.action.Call.method, 'ggg_department_edit');
  assert.notEqual((await department('council')).description, 'The town council.');
  await approve(filedId);
  assert.equal(tag((await finalizeAndRun(filedId)).status), 'Executed');
  assert.equal((await department('council')).description, 'The town council.');
});

test('a change of parent is governed by the lowest department above the old and the new parent', async () => {
  // Roads moves under its sibling parks: the council is above both, and decides 2 of 3.
  refusedWith(await create({ action: editing(move('roads', 'parks')), department: 'parks' }), 'Forbidden');
  const filedId = ok(await as(bob).ggg_department_edit(move('roads', 'parks'))).Proposed;
  const filed = await get(filedId);
  assert.deepEqual(filed.department, ['council']);
  assert.deepEqual((await department('roads')).parent, ['council']);
  await approve(filedId);
  assert.equal(tag((await finalizeAndRun(filedId)).status), 'Executed');
  assert.deepEqual((await department('roads')).parent, ['parks']);

  // Back under the council: the council is above parks and is the council, so it decides again.
  const back = ok(await as(bob).ggg_department_edit(move('roads', 'council'))).Proposed;
  await approve(back);
  assert.equal(tag((await finalizeAndRun(back)).status), 'Executed');
  assert.deepEqual((await department('roads')).parent, ['council']);

  // A new parent that does not exist is NotFound, directly and as a proposal's action.
  refusedWith(await as(bob).ggg_department_edit(move('roads', 'no-such-department')), 'NotFound');
  refusedWith(await create({ action: editing(move('roads', 'no-such-department')), department: 'council' }), 'NotFound');
});

test('the parent rule is checked again when the move executes, and moves to and from the root are the root\'s', async () => {
  // The council files a move of roads under parks. Before it runs, the root moves roads out from under
  // the council (the root is above both parents, and decides alone): now the move is the root's too.
  const filedId = ok(await as(bob).ggg_department_edit(move('roads', 'parks'))).Proposed;
  assert.deepEqual(ok(await as(bob).ggg_department_edit(move('roads', 'root'))), { Done: [] });
  assert.deepEqual((await department('roads')).parent, ['root']);
  await approve(filedId);
  const ran = await finalizeAndRun(filedId);
  assert.equal(tag(ran.status), 'Failed');
  assert.deepEqual((await department('roads')).parent, ['root']);

  // From the root back under the council is the root's as well: a council proposal cannot carry it.
  refusedWith(await create({ action: editing(move('roads', 'council')), department: 'council' }), 'Forbidden');
  assert.deepEqual(ok(await as(bob).ggg_department_edit(move('roads', 'council'))), { Done: [] });
  assert.deepEqual((await department('roads')).parent, ['council']);
});

test('department_delete is governed by the parent, and a proposal of a deleted department carries nothing', async () => {
  refusedWith(await as(bob).ggg_department_delete('root'), 'InvalidArgument');
  refusedWith(await as(bob).ggg_department_delete('no-such-department'), 'NotFound');
  // This fixture deletes no department with departments below it.
  refusedWith(await as(bob).ggg_department_delete('council'), 'Conflict');

  const target = await file({ action: await ownStop('parks'), days: 40, everyone: true, department: 'parks' });
  await wait(1);
  assert.equal(await finalize(target), 'ExecutionScheduled');

  // Parks is under the council, which decides 2 of 3: the delete files a council proposal.
  const filedId = ok(await as(bob).ggg_department_delete('parks')).Proposed;
  assert.deepEqual((await get(filedId)).department, ['council']);
  await approve(filedId);
  assert.equal(tag((await finalizeAndRun(filedId)).status), 'Executed');
  assert.deepEqual(ok(await as(alice).ggg_department_get({ id: 'parks', cursor: [], limit: [] })), []);

  // The scheduled proposal of parks carries nothing now: nobody can stop it, and it fails when it runs.
  refusedWith(await as(bob).ggg_proposal_stop(target), 'NotFound');
  await wait(40);
  const ran = await runScheduled(target);
  assert.equal(tag(ran.status), 'Failed');
  assert.deepEqual(ran.result.map(tag), ['Error']);
});

test("a budget is governed by its fund's owner, or by the root for every fund's lines", async () => {
  // A fund of the root, created at once, and one of the council, whose 2 of 3 files a council proposal.
  assert.deepEqual(ok(await as(bob).ggg_fund_create(fundArgs('GENERAL'))), { Done: ['GENERAL'] });
  refusedWith(await as(bob).ggg_fund_create(fundArgs('GENERAL')), 'Conflict');
  const fund = ok(await as(bob).ggg_fund_create(fundArgs('COUNCIL', 'council'))).Proposed;
  assert.deepEqual((await get(fund)).department, ['council']);
  await approve(fund);
  assert.equal(tag((await finalizeAndRun(fund)).status), 'Executed');
  assert.deepEqual(ok(await as(alice).ggg_treasury_view({ cursor: [], limit: [] })).funds.map((f) => f.id).sort(), ['COUNCIL', 'GENERAL']);

  // Draft lines follow the fund's owner too.
  assert.equal(tag(ok(await as(bob).ggg_budget_draft(lineArgs('GENERAL', 'FY2027')))), 'Done');
  const line = ok(await as(bob).ggg_budget_draft(lineArgs('COUNCIL', 'FY2027'))).Proposed;
  await approve(line);
  assert.equal(tag((await finalizeAndRun(line)).status), 'Executed');
  refusedWith(await as(bob).ggg_budget_draft(lineArgs('NO-SUCH-FUND', 'FY2027')), 'NotFound');

  // The council proposes its own fund's budget under its policy; a committee below it cannot carry that.
  refusedWith(await create({ action: calling('ggg_budget_propose', budget('FY2027', 'COUNCIL')), department: 'roads' }), 'Forbidden');
  const adopt = ok(await as(bob).ggg_budget_propose(budget('FY2027', 'COUNCIL'))).Proposed;
  assert.deepEqual((await get(adopt)).department, ['council']);
  // Its lines are fixed at the filing: a second proposal finds no draft line of the fund left.
  refusedWith(await as(bob).ggg_budget_propose(budget('FY2027', 'COUNCIL')), 'Conflict');
  refusedWith(await as(bob).ggg_budget_propose(budget('FY2027', 'NO-SUCH-FUND')), 'NotFound');
  // A line drafted after the filing is not part of it: the vote adopts exactly the lines it filed, the
  // late line is still a draft, and the next proposal takes it.
  const late = ok(await as(bob).ggg_budget_draft(lineArgs('COUNCIL', 'FY2027'))).Proposed;
  await approve(late);
  assert.equal(tag((await finalizeAndRun(late)).status), 'Executed');
  await approve(adopt);
  assert.equal(tag((await finalizeAndRun(adopt)).status), 'Executed');
  const next = ok(await as(bob).ggg_budget_propose(budget('FY2027', 'COUNCIL'))).Proposed;
  assert.deepEqual((await get(next)).department, ['council']);

  // The whole-period budget is the root's: it adopts every fund's draft lines at once, never a line a
  // proposal holds, so the council's next proposal still finds its line when it runs.
  assert.deepEqual(ok(await as(bob).ggg_budget_propose(budget('FY2027'))), { Done: [] });
  refusedWith(await as(bob).ggg_budget_propose(budget('FY2027')), 'Conflict');
  await approve(next);
  assert.equal(tag((await finalizeAndRun(next)).status), 'Executed');

  // A department that owns a fund is never deleted, so no fund is left without an owner.
  assert.deepEqual(ok(await as(bob).ggg_fund_create(fundArgs('ROADS', 'roads'))), { Done: ['ROADS'] });
  refusedWith(await as(bob).ggg_department_delete('roads'), 'Conflict');
});

test('budget lines return to draft when their proposal ends without adopting them, and any proposal carrying budget_propose marks them', async () => {
  const draft = ok(await as(bob).ggg_budget_draft(lineArgs('COUNCIL', 'FY2028'))).Proposed;
  await approve(draft);
  assert.equal(tag((await finalizeAndRun(draft)).status), 'Executed');

  // Rejected: the lines go back to draft, and the fund's budget can be proposed again.
  const rejected = ok(await as(bob).ggg_budget_propose(budget('FY2028', 'COUNCIL'))).Proposed;
  refusedWith(await as(bob).ggg_budget_propose(budget('FY2028', 'COUNCIL')), 'Conflict');
  for (const voter of [alice, bob]) ok(await as(voter).ggg_proposal_vote({ proposal: rejected, choice: { No: null }, on_behalf_of: [] }));
  assert.equal(await finalize(rejected), 'Rejected');
  // Withdrawn: the same.
  const withdrawn = ok(await as(bob).ggg_budget_propose(budget('FY2028', 'COUNCIL'))).Proposed;
  ok(await as(bob).ggg_proposal_withdraw({ proposal: withdrawn, on_behalf_of: [] }));

  // A realm-wide proposal carrying the council fund's budget_propose marks the lines too, and adopts them.
  const carried = await file({ action: calling('ggg_budget_propose', budget('FY2028', 'COUNCIL')), everyone: true });
  refusedWith(await create({ action: calling('ggg_budget_propose', budget('FY2028', 'COUNCIL')) }), 'Conflict');
  assert.equal(tag((await finalizeAndRun(carried)).status), 'Executed');
  refusedWith(await as(bob).ggg_budget_propose(budget('FY2028', 'COUNCIL')), 'Conflict');
});

test('an adopted budget amends the extended lines and an earlier line of the same category, and is exhaustive for its fund', async () => {
  const open = (period) => as(bob).ggg_period_open({ period, name: [], starts_at: 0n, ends_at: 0n });
  const transfer = (fund, category) => ({
    fund,
    to: { kind: 'User', id: alice.getPrincipal().toText() },
    amount: 10n,
    symbol: [],
    category: category ? [category] : [],
    description: [],
    contract: [],
    on_behalf_of: [],
  });
  const spend = (fund, category) => as(bob).ggg_transfer_create(transfer(fund, category));
  const expense = (fund, period, category) => ({ ...lineArgs(fund, period), category });
  const revenue = (fund, period, category) => ({ ...expense(fund, period, category), kind: { Revenue: null } });
  const draft = async (args) => ok(await as(bob).ggg_budget_draft(args));
  const adopt = async (period, fund) => ok(await as(bob).ggg_budget_propose(budget(period, fund)));

  // Two funds of the root, so everything applies at once. P1: LIBRARY plans books and events (expenses)
  // and fees (revenue); ARCHIVE plans storage. A category is either revenue or expense.
  for (const fund of ['LIBRARY', 'ARCHIVE']) assert.deepEqual(ok(await as(bob).ggg_fund_create(fundArgs(fund))), { Done: [fund] });
  assert.deepEqual(ok(await open('P1')), { Done: ['P1'] });
  refusedWith(await open('P1'), 'Conflict');
  refusedWith(await as(bob).ggg_budget_extend('P1'), 'Conflict'); // no period before it
  for (const category of ['books', 'events']) await draft(expense('LIBRARY', 'P1', category));
  refusedWith(await as(bob).ggg_budget_draft(revenue('LIBRARY', 'P1', 'books')), 'InvalidArgument');
  await draft(revenue('LIBRARY', 'P1', 'fees'));
  await draft(expense('ARCHIVE', 'P1', 'storage'));
  await adopt('P1', 'LIBRARY');
  await adopt('P1', 'ARCHIVE');

  // P2 opens. The extension carries what stood at P1's end, fund by fund, but not a category P2 already
  // holds as the other kind: LIBRARY drafted events as revenue, so books and fees carry over, and storage.
  ok(await open('P2'));
  refusedWith(await as(bob).ggg_budget_extend('P9'), 'NotFound');
  await draft(revenue('LIBRARY', 'P2', 'events'));
  assert.equal(ok(await as(bob).ggg_budget_extend('P2')), 3n);
  refusedWith(await as(bob).ggg_budget_extend('P2'), 'Conflict'); // every fund has its lines
  // With only extended lines a fund spends as before, in any category.
  assert.deepEqual(ok(await spend('LIBRARY', 'music')), { Done: [] });

  // LIBRARY adopts its P2 budget: books and transfer as expenses, events as revenue. The extended lines
  // are amended. Only an adopted expense line allows spending; no category is the category "transfer".
  await draft(expense('LIBRARY', 'P2', 'books'));
  await draft(expense('LIBRARY', 'P2', 'transfer'));
  await adopt('P2', 'LIBRARY');
  assert.deepEqual(ok(await spend('LIBRARY', 'books')), { Done: [] });
  assert.deepEqual(ok(await spend('LIBRARY', null)), { Done: [] });
  refusedWith(await spend('LIBRARY', 'events'), 'Conflict'); // a revenue line
  refusedWith(await spend('LIBRARY', 'music'), 'Conflict'); // no line
  // A fund with only extended lines, and one with no budget, spend as before.
  assert.deepEqual(ok(await spend('ARCHIVE', 'anything')), { Done: [] });
  assert.deepEqual(ok(await spend('GENERAL', 'anything')), { Done: [] });
  // ledger_fee, the fee entry the realm books itself, is reserved: no transfer or budget line names it,
  // budget or not, and a proposal carrying one is refused at filing.
  refusedWith(await spend('LIBRARY', 'ledger_fee'), 'InvalidArgument');
  refusedWith(await spend('GENERAL', 'ledger_fee'), 'InvalidArgument');
  refusedWith(await as(bob).ggg_budget_draft(expense('LIBRARY', 'P2', 'ledger_fee')), 'InvalidArgument');
  refusedWith(await create({ action: calling('ggg_transfer_create', transfer('LIBRARY', 'ledger_fee')) }), 'InvalidArgument');
  refusedWith(await create({ action: calling('ggg_budget_draft', expense('LIBRARY', 'P2', 'ledger_fee')) }), 'InvalidArgument');

  // A later adopted books line, 2 000 now, amends the earlier one: one line stands per fund, period and
  // category, and books is still budgeted.
  await draft({ ...expense('LIBRARY', 'P2', 'books'), planned: 2_000n });
  await adopt('P2', 'LIBRARY');
  assert.deepEqual(ok(await spend('LIBRARY', 'books')), { Done: [] });

  // P3's extension carries the three LIBRARY lines that stood at P2's end (the newest books, transfer
  // and events; neither the amended fees nor the first books line comes back) and ARCHIVE's storage,
  // extended a second time.
  ok(await open('P3'));
  assert.equal(ok(await as(bob).ggg_budget_extend('P3')), 4n);
  refusedWith(await as(bob).ggg_budget_extend('P3'), 'Conflict');

  // Within one adoption too: LIBRARY drafts books twice for P3, 1 000 then 2 000, and adopts them
  // together; the later line amends the earlier one, and the adopted budget amends the three extended
  // lines. P4's extension carries one LIBRARY line, the newest books, and ARCHIVE's storage.
  await draft(expense('LIBRARY', 'P3', 'books'));
  await draft({ ...expense('LIBRARY', 'P3', 'books'), planned: 2_000n });
  await adopt('P3', 'LIBRARY');
  ok(await open('P4'));
  assert.equal(ok(await as(bob).ggg_budget_extend('P4')), 2n);
});
