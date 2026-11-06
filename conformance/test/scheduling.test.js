// The life of a proposal with an effective_at, driven on PocketIC with its own clock.
// The fixture decides a vote only after its deadline (7 days), so the tests move the clock forward.
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

/** Files a proposal as Alice, with Alice voting yes. `days` is when it takes effect, counted from now. */
async function file({ action = motion, days = null } = {}) {
  const effective_at = days === null ? [] : [(await nowNs()) + BigInt(days * DAY_MS) * 1_000_000n];
  const id = ok(await as(alice).ggg_proposal_create({
    title: 'A proposal',
    description: '',
    department: [],
    action,
    effective_at,
    on_behalf_of: [],
  }));
  ok(await as(alice).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
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
  const args = { title: 'Late', description: '', department: [], action: motion, on_behalf_of: [] };
  refusedWith(await as(alice).ggg_proposal_create({ ...args, effective_at: [1n] }), 'InvalidArgument');
  refusedWith(await as(alice).ggg_proposal_create({ ...args, effective_at: [await nowNs()] }), 'InvalidArgument');
});

test('without an effective_at, an accepted proposal can be executed at once', async () => {
  const id = await file();
  await wait(8);
  assert.equal(await finalize(id), 'Accepted');
  assert.equal(tag(ok(await execute(id)).status), 'Executed');
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

test('another proposal stops a scheduled one before its time, and it is never executed', async () => {
  const target = await file({ action: stopping('0'), days: 60 });
  const stopper = await file({ action: stopping(target) });
  await wait(8);
  await finalize(target);
  assert.equal(await finalize(stopper), 'Accepted');
  assert.equal(await status(target), 'ExecutionScheduled');
  const executed = ok(await execute(stopper));
  assert.equal(tag(executed.status), 'Executed');
  assert.equal(await status(target), 'Withdrawn');
  await wait(60);
  refusedWith(await execute(target), 'Conflict');
  assert.equal(await status(target), 'Withdrawn');
});

test('proposal_stop is refused for a proposal that is not scheduled, for an unknown one and for a stranger', async () => {
  const id = await file();
  refusedWith(await as(bob).ggg_proposal_stop(id), 'Conflict');
  refusedWith(await as(bob).ggg_proposal_stop('no-such-proposal'), 'NotFound');
  refusedWith(await as(Ed25519KeyIdentity.generate()).ggg_proposal_stop(id), 'Forbidden');
  assert.equal(await status(id), 'Voting');
});

test('a vote that ends after effective_at expires the proposal, whatever was decided', async () => {
  const early = await file({ action: stopping('0'), days: 3 }); // effective before the 7-day vote ends
  const late = await file({ action: stopping('0'), days: 8 }); // effective after the deadline, but decided later
  await wait(9);
  assert.equal(await finalize(early), 'Expired');
  assert.equal(await finalize(late), 'Expired');
  refusedWith(await execute(early), 'Conflict');
  refusedWith(await execute(late), 'Conflict');
});

test('a proposal decided before effective_at is scheduled, though effective_at is near', async () => {
  const id = await file({ action: stopping('0'), days: 8 });
  await wait(7.5);
  assert.equal(await finalize(id), 'ExecutionScheduled');
});

test('a motion with an effective_at stays Accepted, and is executed at that time, not before', async () => {
  const id = await file({ days: 30 });
  await wait(8);
  assert.equal(await finalize(id), 'Accepted');
  refusedWith(await execute(id), 'Conflict');
  await wait(23);
  assert.equal(tag(ok(await execute(id)).status), 'Executed');
});
