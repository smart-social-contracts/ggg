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

/** The interface of a caller built before links existed: ProposalCreateArgs without a links field. */
const callerWithoutLinks = ({ IDL: idl }) => {
  const [, create] = idlFactory({ IDL: idl })._fields.find(([name]) => name === 'ggg_proposal_create');
  const args = idl.Record(Object.fromEntries(create.argTypes[0]._fields.filter(([key]) => key !== 'links')));
  return idl.Service({ ggg_proposal_create: idl.Func([args], create.retTypes, []) });
};

let server;
let pic;
let as;
let asOldCaller;

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const canisterId = await pic.createCanister();
  const wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  const arg = IDL.encode([IDL.Vec(IDL.Principal)], [[alice.getPrincipal(), bob.getPrincipal()]]);
  await pic.installCode({ canisterId, wasm, arg });
  as = (identity) => pic.createActor({ idlFactory, canisterId, sender: identity.getPrincipal() });
  asOldCaller = (identity) => pic.createActor({ idlFactory: callerWithoutLinks, canisterId, sender: identity.getPrincipal() });
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
const create = (identity, links) =>
  as(identity).ggg_proposal_create({
    title: 'A proposal',
    description: '',
    department: [],
    action: { Motion: null },
    effective_at: [],
    links: links ? [links] : [],
    on_behalf_of: [],
  });
const file = async (identity, links) => ok(await create(identity, links));
const withdraw = async (identity, id) => ok(await as(identity).ggg_proposal_withdraw({ proposal: id, on_behalf_of: [] }));
const detail = async (id) => ok(await as(alice).ggg_proposal_get({ id, cursor: [], limit: [] }))[0];
const linkedFrom = (id, args = {}) => as(alice).ggg_proposal_linked_from({ id, cursor: [], limit: [], ...args });

test('a caller that sends no links field files a proposal with no links', async () => {
  const id = ok(await asOldCaller(alice).ggg_proposal_create({
    title: 'From an older caller',
    description: '',
    department: [],
    action: { Motion: null },
    effective_at: [],
    on_behalf_of: [],
  }));
  assert.deepEqual((await detail(id)).proposal.links, []);
});

test('a replacement is listed with its links, and the replaced proposal points forward to it', async () => {
  const old = await file(alice);
  await withdraw(alice, old);
  const next = await file(alice, [link('Replaces', old)]);
  assert.deepEqual((await detail(next)).proposal.links, [link('Replaces', old)]);
  assert.deepEqual((await detail(old)).replaced_by, [next]);
  assert.deepEqual((await detail(next)).replaced_by, []);
  assert.deepEqual(ok(await linkedFrom(old))[0].items, [link('Replaces', next)]);
  const listed = ok(await as(alice).ggg_proposal_list({ cursor: [], limit: [100], status: [] })).items.find((p) => p.id === next);
  assert.deepEqual(listed.links, [link('Replaces', old)]);
});

test('relates to shows on both proposals, and the other side is listed oldest first', async () => {
  const target = await file(alice);
  const first = await file(alice, [link('RelatesTo', target)]);
  const second = await file(bob, [link('RelatesTo', target)]);
  assert.deepEqual(ok(await linkedFrom(target))[0].items, [link('RelatesTo', first), link('RelatesTo', second)]);
  assert.deepEqual((await detail(target)).replaced_by, []);
  assert.deepEqual((await detail(second)).proposal.links, [link('RelatesTo', target)]);
});

test('only the proposer replaces a withdrawn proposal, and only once it is withdrawn', async () => {
  const open = await file(alice);
  refusedWith(await create(alice, [link('Replaces', open)]), 'Conflict');
  await withdraw(alice, open);
  refusedWith(await create(bob, [link('Replaces', open)]), 'Forbidden');
  ok(await create(alice, [link('Replaces', open)]));
});

test('a withdrawn proposal is replaced once', async () => {
  const old = await file(alice);
  await withdraw(alice, old);
  const first = await file(alice, [link('Replaces', old)]);
  refusedWith(await create(alice, [link('Replaces', old)]), 'Conflict');
  // Relating to it is still fine, and the replacement stays the one that replaced it.
  await file(alice, [link('RelatesTo', old)]);
  assert.deepEqual((await detail(old)).replaced_by, [first]);
});

test('if the replacement is withdrawn too, a new proposal replaces the replacement, not the first one', async () => {
  const a = await file(alice);
  await withdraw(alice, a);
  const b = await file(alice, [link('Replaces', a)]);
  await withdraw(alice, b);
  refusedWith(await create(alice, [link('Replaces', a)]), 'Conflict'); // A is already replaced, by B
  const c = await file(alice, [link('Replaces', b)]);
  assert.deepEqual((await detail(a)).replaced_by, [b]);
  assert.deepEqual((await detail(b)).replaced_by, [c]);
  assert.deepEqual((await detail(c)).replaced_by, []);
  assert.deepEqual(ok(await linkedFrom(a))[0].items, [link('Replaces', b)]);
  assert.deepEqual(ok(await linkedFrom(b))[0].items, [link('Replaces', c)]);
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

test('links from other proposals are not limited, do not block a replacement, and are read a page at a time', async () => {
  const target = await file(alice);
  const linking = [];
  for (let i = 0; i < 40; i++) linking.push(await file(i % 2 ? alice : bob, [link('RelatesTo', target)]));
  await withdraw(alice, target);
  const replacement = await file(alice, [link('Replaces', target)]);

  const seen = [];
  let cursor = [];
  let pages = 0;
  for (;;) {
    const page = ok(await linkedFrom(target, { cursor, limit: [15] }))[0];
    assert.ok(page.items.length <= 15);
    seen.push(...page.items);
    pages += 1;
    if (!page.next.length) break;
    cursor = page.next;
  }
  assert.equal(pages, 3);
  assert.deepEqual(seen, [...linking.map((id) => link('RelatesTo', id)), link('Replaces', replacement)]);
  assert.deepEqual((await detail(target)).replaced_by, [replacement]);

  refusedWith(await linkedFrom(target, { cursor: ['not-a-cursor'] }), 'InvalidArgument');
  assert.deepEqual(ok(await linkedFrom('no-such-proposal')), []);
});
