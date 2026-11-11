// Proposal tags on PocketIC (model I-GOV-15): what only the fixture can show, such as a list that
// filters by any of several tags together with a status, and who may replace a proposal's tags. The
// suite's W27 and W28 cover the rest.
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
  if ('Err' in result) assert.fail(`expected Ok, got Err ${tag(result.Err)}`);
  return result.Ok;
};
const refusedWith = (result, error) => {
  assert.ok('Err' in result, 'expected Err, got Ok');
  assert.equal(tag(result.Err), error);
};

const file = async (tags) =>
  ok(await as(alice).ggg_proposal_create({
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
    tags: [tags],
    on_behalf_of: [],
  }));
const listed = async (tags, status = []) =>
  ok(await as(alice).ggg_proposal_list({ cursor: [], limit: [100], status, tags: [tags] })).items.map((p) => p.id);

test('a list by tags holds every proposal that carries any of them, and only those', async () => {
  const parks = await file(['parks', 'district-2']);
  const roads = await file(['roads', 'district-3']);
  const both = await file(['parks', 'roads']);
  const untagged = await file([]);
  assert.deepEqual(await listed(['district-2', 'district-3']), [parks, roads]);
  assert.deepEqual(await listed(['parks']), [parks, both]);
  assert.deepEqual(await listed(['Parks']), [], 'tags are compared exactly');
  const all = await listed([]);
  for (const id of [parks, roads, both, untagged]) assert.ok(all.includes(id), `an empty list of tags filters nothing, but ${id} is missing`);
});

test('a list by tags and a status holds the proposals that match both', async () => {
  const open = await file(['budget']);
  const withdrawn = await file(['budget']);
  ok(await as(alice).ggg_proposal_withdraw({ proposal: withdrawn, on_behalf_of: [] }));
  assert.deepEqual(await listed(['budget'], [{ Withdrawn: null }]), [withdrawn]);
  assert.deepEqual(await listed(['budget'], [{ Voting: null }]), [open]);
});

test("a member may not replace another's tags, and nobody an open proposal's", async () => {
  const id = await file(['parks']);
  refusedWith(await as(bob).ggg_proposal_set_tags({ proposal: id, tags: ['roads'], on_behalf_of: [] }), 'Forbidden');
  refusedWith(await as(alice).ggg_proposal_set_tags({ proposal: id, tags: ['roads'], on_behalf_of: [] }), 'Conflict');
  const { proposal } = ok(await as(alice).ggg_proposal_get({ id, cursor: [], limit: [] }))[0];
  assert.deepEqual(proposal.tags, ['parks']);
});
