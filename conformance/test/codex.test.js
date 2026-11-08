// codex_revert (model §11, D24) on PocketIC: a fixture holding three codices by checksum installs them
// in turn, then reverts to the one the active codex replaced, to an earlier one by checksum, and
// refuses an unknown one. The root decides alone, so each governed call applies at once.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { idlFactory } from '../idl/ggg.js';

const alice = Ed25519KeyIdentity.generate();
const bob = Ed25519KeyIdentity.generate();
const CODEX = [1, 2, 3].map((n) => `sha256:${String(n).repeat(64)}`);
const UNKNOWN = `sha256:${'f'.repeat(64)}`;

let server;
let pic;
let as;

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const canisterId = await pic.createCanister();
  const wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  const chapters = CODEX.map((checksum, i) => [checksum, [i + 1]]);
  const arg = IDL.encode([IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))], [[alice.getPrincipal(), bob.getPrincipal()], chapters]);
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

const install = (checksum) => as(bob).ggg_codex_install({ Package: { manifest: { Map: [] }, source: checksum } });
const revert = (checksum) => as(bob).ggg_codex_revert(checksum === undefined ? [] : [{ codex: checksum === null ? [] : [checksum] }]);
const status = async () => {
  const view = ok(await as(alice).ggg_codex_status({ cursor: [], limit: [] }));
  return { active: view.checksum[0] ?? null, history: view.history };
};
const argType = (method) => idlFactory({ IDL })._fields.find(([name]) => name === method)[1].argTypes[0];
const reverting = (checksum) => ({ Call: { method: 'ggg_codex_revert', arg: new Uint8Array(IDL.encode([argType('ggg_codex_revert')], [[{ codex: [checksum] }]])) } });
const proposal = (action, department = null) => as(alice).ggg_proposal_create({
  title: 'Revert',
  description: '',
  department: department ? [department] : [],
  action,
  kind: [],
  matter: [],
  threshold: [],
  quorum: [],
  threshold_of: [],
  effective_at: [],
  links: [],
  on_behalf_of: [],
});

test('a codex the realm holds is installed by its checksum, and the history keeps the earlier ones', async () => {
  assert.deepEqual(await status(), { active: null, history: [] });
  refusedWith(await revert(), 'Conflict');
  refusedWith(await install(UNKNOWN), 'InvalidArgument');
  refusedWith(await as(bob).ggg_codex_install({ Registry: { codex: 'agora', version: '1.0.0' } }), 'InvalidArgument');
  for (const checksum of CODEX) assert.deepEqual(ok(await install(checksum)), { Done: [checksum] });
  refusedWith(await install(CODEX[0]), 'Conflict');
  assert.deepEqual(await status(), { active: CODEX[2], history: [CODEX[0], CODEX[1]] });
});

test('a revert with no codex named restores the one the active codex replaced', async () => {
  assert.deepEqual(ok(await revert()), { Done: [] });
  assert.deepEqual(await status(), { active: CODEX[1], history: [CODEX[0], CODEX[2]] });
  // The same, with the argument present but empty.
  assert.deepEqual(ok(await revert(null)), { Done: [] });
  assert.deepEqual(await status(), { active: CODEX[0], history: [CODEX[1], CODEX[2]] });
  // The first codex replaced none.
  refusedWith(await revert(), 'Conflict');
});

test('a revert names any earlier codex by its checksum; an unknown one is NotFound', async () => {
  assert.deepEqual(ok(await revert(CODEX[2])), { Done: [] });
  assert.deepEqual(await status(), { active: CODEX[2], history: [CODEX[0], CODEX[1]] });
  refusedWith(await revert(UNKNOWN), 'NotFound');
  refusedWith(await revert(CODEX[2]), 'Conflict');
  refusedWith(await as(Ed25519KeyIdentity.generate()).ggg_codex_revert([]), 'Forbidden');
});

test('a revert is the realm\'s: a department\'s proposal cannot carry it, a realm-wide one executes it', async () => {
  refusedWith(await proposal(reverting(CODEX[0]), 'council'), 'Forbidden');
  const id = ok(await proposal(reverting(CODEX[0])));
  for (const voter of [alice, bob]) ok(await as(voter).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
  assert.equal(tag(ok(await as(bob).ggg_proposal_finalize(id)).status), 'Accepted');
  assert.equal(tag(ok(await as(bob).ggg_proposal_execute(id)).status), 'Executed');
  assert.deepEqual(await status(), { active: CODEX[0], history: [CODEX[1], CODEX[2]] });
});
