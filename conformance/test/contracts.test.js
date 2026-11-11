// Contract amendments on PocketIC (model I-GOV-16): what a contract's terms may become, what each
// amendment records, and that a proposal carrying an amendment is named in it; and the payments on a
// contract, which never exceed its value, so that no amendment sets it below them (I-FIN-11). The
// suite's W29, G1 and T2 cover what any GOS can show.
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
  if ('Err' in result) assert.fail(`expected Ok, got Err ${tag(result.Err)}: ${JSON.stringify(Object.values(result.Err)[0])}`);
  return result.Ok;
};
const refusedWith = (result, error, message) => {
  assert.ok('Err' in result, 'expected Err, got Ok');
  assert.equal(tag(result.Err), error);
  if (message) assert.match(result.Err[error], message);
};

const DAY = 24n * 3600n * 1_000_000_000n;
const JAN_2026 = 1_767_225_600_000_000_000n;
const spread = (...pairs) => pairs.map(([period, amount]) => ({ period, amount }));

/** Bike lane works: 50,000, 30,000 of it in FY2026 and 20,000 in FY2027, for 90 days. */
const create = (overrides = {}) =>
  as(alice).ggg_contract_create({
    title: 'Bike lane works',
    parties: [{ kind: 'Organization', id: 'buildco' }],
    mandate: [],
    kind: ['works'],
    procedure: ['open'],
    tender: [],
    value: 50_000n,
    symbol: 'REALM',
    terms_ref: 'doc:terms',
    terms_hash: 'sha256:00',
    starts_at: [JAN_2026],
    ends_at: [JAN_2026 + 90n * DAY],
    split: [spread(['FY2026', 30_000n], ['FY2027', 20_000n])],
    ...overrides,
  });
const amendArgs = (contract, terms) => ({ contract, value: [], split: [], starts_at: [], ends_at: [], ...terms });
const amend = (contract, terms) => as(alice).ggg_contract_amend(amendArgs(contract, terms));
const detail = async (id) => ok(await as(alice).ggg_contract_get({ id, cursor: [], limit: [] }))[0];

test('a contract is made with its value spread over periods, and a split that does not add up is refused', async () => {
  const contract = ok(await create());
  assert.deepEqual(contract.split, spread(['FY2026', 30_000n], ['FY2027', 20_000n]));
  const { amendments } = await detail(contract.id);
  assert.deepEqual(amendments, []);
  refusedWith(await create({ split: [spread(['FY2026', 30_000n])] }), 'InvalidArgument');
  refusedWith(await create({ split: [spread(['FY2026', 25_000n], ['FY2026', 25_000n])] }), 'InvalidArgument');
});

test('an amendment re-spreads a contract and moves its end, keeping its id, and records both sides', async () => {
  const { id } = ok(await create());
  const later = JAN_2026 + 180n * DAY;
  const reply = ok(await amend(id, { split: [spread(['FY2026', 10_000n], ['FY2027', 40_000n])], ends_at: [later] }));
  assert.equal(tag(reply), 'Done');
  const { contract, amendments } = await detail(id);
  assert.deepEqual([contract.id, contract.value, contract.split, contract.ends_at], [id, 50_000n, spread(['FY2026', 10_000n], ['FY2027', 40_000n]), [later]]);
  assert.equal(amendments.length, 1);
  const [amendment] = amendments;
  assert.deepEqual(reply.Done, [amendment.id]);
  assert.deepEqual(amendment.before.split, spread(['FY2026', 30_000n], ['FY2027', 20_000n]));
  assert.deepEqual(amendment.before.ends_at, [JAN_2026 + 90n * DAY]);
  assert.deepEqual([amendment.after.split, amendment.after.ends_at], [contract.split, [later]]);
  assert.deepEqual(amendment.proposal, [], 'the root decided directly, so no proposal carried it');
});

test("a spread contract's value changes only with a split that adds up to it", async () => {
  const { id } = ok(await create());
  refusedWith(await amend(id, { value: [60_000n] }), 'InvalidArgument');
  ok(await amend(id, { value: [60_000n], split: [spread(['FY2026', 30_000n], ['FY2027', 30_000n])] }));
  ok(await amend(id, { value: [55_000n], split: [[]] }));
  const { contract, amendments } = await detail(id);
  assert.deepEqual([contract.value, contract.split, amendments.length], [55_000n, [], 2]);
});

test('an amendment that changes nothing, ends before it starts or names an unknown contract is refused', async () => {
  const { id } = ok(await create());
  refusedWith(await amend(id, {}), 'InvalidArgument');
  refusedWith(await amend(id, { value: [50_000n] }), 'InvalidArgument');
  refusedWith(await amend(id, { ends_at: [JAN_2026 - DAY] }), 'InvalidArgument');
  const tooMany = Array.from({ length: 65 }, (_, i) => ({ period: `P${i}`, amount: i === 0 ? 50_000n : 0n }));
  refusedWith(await amend(id, { split: [tooMany] }), 'InvalidArgument');
  refusedWith(await amend('no-such-contract', { value: [1n] }), 'NotFound');
  assert.deepEqual((await detail(id)).amendments, []);
});

