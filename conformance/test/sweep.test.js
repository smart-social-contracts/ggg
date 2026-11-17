// Quarter → capital sweeps on PocketIC (model I-FED-5 to 7): a capital and a quarter, both the fixture, and a
// small ICRC-1 ledger (fixture/ledger.mo) that can drop its answers. A sweep moves the quarter's money once,
// is booked on both sides with its block, waits for a capital that does not answer, finds a transfer whose
// answer was lost instead of sending it again, and, unanswered past the ledger's deduplication window, is
// never sent again but waits for a person to resolve it. The suite's S1 and W31 cover what any GOS shows.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { PocketIc, PocketIcServer } from '@dfinity/pic';
import { idlFactory } from '../idl/ggg.js';

const DAY_MS = 24 * 3600 * 1000;
const FEE = 10n;
const KEEP = 1_000n;
const alice = Ed25519KeyIdentity.generate();
const minter = Ed25519KeyIdentity.generate();

const ledgerIdl = ({ IDL }) => {
  const Account = IDL.Record({ owner: IDL.Principal, subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)) });
  const TransferArg = IDL.Record({
    from_subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)),
    to: Account,
    amount: IDL.Nat,
    fee: IDL.Opt(IDL.Nat),
    memo: IDL.Opt(IDL.Vec(IDL.Nat8)),
    created_at_time: IDL.Opt(IDL.Nat64),
  });
  const TransferError = IDL.Variant({
    BadFee: IDL.Record({ expected_fee: IDL.Nat }),
    BadBurn: IDL.Record({ min_burn_amount: IDL.Nat }),
    InsufficientFunds: IDL.Record({ balance: IDL.Nat }),
    TooOld: IDL.Null,
    CreatedInFuture: IDL.Record({ ledger_time: IDL.Nat64 }),
    Duplicate: IDL.Record({ duplicate_of: IDL.Nat }),
    TemporarilyUnavailable: IDL.Null,
    GenericError: IDL.Record({ error_code: IDL.Nat, message: IDL.Text }),
  });
  const Answer = IDL.Variant({ Answer: IDL.Null, ApplyThenDrop: IDL.Null, DropOnly: IDL.Null });
  return IDL.Service({
    icrc1_balance_of: IDL.Func([Account], [IDL.Nat], ['query']),
    icrc1_transfer: IDL.Func([TransferArg], [IDL.Variant({ Ok: IDL.Nat, Err: TransferError })], []),
    set_answer: IDL.Func([Answer], [], []),
  });
};

let server;
let pic;
let capitalId;
let quarterId;
let ledgerId;
let capital;
let quarter;
let ledger;
// What was minted to the quarter, and how many transfers moved money from it.
let minted = 0n;
let moves = 0n;

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const read = (name) => readFileSync(new URL(`../fixture/${name}`, import.meta.url));
  ledgerId = await pic.createCanister();
  await pic.installCode({ canisterId: ledgerId, wasm: read('ledger.wasm'), arg: IDL.encode([IDL.Principal], [minter.getPrincipal()]) });
  const initTypes = [IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))];
  const arg = IDL.encode(initTypes, [[alice.getPrincipal()], []]);
  capitalId = await pic.createCanister();
  quarterId = await pic.createCanister();
  await pic.installCode({ canisterId: capitalId, wasm: read('ggg_fixture.wasm'), arg });
  await pic.installCode({ canisterId: quarterId, wasm: read('ggg_fixture.wasm'), arg });
  capital = (sender = alice.getPrincipal()) => pic.createActor({ idlFactory, canisterId: capitalId, sender });
  quarter = pic.createActor({ idlFactory, canisterId: quarterId, sender: alice.getPrincipal() });
  ledger = pic.createActor({ idlFactory: ledgerIdl, canisterId: ledgerId, sender: minter.getPrincipal() });
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
const refusedWith = (result, error) => {
  assert.ok('Err' in result, `expected Err ${error}, got Ok`);
  assert.equal(tag(result.Err), error);
};

