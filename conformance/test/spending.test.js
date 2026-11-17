// Spending stages on PocketIC (model I-FIN-9, I-FIN-10): a budget line's reserved and committed money,
// transfers charged to it from its committed money or its available credit and refused past it, and
// scheduled transfers, owed until they are paid or cancelled. The suite's B1, T1 and W30 cover what any
// GOS shows.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { idlFactory } from '../idl/ggg.js';

const alice = Ed25519KeyIdentity.generate();

let server;
let pic;
let as;

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const canisterId = await pic.createCanister();
  const wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  const arg = IDL.encode([IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))], [[alice.getPrincipal()], []]);
  await pic.installCode({ canisterId, wasm, arg });
  as = (identity) => pic.createActor({ idlFactory, canisterId, sender: identity.getPrincipal() });
});

after(async () => {
  await pic?.tearDown();
  await server?.stop();
});

const tag = (variant) => Object.keys(variant)[0];
const ok = (result) => {
  if ('Err' in result) assert.fail(`expected Ok, got Err ${tag(result.Err)}: ${JSON.stringify(Object.values(result.Err)[0])}`);
  return result.Ok;
};
const refusedWith = (result, error, message) => {
  assert.ok('Err' in result, 'expected Err, got Ok');
  assert.equal(tag(result.Err), error);
  if (message) assert.match(result.Err[error], message);
};

const DAY = 24n * 3600n * 1_000_000_000n;
const now = async () => BigInt(await pic.getTime()) * 1_000_000n;

const realm = () => as(alice);
const line = async (fund) => ok(await realm().ggg_budget_list({ cursor: [], limit: [], fund: [fund], period: [] })).items.find((b) => tag(b.status) === 'Adopted');
const figures = (b) => [b.reserved, b.committed, b.actual];
const stage = (budget, reserve, commit) => realm().ggg_budget_stage({ budget, reserve, commit });
const pay = (fund, amount, { committed = false, due_at = null } = {}) =>
  realm().ggg_transfer_create({
    fund,
    to: { kind: 'Organization', id: 'buildco' },
    amount,
    symbol: [],
    category: ['capital'],
    description: [],
    contract: [],
    on_behalf_of: [],
    due_at: due_at === null ? [] : [due_at],
    committed: committed ? [true] : [],
  });
const transfer = async (fund, id) => ok(await realm().ggg_transfer_list({ cursor: [], limit: [], fund: [fund], status: [] })).items.find((t) => t.id === id);

/** A fund of the root, so every governed call applies at once, with one adopted capital line of 1 000. */
async function adoptedLine(fund, period) {
  ok(await realm().ggg_fund_create({ fund, name: [], kind: [], department: [] }));
  ok(await realm().ggg_period_open({ period, name: [], starts_at: 0n, ends_at: 0n }));
  ok(await realm().ggg_budget_draft({ fund, period, category: 'capital', kind: { Expense: null }, planned: 1_000n }));
  ok(await realm().ggg_budget_propose({ period, years: [], fund: [fund] }));
  return (await line(fund)).id;
}

test("a line's money is reserved, then committed, never past the line and never below nothing", async () => {
  const id = await adoptedLine('ROADS', 'P1');
  assert.deepEqual(figures(await line('ROADS')), [0n, 0n, 0n]);
  ok(await stage(id, 400n, 0n));
  ok(await stage(id, -300n, 300n));
  assert.deepEqual(figures(await line('ROADS')), [100n, 300n, 0n]);
  refusedWith(await stage(id, 700n, 0n), 'Conflict', new RegExp(`${id}.*100 above`));
  refusedWith(await stage(id, -200n, 0n), 'Conflict');
  refusedWith(await stage(id, 0n, 0n), 'InvalidArgument');
  refusedWith(await stage('B-404', 1n, 0n), 'NotFound');
  assert.deepEqual(figures(await line('ROADS')), [100n, 300n, 0n]);
});

test('a transfer is charged to its line, from its committed money or its credit, and refused when short', async () => {
  const id = (await line('ROADS')).id; // reserved 100, committed 300: 600 available
  assert.equal(tag(ok(await pay('ROADS', 500n))), 'Done');
  refusedWith(await pay('ROADS', 150n), 'Conflict', new RegExp(`${id} \\(ROADS, P1, capital\\) has 100 available; the transfer of 150 is 50 short`));
  ok(await pay('ROADS', 250n, { committed: true }));
  refusedWith(await pay('ROADS', 100n, { committed: true }), 'Conflict', /has 50 committed; the transfer of 100 is 50 short/);
  assert.deepEqual(figures(await line('ROADS')), [100n, 50n, 750n]);
});

test('a scheduled transfer is owed until paid, and cancelling it gives its money back', async () => {
  const due = (await now()) + 30n * DAY;
  refusedWith(await pay('ROADS', 10n, { due_at: (await now()) - DAY }), 'InvalidArgument');

  const cancelled = ok(await pay('ROADS', 30n, { committed: true, due_at: due })).Done[0];
  assert.deepEqual(figures(await line('ROADS')), [100n, 20n, 780n], 'charged when the obligation is recognised');
  const owed = ok(await realm().ggg_transfer_list({ cursor: [], limit: [], fund: ['ROADS'], status: [{ Scheduled: null }] })).items;
  assert.deepEqual(owed.map((t) => [t.id, t.due_at, t.committed]), [[cancelled, [due], true]]);
  assert.equal(tag(ok(await realm().ggg_transfer_revert({ transfer: cancelled, reason: [] }))), 'Done');
  assert.equal(tag((await transfer('ROADS', cancelled)).status), 'Cancelled');
  assert.deepEqual(figures(await line('ROADS')), [100n, 50n, 750n], 'back to the committed money it came from');
  refusedWith(await realm().ggg_transfer_pay(cancelled), 'Conflict');

  const paid = ok(await pay('ROADS', 100n, { due_at: due })).Done[0];
  assert.deepEqual(figures(await line('ROADS')), [100n, 50n, 850n]);
  assert.equal(tag(ok(await realm().ggg_transfer_pay(paid)).status), 'Completed');
  assert.deepEqual(figures(await line('ROADS')), [100n, 50n, 850n], 'paying moves no budget money');
  refusedWith(await realm().ggg_transfer_pay(paid), 'Conflict');
  refusedWith(await realm().ggg_transfer_revert({ transfer: paid, reason: [] }), 'Conflict');
  refusedWith(await realm().ggg_transfer_pay('T-404'), 'NotFound');
});

test('a line that replaces another carries its money, and is refused when it plans less', async () => {
  const draft = (planned) => realm().ggg_budget_draft({ fund: 'ROADS', period: 'P1', category: 'capital', kind: { Expense: null }, planned });
  const adopt = () => realm().ggg_budget_propose({ period: 'P1', years: [], fund: ['ROADS'] });
  ok(await draft(1_500n));
  ok(await adopt());
  const replacing = await line('ROADS');
  assert.deepEqual([replacing.planned, ...figures(replacing)], [1_500n, 100n, 50n, 850n]);
  ok(await draft(900n));
  refusedWith(await adopt(), 'Conflict', new RegExp(`plans 900, less than the 1000 that ${replacing.id} holds`));
  assert.equal((await line('ROADS')).id, replacing.id);
});
