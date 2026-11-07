// The life of a proposal with an effective_at, driven on PocketIC with its own clock.
// The fixture decides a vote after its deadline (7 days), or earlier once both members have voted, so
// the tests move the clock forward.
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
  await pic.tick();
};

const motion = { Motion: null };
const stopping = (id) => ({ Call: { method: 'ggg_proposal_stop', arg: new Uint8Array(IDL.encode([IDL.Text], [id])) } });

/**
 * Files a proposal as Alice, with Alice voting yes, and Bob too when `everyone` is set (then every
 * eligible member has voted). `days` is when it takes effect, counted from now.
 */
async function file({ action = motion, days = null, everyone = false } = {}) {
  const effective_at = days === null ? [] : [(await nowNs()) + BigInt(days * DAY_MS) * 1_000_000n];
  const id = ok(await as(alice).ggg_proposal_create({
    title: 'A proposal',
    description: '',
    department: [],
    action,
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
const finalize = async (id) => tag(ok(await as(bob).ggg_proposal_finalize(id)).status);
const execute = (id) => as(bob).ggg_proposal_execute(id);

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
  const args = { title: 'Late', description: '', department: [], action: motion, links: [], on_behalf_of: [] };
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
  const executed = ok(await execute(stopper));
  assert.equal(tag(executed.status), 'Executed');
  assert.equal(await status(stopper), 'Executed');
  // The target was scheduled for later, and the stopper's action ended it.
  assert.equal(await status(target), 'Withdrawn');
  refusedWith(await execute(target), 'Conflict');
});

test('without an effective_at, an accepted proposal with an action executes at once, and can stop a scheduled one', async () => {
  const target = await file({ action: stopping('0'), days: 60 });
  const stopper = await file({ action: stopping(target) });
  await wait(8);
  await finalize(target);
  assert.equal(await finalize(stopper), 'Accepted');
  assert.equal(await status(target), 'ExecutionScheduled');
  const executed = ok(await execute(stopper));
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
  const early = await file({ action: stopping('0'), days: 3, everyone: true }); // finalized early, but after it
  await wait(4);
  assert.equal(await finalize(early), 'Expired');
  await wait(5);
  assert.equal(await finalize(deadline), 'Expired');
  refusedWith(await execute(deadline), 'Conflict');
  refusedWith(await execute(early), 'Conflict');
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
  assert.equal(tag(ok(await execute(stopper)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
});

test('a vote that ended before effective_at but is finalized after it is accepted and executes at once', async () => {
  const target = await file({ action: stopping('0'), days: 60 });
  const late = await file({ action: stopping(target), days: 8 }); // the vote ends on day 7, effective on day 8
  await wait(9);
  assert.equal(await finalize(target), 'ExecutionScheduled');
  assert.equal(await finalize(late), 'Accepted');
  assert.equal(tag(ok(await execute(late)).status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
});

test('a proposal decided before effective_at is scheduled, though its deadline is not far off', async () => {
  const id = await file({ action: stopping('0'), days: 8 });
  await wait(7.5);
  assert.equal(await finalize(id), 'ExecutionScheduled');
});