/** Files a realm-wide proposal that amends `contract`, and returns its id. */
async function proposeAmendment(contract, terms) {
  const call = { method: 'ggg_contract_amend', arg: new Uint8Array(IDL.encode(contractAmendType(), [amendArgs(contract, terms)])) };
  return ok(await as(alice).ggg_proposal_create({
    title: 'Amend the bike lane works',
    description: '',
    department: [],
    action: { Call: call },
    kind: [],
    matter: [],
    threshold: [],
    quorum: [],
    threshold_of: [],
    effective_at: [],
    links: [],
    tags: [],
    on_behalf_of: [],
  }));
}

/** Both members vote yes, then the proposal is finalized and executed; returns how the execution ended. */
async function carry(proposal) {
  for (const voter of [alice, bob]) ok(await as(voter).ggg_proposal_vote({ proposal, choice: { Yes: null }, on_behalf_of: [] }));
  assert.equal(tag(ok(await as(alice).ggg_proposal_finalize(proposal)).status), 'Accepted');
  return tag(ok(await as(alice).ggg_proposal_execute(proposal)).status);
}

test('a proposal that carries an amendment is named in it', async () => {
  const { id } = ok(await create());
  const proposal = await proposeAmendment(id, { value: [40_000n], split: [spread(['FY2026', 40_000n])] });
  assert.equal(await carry(proposal), 'Executed');
  const { contract, amendments } = await detail(id);
  assert.equal(contract.value, 40_000n);
  assert.deepEqual(amendments.map((a) => a.proposal), [[proposal]]);
});

test('a terminated contract is never amended, not by a proposal filed before it ended either', async () => {
  const { id } = ok(await create());
  const proposal = await proposeAmendment(id, { value: [40_000n], split: [[]] });
  ok(await as(alice).ggg_contract_terminate(id));
  refusedWith(await amend(id, { value: [40_000n], split: [[]] }), 'Conflict');
  assert.equal(await carry(proposal), 'Failed');
  assert.deepEqual((await detail(id)).amendments, []);
});

const now = async () => BigInt(await pic.getTime()) * 1_000_000n;

/** A fund of the root with no budget, so a transfer from it is charged to no line. */
const makeFund = async (fund) => ok(await as(alice).ggg_fund_create({ fund, name: [], kind: [], department: [] }));

/** Pays `amount` for `contract` from `fund`, at once or, with a due date, as a scheduled transfer. */
const payFor = (fund, contract, amount, { symbol = [], due_at = [] } = {}) =>
  as(alice).ggg_transfer_create({
    fund,
    to: { kind: 'Organization', id: 'buildco' },
    amount,
    symbol,
    category: [],
    description: [],
    contract: [contract],
    on_behalf_of: [],
    due_at,
    committed: [],
  });
const transfersOf = async (fund) => ok(await as(alice).ggg_transfer_list({ cursor: [], limit: [], fund: [fund], status: [] })).items;

test('payments on a contract never exceed its value; a scheduled one is owed and counts, a cancelled one does not', async () => {
  const { id } = ok(await create({ value: 1_000n, split: [[]] }));
  await makeFund('WORKS');
  ok(await payFor('WORKS', id, 600n));
  const due = (await now()) + 30n * DAY;
  const owed = ok(await payFor('WORKS', id, 300n, { due_at: [due] })).Done[0];
  refusedWith(await payFor('WORKS', id, 200n), 'Conflict', new RegExp(`contract ${id} has 100 left of its value; the transfer of 200 is 100 over`));

  ok(await as(alice).ggg_transfer_revert({ transfer: owed, reason: [] }));
  ok(await payFor('WORKS', id, 400n));
  refusedWith(await payFor('WORKS', id, 1n), 'Conflict');
  assert.deepEqual((await transfersOf('WORKS')).map((t) => t.contract), [[id], [id], [id]]);
});

test('a transfer for a contract names one that exists and is in its symbol', async () => {
  const { id } = ok(await create({ value: 1_000n, split: [[]], symbol: 'USDC' }));
  await makeFund('SCHOOLS');
  refusedWith(await payFor('SCHOOLS', 'no-such-contract', 1n), 'NotFound');
  refusedWith(await payFor('SCHOOLS', id, 1n), 'InvalidArgument');
  ok(await payFor('SCHOOLS', id, 1n, { symbol: ['USDC'] }));
});

test("an amendment never sets a contract's value below what has been paid on it, not one a proposal carries later either", async () => {
  const { id } = ok(await create({ value: 1_000n, split: [[]] }));
  await makeFund('PARKS');
  ok(await payFor('PARKS', id, 800n));
  ok(await payFor('PARKS', id, 100n, { due_at: [(await now()) + 30n * DAY] }));
  refusedWith(await amend(id, { value: [850n] }), 'Conflict', /below the 900 paid on the contract/);
  ok(await amend(id, { value: [900n] }));
  ok(await amend(id, { value: [1_000n] }));

  const proposal = await proposeAmendment(id, { value: [950n] });
  ok(await payFor('PARKS', id, 100n));
  assert.equal(await carry(proposal), 'Failed');
  const { contract, amendments } = await detail(id);
  assert.equal(contract.value, 1_000n);
  assert.equal(amendments.length, 2);
});

/** ContractAmendArgs, as the fixture decodes a proposal's call. */
function contractAmendType() {
  const [, fn] = idlFactory({ IDL })._fields.find(([name]) => name === 'ggg_contract_amend');
  return fn.argTypes;
}
