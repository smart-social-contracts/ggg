// Proposal links on PocketIC: what only the fixture can show, such as who may replace whose proposal
// and the limits on how many links a proposal has. The suite's W15 to W17 cover the rest.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { idlFactory } from '../idl/ggg.js';

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
  if ('Err' in result) assert.fail(`expected Ok, got Err ${tag(result.Err)}`);
  return result.Ok;
};
const refusedWith = (result, error) => {
  assert.ok('Err' in result, 'expected Err, got Ok');
  assert.equal(tag(result.Err), error);
};

const link = (kind, proposal) => ({ kind: { [kind]: null }, proposal });
const create = (identity, links = []) =>
  as(identity).ggg_proposal_create({
    title: 'A proposal',
    description: '',
    department: [],
    action: { Motion: null },
    effective_at: [],
    links,
    on_behalf_of: [],
  });
const file = async (identity, links = []) => ok(await create(identity, links));
const withdraw = async (identity, id) => ok(await as(identity).ggg_proposal_withdraw({ proposal: id, on_behalf_of: [] }));
const detail = async (id) => ok(await as(alice).ggg_proposal_get({ id, cursor: [], limit: [] }))[0];

test('a replacement is listed with its links, and the replaced proposal points forward to it', async () => {
  const old = await file(alice);
  await withdraw(alice, old);
  const next = await file(alice, [link('Replaces', old)]);
  assert.deepEqual((await detail(next)).proposal.links, [link('Replaces', old)]);
  assert.deepEqual((await detail(old)).linked_from, [link('Replaces', next)]);
  const listed = ok(await as(alice).ggg_proposal_list({ cursor: [], limit: [100], status: [] })).items.find((p) => p.id === next);
  assert.deepEqual(listed.links, [link('Replaces', old)]);
});

test('relates to shows on both proposals, and the other side is listed oldest first', async () => {
  const target = await file(alice);
  const first = await file(alice, [link('RelatesTo', target)]);
  const second = await file(bob, [link('RelatesTo', target)]);
  assert.deepEqual((await detail(target)).linked_from, [link('RelatesTo', first), link('RelatesTo', second)]);
  assert.deepEqual((await detail(second)).proposal.links, [link('RelatesTo', target)]);
});

test('only the proposer replaces a withdrawn proposal, and only once it is withdrawn', async () => {
  const open = await file(alice);
  refusedWith(await create(alice, [link('Replaces', open)]), 'Conflict');
  await withdraw(alice, open);
  refusedWith(await create(bob, [link('Replaces', open)]), 'Forbidden');
  ok(await create(alice, [link('Replaces', open)]));
});

test('a link to an unknown proposal, or the same proposal twice, is refused', async () => {
  const target = await file(alice);
  refusedWith(await create(alice, [link('RelatesTo', 'no-such-proposal')]), 'NotFound');
  refusedWith(await create(alice, [link('RelatesTo', target), link('Replaces', target)]), 'InvalidArgument');
});

test('a proposal has at most 16 links of its own', async () => {
  const targets = [];
  for (let i = 0; i < 17; i++) targets.push(await file(alice));
  const relating = (ids) => ids.map((id) => link('RelatesTo', id));
  ok(await create(alice, relating(targets.slice(0, 16))));
  refusedWith(await create(alice, relating(targets)), 'InvalidArgument');
});

test('at most 32 proposals link to one proposal', async () => {
  const target = await file(alice);
  for (let i = 0; i < 32; i++) await file(alice, [link('RelatesTo', target)]);
  assert.equal((await detail(target)).linked_from.length, 32);
  refusedWith(await create(alice, [link('RelatesTo', target)]), 'Conflict');
});