const account = (owner) => ({ owner, subaccount: [] });
const balance = (owner) => ledger.icrc1_balance_of(account(owner));
const mint = async (amount) => {
  ok(await ledger.icrc1_transfer({ from_subaccount: [], to: account(quarterId), amount, fee: [], memo: [], created_at_time: [] }));
  minted += amount;
};
const rule = { fund: 'GENERAL', symbol: 'REALM', into: 'GENERAL', keep: KEEP };
const configure = (actor, sweep) => actor.ggg_treasury_configure({ epoch: [], anchor_month: [], source_fund: [], auto_allocate: [], sweep: [sweep] });
/** Sweeps on the quarter and returns each sweep it touched, as [id, status]. */
const sweepNow = async () => ok(await quarter.ggg_quarter_sweep({ fund: [] })).map((s) => [s.id, tag(s.status)]);
const sweepOn = async (actor, id) => ok(await actor.ggg_sweep_list({ cursor: [], limit: [100], quarter: [], status: [] })).items.find((s) => s.id === id);
const entriesOf = async (actor, sweep) => ok(await actor.ggg_ledger_view({ cursor: [], limit: [100], transaction: [], symbol: [], kind: [], fund: [], period: [] })).items.filter((e) => e.sweep[0] === sweep);
const sum = (items, field) => items.reduce((total, e) => total + e[field], 0n);

test('a capital sets the sweep rules, and a quarter that joins it sweeps by them', async () => {
  for (const realm of [capital(), quarter]) {
    ok(await realm.ggg_token_register({ symbol: 'REALM', ledger: ledgerId, indexer: [], decimals: [], fee: [FEE] }));
    ok(await realm.ggg_fund_create({ fund: 'GENERAL', name: [], kind: [], department: [] }));
  }
  refusedWith(await configure(capital(), [rule]), 'InvalidArgument'); // not a capital yet
  refusedWith(await quarter.ggg_quarter_sweep({ fund: [] }), 'Conflict'); // not a quarter yet
  ok(await capital().ggg_quarter_register({ canister: quarterId, name: ['North'] }));
  refusedWith(await configure(capital(), [{ ...rule, into: 'NOWHERE' }]), 'NotFound');
  refusedWith(await configure(capital(), [rule, rule]), 'InvalidArgument');
  ok(await configure(capital(), [rule]));
  refusedWith(await configure(quarter, [rule]), 'InvalidArgument'); // a quarter sets no rules
  ok(await quarter.ggg_quarter_join_federation({ capital: capitalId, name: [] }));
  refusedWith(await capital().ggg_quarter_sweep({ fund: [] }), 'Conflict'); // a capital does not sweep
  const info = await quarter.ggg_realm_info();
  assert.deepEqual([info.is_quarter, (await capital().ggg_realm_info()).is_capital], [true, true]);
  // `sweep` is the category of a sweep's own entries: no transfer names it.
  const transfer = { fund: 'GENERAL', to: { kind: 'Organization', id: 'buildco' }, amount: 1n, symbol: [], category: ['sweep'], description: [], contract: [], on_behalf_of: [], due_at: [], committed: [] };
  refusedWith(await quarter.ggg_transfer_create(transfer), 'InvalidArgument');
});

test("a sweep moves the quarter's money once, all but what it keeps, and both sides book it", async () => {
  await mint(100_000n);
  assert.deepEqual(await sweepNow(), [['SW-1', 'Booked']]);
  moves += 1n;
  assert.deepEqual([await balance(quarterId), await balance(capitalId)], [KEEP, 100_000n - KEEP - FEE]);
  const sent = await sweepOn(quarter, 'SW-1');
  const booked = await sweepOn(capital(), `${quarterId.toText()}/SW-1`);
  assert.deepEqual([sent.amount, sent.fee, booked.amount], [98_990n, FEE, 98_990n]);
  assert.equal(booked.block[0], sent.block[0], 'both sides keep the block');
  assert.equal(tag(booked.status), 'Booked');
  // The quarter books the amount out with the fee; the capital books the amount in.
  const out = await entriesOf(quarter, 'SW-1');
  assert.deepEqual([sum(out, 'debit'), sum(out, 'credit')], [99_000n, 99_000n]);
  assert.deepEqual(out.filter((e) => e.category === 'ledger_fee').map((e) => e.debit), [FEE]);
  const into = await entriesOf(capital(), booked.id);
  assert.deepEqual([sum(into, 'debit'), sum(into, 'credit')], [98_990n, 98_990n]);
  // One sweep per rule and epoch: sweeping again moves nothing.
  await mint(5_000n);
  assert.deepEqual(await sweepNow(), []);
  assert.equal(await balance(quarterId), KEEP + 5_000n);
});

