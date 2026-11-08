// The rule that decides a proposal (I-GOV-3), on PocketIC with four members: over the eligible voters a tie
// at the threshold rejects, a clear majority accepts, and absentees count against, where over the votes
// cast they would not. The suite's W18 to W20 cover what is stored; this covers what it decides.
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

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const canisterId = await pic.createCanister();
  const wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  const arg = IDL.encode([IDL.Vec(IDL.Principal)], [members.map((m) => m.getPrincipal())]);
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

/** Files a Motion as Alice, with the realm's rule unless `rule` says otherwise. */
const file = async (rule = {}) =>
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
    casting_vote: [],
    effective_at: [],
    links: [],
    on_behalf_of: [],
    ...rule,
  }));
const vote = async (voter, id, choice) => ok(await as(voter).ggg_proposal_vote({ proposal: id, choice: { [choice]: null }, on_behalf_of: [] }));
const finalize = async (id) => tag(ok(await as(alice).ggg_proposal_finalize(id)).status);
const pastTheDeadline = async () => {
  await pic.setTime((await pic.getTime()) + 8 * DAY_MS);
  await pic.tick();
};
const eligible = { threshold_of: [{ Eligible: null }] };

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
