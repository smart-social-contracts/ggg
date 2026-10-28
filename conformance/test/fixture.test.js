import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { runSuite } from '../src/suite.js';

const wasm = (name) => readFileSync(new URL(`../fixture/${name}.wasm`, import.meta.url));

let server;
let pic;
let host;
let canisterId;
let brokenId;
const member = Ed25519KeyIdentity.generate();

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  canisterId = await pic.createCanister();
  const arg = IDL.encode([IDL.Vec(IDL.Principal)], [[member.getPrincipal()]]);
  await pic.installCode({ canisterId, wasm: wasm('ggg_fixture'), arg });
  brokenId = await pic.createCanister();
  await pic.installCode({ canisterId: brokenId, wasm: wasm('broken'), arg: IDL.encode([], []) });
  host = `http://localhost:${await pic.makeLive()}`;
});

after(async () => {
  await pic?.tearDown();
  await server?.stop();
});

const run = (options) => runSuite({ host, canisterId, fetchRootKey: true, ...options });
const outcomes = (results) => Object.fromEntries(results.map((r) => [r.id, r.outcome]));
const failures = (results) => results.filter((r) => r.outcome === 'fail').map((r) => `${r.id}: ${r.detail}`);

test('the fixture passes the read-only checks', async () => {
  const results = await run({});
  assert.deepEqual(failures(results), []);
  const o = outcomes(results);
  assert.equal(o.D1, 'pass');
  assert.equal(o.D2, 'warn');
  assert.equal(o.R1, 'pass');
  assert.equal(o.W1, 'skip');
});

test('the fixture passes every check with a member identity', async () => {
  const results = await run({ writes: true, member });
  assert.deepEqual(failures(results), []);
  const o = outcomes(results);
  for (const id of ['M1', 'W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8', 'W9', 'W10', 'W11', 'W12']) {
    assert.equal(o[id], 'pass', id);
  }
});

test('once a proposal exists, it is listed, found and its votes paginate', async () => {
  const o = outcomes(await run({}));
  for (const id of ['P1', 'P2', 'P4', 'V1']) assert.equal(o[id], 'pass', id);
});

test('every list paginates, rejects a malformed cursor, and lookups of unknown ids return null', async () => {
  const results = await run({ member });
  assert.deepEqual(failures(results), []);
  const lists = results.filter((r) => /^L\d+$/.test(r.id));
  assert.equal(lists.length, 25);
  const skipped = lists.filter((r) => r.outcome === 'skip').map((r) => r.title);
  assert.deepEqual(skipped, ['ggg_crypto_access paginates']);
  const events = lists.find((r) => r.title === 'ggg_events paginates');
  assert.match(events.detail, /^[1-9]\d* listed$/);
  const o = outcomes(results);
  assert.equal(o.C1, 'pass');
  assert.equal(o.G1, 'pass');
});

test('a canister that breaks GGG fails', async () => {
  const results = await run({ canisterId: brokenId });
  const o = outcomes(results);
  for (const id of ['D1', 'R1', 'M1', 'M2', 'P1', 'P3', 'P5', 'L1', 'C1', 'G1']) assert.equal(o[id], 'fail', id);
  assert.match(results.find((r) => r.id === 'D1').detail, /GGG missing/);
  assert.match(results.find((r) => r.id === 'R1').detail, /name is empty/);
});

test('a non-member is refused, which the suite reports as a skip', async () => {
  const results = await run({ writes: true, member: Ed25519KeyIdentity.generate() });
  assert.deepEqual(failures(results), []);
  const o = outcomes(results);
  assert.equal(o.W1, 'pass');
  assert.equal(o.W9, 'pass');
  for (const id of ['W2', 'W5', 'W6', 'W7', 'W8']) assert.equal(o[id], 'skip', id);
});
