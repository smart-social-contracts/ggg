// Attributes (model §2, I-PRV-1, D29) on PocketIC: a member submits one, the holders of
// attribute.review read the pending ones with their kind and value, the person reads their own, the
// reviewer decides, and the audit log never holds a kind or a value.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { idlFactory } from '../idl/ggg.js';

const alice = Ed25519KeyIdentity.generate();
const bob = Ed25519KeyIdentity.generate();
const stranger = Ed25519KeyIdentity.generate();

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
const none = { cursor: [], limit: [] };
const submission = (kind, value) => ({ kind, value, issuer: ['the regional government'], ref: 'doc-1', expires_at: [] });
const pending = async (who) => ok(await as(who).ggg_attribute_pending_list(none)).items;
const own = async (who, kind = null) => ok(await as(who).ggg_attribute_list({ kind: kind ? [kind] : [], ...none, on_behalf_of: [] })).items;
let submitted;

test('a member submits an attribute, pending review', async () => {
  submitted = ok(await as(alice).ggg_attribute_submit(submission('large_family', 'general')));
  assert.equal(tag(submitted.status), 'Pending');
  assert.equal(submitted.kind, 'large_family');
  refusedWith(await as(alice).ggg_attribute_submit(submission('', 'x')), 'InvalidArgument');
  refusedWith(await as(alice).ggg_attribute_submit(submission('x', '')), 'InvalidArgument');
  refusedWith(await as(stranger).ggg_attribute_submit(submission('a', 'b')), 'Forbidden');
});

test('the holders of attribute.review read the pending attributes with kind and value; the person reads their own', async () => {
  const [seen] = await pending(bob);
  assert.deepEqual([seen.id, seen.kind, seen.value], [submitted.id, 'large_family', 'general']);
  refusedWith(await as(stranger).ggg_attribute_pending_list(none), 'Forbidden');
  assert.deepEqual((await own(alice)).map((a) => a.id), [submitted.id]);
  assert.deepEqual(await own(bob), []); // not his
  assert.deepEqual(await own(alice, 'other'), []);
});

test('a review decides a pending attribute once, and never one\'s own', async () => {
  refusedWith(await as(alice).ggg_attribute_review({ attribute: submitted.id, status: { Verified: null } }), 'Forbidden');
  const verified = ok(await as(bob).ggg_attribute_review({ attribute: submitted.id, status: { Verified: null } }));
  assert.equal(tag(verified.status), 'Verified');
  assert.equal(verified.verified_at.length, 1);
  assert.deepEqual(await pending(bob), []);
  assert.equal(tag((await own(alice))[0].status), 'Verified');
  refusedWith(await as(bob).ggg_attribute_review({ attribute: submitted.id, status: { Rejected: null } }), 'Conflict');
  refusedWith(await as(bob).ggg_attribute_review({ attribute: 'A-999', status: { Verified: null } }), 'NotFound');
  refusedWith(await as(stranger).ggg_attribute_review({ attribute: submitted.id, status: { Verified: null } }), 'Forbidden');
  const rejected = ok(await as(alice).ggg_attribute_submit(submission('student', 'full_time')));
  assert.equal(tag(ok(await as(bob).ggg_attribute_review({ attribute: rejected.id, status: { Rejected: null } })).status), 'Rejected');
  assert.deepEqual((await own(alice, 'student')).map((a) => tag(a.status)), ['Rejected']);
});

test('the audit log keeps an attribute\'s id, never its kind or value', async () => {
  const events = ok(await as(alice).ggg_events({ cursor: [], limit: [100] })).items;
  const about = events.filter((e) => ['attribute_submit', 'attribute_review'].includes(e.op));
  assert.equal(about.length, 4);
  const text = JSON.stringify(about, (_, x) => (typeof x === 'bigint' ? `${x}n` : x));
  for (const secret of ['large_family', 'general', 'student', 'full_time']) assert.ok(!text.includes(secret), `${secret} is not in the audit log`);
  assert.ok(text.includes(submitted.id));
});

test('the pending list pages by id, so deciding a page skips none', async () => {
  const ids = [];
  for (const kind of ['disability', 'student', 'veteran']) ids.push(ok(await as(alice).ggg_attribute_submit(submission(kind, 'yes'))).id);
  const first = ok(await as(bob).ggg_attribute_pending_list({ cursor: [], limit: [2] }));
  assert.deepEqual(first.items.map((a) => a.id), ids.slice(0, 2));
  assert.deepEqual(first.next, [ids[1]]);
  for (const id of ids.slice(0, 2)) ok(await as(bob).ggg_attribute_review({ attribute: id, status: { Verified: null } }));
  const second = ok(await as(bob).ggg_attribute_pending_list({ cursor: first.next, limit: [2] }));
  assert.deepEqual(second.items.map((a) => a.id), [ids[2]]);
  assert.deepEqual(second.next, []);
  refusedWith(await as(bob).ggg_attribute_pending_list({ cursor: ['2'], limit: [] }), 'InvalidArgument');
});