test('when the capital does not answer, the money reaches it and its books wait for the report', async () => {
  await pic.advanceTime(DAY_MS);
  await pic.stopCanister({ canisterId: capitalId });
  assert.deepEqual(await sweepNow(), [['SW-2', 'Sent']]);
  moves += 1n;
  assert.equal(await balance(quarterId), KEEP);
  await pic.startCanister({ canisterId: capitalId });
  assert.deepEqual(await sweepNow(), [['SW-2', 'Booked']]);
  assert.equal(tag((await sweepOn(capital(), `${quarterId.toText()}/SW-2`)).status), 'Booked');
});

test('a sweep whose answer was lost is sent again as the same transfer, and the ledger moves it once', async () => {
  await pic.advanceTime(DAY_MS);
  await mint(20_000n);
  const before = await balance(capitalId);
  await ledger.set_answer({ ApplyThenDrop: null });
  assert.deepEqual(await sweepNow(), [['SW-3', 'Sending']]);
  assert.equal(await balance(capitalId), before + 19_990n, 'the ledger applied it');
  await ledger.set_answer({ Answer: null });
  assert.deepEqual(await sweepNow(), [['SW-3', 'Booked']]);
  moves += 1n;
  assert.equal(await balance(capitalId), before + 19_990n, 'and moved it once');
  assert.ok((await sweepOn(quarter, 'SW-3')).block.length === 1);
});

test('a sweep still unanswered past the window is never sent again, and holds its rule until resolved', async () => {
  await pic.advanceTime(DAY_MS);
  await mint(30_000n);
  const before = [await balance(quarterId), await balance(capitalId)];
  await ledger.set_answer({ DropOnly: null });
  assert.deepEqual(await sweepNow(), [['SW-4', 'Sending']]);
  await ledger.set_answer({ Answer: null });
  await pic.advanceTime(DAY_MS);
  // A new epoch, but no new sweep: SW-4's outcome is unknown, and it is not sent again.
  assert.deepEqual(await sweepNow(), [['SW-4', 'NeedsCheck']]);
  assert.deepEqual(await sweepNow(), [['SW-4', 'NeedsCheck']]);
  assert.deepEqual([await balance(quarterId), await balance(capitalId)], before, 'nothing moved');
  assert.deepEqual((await sweepOn(quarter, 'SW-4')).block, []);

  refusedWith(await quarter.ggg_sweep_resolve({ sweep: 'SW-404', block: [] }), 'NotFound');
  refusedWith(await quarter.ggg_sweep_resolve({ sweep: 'SW-1', block: [] }), 'Conflict');
  // A person found no such transfer on the ledger: it failed, and the rule sweeps again.
  ok(await quarter.ggg_sweep_resolve({ sweep: 'SW-4', block: [] }));
  assert.equal(tag((await sweepOn(quarter, 'SW-4')).status), 'Failed');
  assert.deepEqual(await sweepNow(), [['SW-5', 'Booked']]);
  moves += 1n;
  assert.equal(await balance(quarterId), KEEP);
  // The quarter's and the capital's money together changed only by the ledger's fees.
  assert.equal((await balance(quarterId)) + (await balance(capitalId)), minted - moves * FEE);
});

test('the capital books a report once, and only from a registered quarter', async () => {
  const booked = await sweepOn(quarter, 'SW-1');
  const report = { ...booked, status: { Sent: null }, reported_at: [] };
  refusedWith(await capital().ggg_quarter_sweep_report(report), 'Forbidden');
  const asQuarter = capital(quarterId);
  refusedWith(await asQuarter.ggg_quarter_sweep_report(booked), 'InvalidArgument'); // not Sent
  assert.equal(ok(await asQuarter.ggg_quarter_sweep_report(report)).id, `${quarterId.toText()}/SW-1`);
  refusedWith(await asQuarter.ggg_quarter_sweep_report({ ...report, amount: report.amount + 1n }), 'Conflict');
  const reports = ok(await capital().ggg_sweep_list({ cursor: [], limit: [100], quarter: [quarterId.toText()], status: [] })).items;
  assert.equal(reports.length, 4, 'SW-1, SW-2, SW-3 and SW-5, each booked once');
});
