// Organization kinds on PocketIC (model I-ORG-9): what an organization is when registered with a kind or
// without one, that its admins change it, and that a list filters by it. The suite's O2 covers the
// filter on any GOS.
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

const register = async (organization, kind) =>
  ok(await as(alice).ggg_organization_register({ organization, description: '', kind: kind ? [{ [kind]: null }] : [] }));
const edit = (identity, organization, kind) =>
  as(identity).ggg_organization_edit({ organization, description: [], admins: [], kind: [{ [kind]: null }] });
const listed = async (kind) =>
  ok(await as(alice).ggg_organization_list({ cursor: [], limit: [], status: [], kind: [{ [kind]: null }] })).items.map((o) => o.id);

test('an organization is registered with its kind, and Other without one', async () => {
  assert.equal(tag((await register('harbour-party', 'Party')).kind), 'Party');
  assert.equal(tag((await register('residents-group')).kind), 'Other');
  assert.equal(tag((await register('buildco', 'Company')).kind), 'Company');
  assert.deepEqual(await listed('Party'), ['harbour-party']);
  assert.deepEqual(await listed('Other'), ['residents-group']);
  assert.deepEqual(await listed('Union'), []);
});

test("an organization's admins change its kind, and nobody else", async () => {
  await register('neighbours', 'Company');
  refusedWith(await edit(bob, 'neighbours', 'Association'), 'Forbidden');
  assert.equal(tag(ok(await edit(alice, 'neighbours', 'Association')).kind), 'Association');
  const detail = ok(await as(bob).ggg_organization_get({ id: 'neighbours', cursor: [], limit: [] }))[0];
  assert.equal(tag(detail.organization.kind), 'Association');
  assert.ok((await listed('Association')).includes('neighbours'));
  assert.ok(!(await listed('Company')).includes('neighbours'));
});
