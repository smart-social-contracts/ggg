// Links between realms (I-NEST-1 to 3) and the published record (model §11), on PocketIC with fixture
// canisters that take legislation from one another: b, a source; a, which takes it from b (and later
// from d too); c, which takes it from a; and pairs of realms for the cycle and lost-notice cases. The
// root of each decides alone, so a vote to add a source or accept a follower applies at once, and the
// canisters call each other's ggg_link_notify. A follower's own calls to a source (ggg_follower_report)
// are made here with the follower canister's principal as the sender, which PocketIC allows; two calls
// at once go through submitCall and awaitCall; an unreachable realm is a stopped canister.
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

// The chapters each realm holds, by checksum.
const CHAPTER_B = `sha256:${'b'.repeat(64)}`;
const CHAPTER_A = `sha256:${'a'.repeat(64)}`;
const CHAPTER_C = `sha256:${'c'.repeat(64)}`;
const CHAPTER_D = `sha256:${'d'.repeat(64)}`;
const UNKNOWN = `sha256:${'f'.repeat(64)}`;
const MINUTE_MS = 60 * 1000;

let server;
let pic;
let wasm;
let a;
let b;
let c;
let d;

const service = idlFactory({ IDL });
const argTypes = (method) => service._fields.find(([name]) => name === method)[1].argTypes;
const retTypes = (method) => service._fields.find(([name]) => name === method)[1].retTypes;

async function install(chapters = []) {
  const canisterId = await pic.createCanister();
  const members = [alice.getPrincipal(), bob.getPrincipal()];
  const arg = IDL.encode([IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))], [members, chapters]);
  await pic.installCode({ canisterId, wasm, arg });
  return canisterId;
}

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  b = await install([[CHAPTER_B, [1, 2, 3]]]);
  a = await install([[CHAPTER_A, [4, 5, 6]]]);
  c = await install([[CHAPTER_C, [7]]]);
  d = await install([[CHAPTER_D, [8]]]);
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

/** The realm `canisterId`, called by a member, or by another canister when `sender` is a principal. */
const on = (canisterId, sender = alice) => pic.createActor({ idlFactory, canisterId, sender: sender.getPrincipal?.() ?? sender });
const none = { cursor: [], limit: [] };
/** Moves the clock forward and lets timers fire. */
const wait = async (minutes) => {
  await pic.setTime((await pic.getTime()) + minutes * MINUTE_MS);
  for (let round = 0; round < 5; round++) await pic.tick();
};
/** Two update calls submitted at once, then both replies. */
async function together(calls) {
  const submitted = [];
  for (const { canisterId, method, args, sender } of calls) {
    const arg = new Uint8Array(IDL.encode(argTypes(method), args));
    submitted.push([method, await pic.submitCall({ canisterId, method, arg, sender: sender.getPrincipal() })]);
  }
  const replies = [];
  for (const [method, call] of submitted) replies.push(IDL.decode(retTypes(method), await pic.awaitCall(call))[0]);
  return replies;
}

const realm = (p) => ({ Realm: p });
const sources = async (canisterId) => (await on(canisterId).ggg_realm_info()).sync_sources;
const source = async (canisterId, p) => (await sources(canisterId)).find((s) => 'Realm' in s.source && s.source.Realm.toText() === p.toText());
const followers = async (canisterId) => ok(await on(canisterId).ggg_follower_list(none)).items;
const follower = async (canisterId, p) => (await followers(canisterId)).find((f) => f.capital.toText() === p.toText());
const releases = async (canisterId) => ok(await on(canisterId).ggg_legislation_releases(none)).items;
const layers = (items) => items.map((r) => `${r.source} ${r.version}`);

const add = (canisterId, ref, name = 'A source') => on(canisterId, bob).ggg_sync_source_add({ source: ref, name });
const remove = (canisterId, ref) => on(canisterId, bob).ggg_sync_source_remove({ source: ref });
const accept = (canisterId, p) => on(canisterId, bob).ggg_follower_accept({ follower: p });
/** Both votes, the follower's first. */
const link = async (follower, sourceId) => {
  ok(await add(follower, realm(sourceId)));
  ok(await accept(sourceId, follower));
};

const publication = (source, version, checksum) => ({
  source,
  version,
  effective_from: 1_800_000_000_000_000_000n,
  commit: 'c'.repeat(40),
  chapters: [{ domain: 'tax', checksum }],
  calendar: [],
  notes: { Map: [] },
});
const publish = (canisterId, args) => on(canisterId, bob).ggg_legislation_release_publish(args);
const release = (source, version) => ({ Release: { source, version } });
const installRelease = (canisterId, source, version) => on(canisterId, bob).ggg_codex_install(release(source, version));

test('a link is active only after both votes, in either order', async () => {
  // The follower votes first: its side is requested, and the source, which has not voted, has no entry.
  assert.deepEqual(ok(await add(a, realm(b), 'The source')), { Done: [] });
  assert.equal(tag((await source(a, b)).status), 'Requested');
  assert.equal(await follower(b, a), undefined);
  // The source's vote completes the link on both sides: its notice is answered Active.
  assert.deepEqual(ok(await accept(b, a)), { Done: [] });
  assert.equal(tag((await follower(b, a)).status), 'Active');
  assert.equal(tag((await source(a, b)).status), 'Active');

  // The source votes first.
  ok(await accept(a, c));
  assert.equal(tag((await follower(a, c)).status), 'Requested');
  assert.equal(await source(c, a), undefined);
  ok(await add(c, realm(a)));
  assert.equal(tag((await source(c, a)).status), 'Active');
  assert.equal(tag((await follower(a, c)).status), 'Active');

  // A second vote for a link that stands is a Conflict.
  refusedWith(await add(a, realm(b)), 'Conflict');
  refusedWith(await accept(b, a), 'Conflict');
  refusedWith(await add(a, realm(b), ''), 'InvalidArgument');
  refusedWith(await on(a, stranger).ggg_sync_source_add({ source: realm(b), name: 'x' }), 'Forbidden');
});

test('a stand-in record is active on the follower\'s vote alone, its url is https, and a second add re-pins it', async () => {
  const url = 'https://example.org/releases.json';
  const record = (checksum) => ({ Record: { url, checksum } });
  refusedWith(await add(a, { Record: { url: 'http://example.org/releases.json', checksum: `sha256:${'1'.repeat(64)}` } }), 'InvalidArgument');
  refusedWith(await add(a, { Record: { url: b.toText(), checksum: `sha256:${'1'.repeat(64)}` } }), 'InvalidArgument');
  ok(await add(a, record(`sha256:${'1'.repeat(64)}`), 'A stand-in'));
  const pinned = (await sources(a)).filter((s) => 'Record' in s.source);
  assert.equal(pinned.length, 1);
  assert.equal(tag(pinned[0].status), 'Active');
  // The realm link stands beside it.
  assert.equal(tag((await source(a, b)).status), 'Active');

  ok(await add(a, record(`sha256:${'2'.repeat(64)}`), 'A stand-in'));
  const repinned = (await sources(a)).filter((s) => 'Record' in s.source);
  assert.equal(repinned.length, 1);
  assert.equal(repinned[0].source.Record.checksum, `sha256:${'2'.repeat(64)}`);
  assert.equal(tag(repinned[0].status), 'Active');

  // Removed by its url, whatever checksum is named.
  assert.deepEqual(ok(await remove(a, record(`sha256:${'9'.repeat(64)}`))), { Done: [] });
  assert.equal(tag((await sources(a)).find((s) => 'Record' in s.source).status), 'Ended');
});

test('a cycle is refused on either vote, directly or through other realms, and an unreadable realm fails the check', async () => {
  refusedWith(await add(b, realm(b)), 'Conflict');
  // a takes legislation from b, so b cannot take it from a; c takes it from a, so b cannot take it from c.
  refusedWith(await add(b, realm(a)), 'Conflict');
  refusedWith(await add(b, realm(c)), 'Conflict');
  assert.deepEqual(await sources(b), []);
  // Nor can a accept b as a follower: a takes legislation from b.
  refusedWith(await accept(a, b), 'Conflict');
  assert.equal(await follower(a, b), undefined);

  // Two adds at once, x from y and y from x: each records its link before it reads the other's, so at
  // most one link can become active once both accept.
  const x = await install();
  const y = await install();
  const adds = await together([
    { canisterId: x, method: 'ggg_sync_source_add', args: [{ source: realm(y), name: 'y' }], sender: bob },
    { canisterId: y, method: 'ggg_sync_source_add', args: [{ source: realm(x), name: 'x' }], sender: bob },
  ]);
  assert.ok(adds.some((r) => 'Err' in r && tag(r.Err) === 'Conflict'), 'one add sees the other as a cycle');
  await accept(y, x);
  await accept(x, y);
  const active = [await source(x, y), await source(y, x)].filter((s) => s && tag(s.status) === 'Active');
  assert.ok(active.length <= 1, 'at most one link is active');

  // q takes legislation from p. While q cannot be read, p's add of q is Unavailable, never an open link.
  const p = await install();
  const q = await install();
  await link(q, p);
  refusedWith(await add(p, realm(q)), 'Conflict');
  await pic.stopCanister({ canisterId: q });
  refusedWith(await add(p, realm(q)), 'Unavailable');
  await pic.startCanister({ canisterId: q });
  assert.equal(await source(p, q), undefined);
  refusedWith(await accept(q, p), 'Conflict');
});

test('link_notify is accepted only from the other side\'s capital, and a forged end is refused', async () => {
  const notice = { side: { Follower: null }, status: { Requested: null } };
  refusedWith(await on(b, stranger).ggg_link_notify(notice), 'Forbidden');
  refusedWith(await on(b, alice).ggg_link_notify(notice), 'Forbidden');
  // c has no link with b.
  refusedWith(await on(b, c).ggg_link_notify(notice), 'Forbidden');
  refusedWith(await on(b, c).ggg_link_notify({ side: { SyncSource: null }, status: { Active: null } }), 'Forbidden');
  // The follower a cannot end the link in the source's name, nor from the future.
  const future = BigInt(await pic.getTime()) * 1_000_000n + 10n * 60n * 1_000_000_000n;
  refusedWith(await on(b, a).ggg_link_notify({ side: { Follower: null }, status: { Ended: { by: b, at: 1n } } }), 'InvalidArgument');
  refusedWith(await on(b, a).ggg_link_notify({ side: { Follower: null }, status: { Ended: { by: a, at: future } } }), 'InvalidArgument');
  assert.equal(tag((await follower(b, a)).status), 'Active');
});

test('publishing refuses an unknown checksum, a second version once, and another source id', async () => {
  refusedWith(await publish(b, publication('b', '1.0.0', UNKNOWN)), 'InvalidArgument');
  assert.deepEqual(await releases(b), []);
  assert.deepEqual(ok(await publish(b, publication('b', '1.0.0', CHAPTER_B))), { Done: [] });
  refusedWith(await publish(b, publication('b', '1.0.0', CHAPTER_B)), 'Conflict');
  refusedWith(await publish(b, publication('other', '1.1.0', CHAPTER_B)), 'InvalidArgument');
  const [published] = await releases(b);
  assert.equal(published.source, 'b');
  assert.equal(published.version, '1.0.0');
  assert.deepEqual(published.chapters, [{ domain: 'tax', checksum: CHAPTER_B }]);
  assert.ok(published.published > 0n);
  assert.deepEqual(ok(await on(b).ggg_legislation_chapter(CHAPTER_B)), [new Uint8Array([1, 2, 3])]);
  assert.deepEqual(ok(await on(b).ggg_legislation_chapter(UNKNOWN)), []);
});

test('a follower\'s report is its own claim, over an active link', async () => {
  const report = { layers: [{ version: '1.0.0', checksum: CHAPTER_B }], compliance: { Compliant: null }, population: 800_000n };
  const reported = ok(await on(b, a).ggg_follower_report(report));
  assert.equal(reported.population, 800_000n);
  assert.equal(reported.reported_at.length, 1);
  const entry = await follower(b, a);
  assert.deepEqual(entry.layers, report.layers);
  assert.equal(tag(entry.compliance), 'Compliant');
  assert.equal(entry.population, 800_000n);
  // A layer the source's record does not list is the follower's claim too, kept as reported; it matches nothing.
  const unlisted = ok(await on(b, a).ggg_follower_report({ ...report, layers: [{ version: '9.9.9', checksum: UNKNOWN }] }));
  assert.deepEqual(unlisted.layers, [{ version: '9.9.9', checksum: UNKNOWN }]);
  ok(await on(b, a).ggg_follower_report(report));
  // Only a follower's capital reports, and only over an active link: b accepts c, which never added b.
  refusedWith(await on(b, c).ggg_follower_report(report), 'Forbidden');
  refusedWith(await on(b, alice).ggg_follower_report(report), 'Forbidden');
  ok(await accept(b, c));
  assert.equal(tag((await follower(b, c)).status), 'Requested');
  refusedWith(await on(b, c).ggg_follower_report(report), 'Conflict');
});

test('the record lists the relayed layers top to bottom, in the vouching record\'s order, then the realm\'s own', async () => {
  // a installs b's release from b's record, then publishes its own.
  assert.deepEqual(ok(await installRelease(a, 'b', '1.0.0')), { Done: [] });
  assert.deepEqual(layers(await releases(a)), ['b 1.0.0']);
  refusedWith(await installRelease(a, 'b', '9.9.9'), 'NotFound');
  refusedWith(await on(a, bob).ggg_codex_install({ Registry: { codex: 'agora', version: '1.0.0' } }), 'InvalidArgument');
  ok(await publish(a, publication('a', '1.0.0', CHAPTER_A)));
  assert.deepEqual(layers(await releases(a)), ['b 1.0.0', 'a 1.0.0']);

  // c takes legislation from a alone, and installs the lower layer first: the record still runs top to bottom.
  ok(await installRelease(c, 'a', '1.0.0'));
  ok(await installRelease(c, 'b', '1.0.0'));
  assert.deepEqual(layers(await releases(c)), ['b 1.0.0', 'a 1.0.0']);
  assert.equal((await releases(c))[1].chapters[0].checksum, CHAPTER_A);
  // c publishes under its own id, never under a layer it relays.
  refusedWith(await publish(c, publication('a', '2.0.0', CHAPTER_C)), 'InvalidArgument');
  ok(await publish(c, publication('c', '1.0.0', CHAPTER_C)));
  assert.deepEqual(layers(await releases(c)), ['b 1.0.0', 'a 1.0.0', 'c 1.0.0']);
});

test('a release that two active sources list differently is refused', async () => {
  // d publishes its own "b 1.0.0" with other bytes, and a takes legislation from d as well.
  ok(await publish(d, publication('b', '1.0.0', CHAPTER_D)));
  await link(a, d);
  refusedWith(await installRelease(a, 'b', '1.0.0'), 'Conflict');
  assert.equal((await releases(a))[0].chapters[0].checksum, CHAPTER_B);
});

test('an install from a release is also a proposal\'s Call action, and runs once under two executes at once', async () => {
  ok(await publish(a, publication('a', '1.1.0', CHAPTER_A)));
  const arg = new Uint8Array(IDL.encode(argTypes('ggg_codex_install'), [release('a', '1.1.0')]));
  const id = ok(await on(c).ggg_proposal_create({
    title: 'Install a 1.1.0',
    description: '',
    department: [],
    action: { Call: { method: 'ggg_codex_install', arg } },
    kind: [],
    matter: [],
    threshold: [],
    quorum: [],
    threshold_of: [],
    effective_at: [],
    links: [],
    on_behalf_of: [],
  }));
  for (const voter of [alice, bob]) ok(await on(c, voter).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
  assert.equal(tag(ok(await on(c, bob).ggg_proposal_finalize(id)).status), 'Accepted');
  const replies = await together([
    { canisterId: c, method: 'ggg_proposal_execute', args: [id], sender: bob },
    { canisterId: c, method: 'ggg_proposal_execute', args: [id], sender: alice },
  ]);
  const ran = replies.filter((r) => 'Ok' in r);
  assert.equal(ran.length, 1, 'one execute runs the action');
  assert.equal(tag(ran[0].Ok.status), 'Executed');
  assert.deepEqual(ran[0].Ok.result.map(tag), ['Reply']);
  refusedWith(replies.find((r) => 'Err' in r), 'Conflict');
  assert.deepEqual(layers(await releases(c)), ['b 1.0.0', 'a 1.1.0', 'c 1.0.0']);
});

test('a stop while the action runs is a Conflict, and the action runs once', async () => {
  // Both calls arrive in one round, in either order, which PocketIC picks: five races make both orders
  // likely. If the execute runs first, it reads a's record while the stop arrives, and the stop is
  // refused; if the stop runs first, the execute finds nothing scheduled. Either way exactly one wins,
  // and the action never runs after a stop.
  let installed = 'a 1.1.0';
  for (let race = 0; race < 5; race++) {
    const version = `1.2.${race}`;
    ok(await publish(a, publication('a', version, CHAPTER_A)));
    const arg = new Uint8Array(IDL.encode(argTypes('ggg_codex_install'), [release('a', version)]));
    const at = BigInt(await pic.getTime()) * 1_000_000n + 60n * 1_000_000_000n;
    const id = ok(await on(c).ggg_proposal_create({
      title: `Install a ${version}`,
      description: '',
      department: [],
      action: { Call: { method: 'ggg_codex_install', arg } },
      kind: [],
      matter: [],
      threshold: [],
      quorum: [],
      threshold_of: [],
      effective_at: [at],
      links: [],
      on_behalf_of: [],
    }));
    for (const voter of [alice, bob]) {
      ok(await on(c, voter).ggg_proposal_vote({ proposal: id, choice: { Yes: null }, on_behalf_of: [] }));
    }
    assert.equal(tag(ok(await on(c, bob).ggg_proposal_finalize(id)).status), 'ExecutionScheduled');
    await wait(2);
    const [executed, stopped] = await together([
      { canisterId: c, method: 'ggg_proposal_execute', args: [id], sender: bob },
      { canisterId: c, method: 'ggg_proposal_stop', args: [id], sender: alice },
    ]);
    const status = tag(ok(await on(c).ggg_proposal_get({ id, ...none }))[0].proposal.status);
    if ('Ok' in executed) {
      assert.equal(tag(executed.Ok.status), 'Executed');
      refusedWith(stopped, 'Conflict');
      assert.equal(status, 'Executed');
      installed = `a ${version}`;
    } else {
      refusedWith(executed, 'Conflict');
      assert.deepEqual(ok(stopped), { Done: [] });
      assert.equal(status, 'Withdrawn');
    }
    assert.deepEqual(layers(await releases(c)), ['b 1.0.0', installed, 'c 1.0.0']);
  }
});

test('a notice that is not answered is sent again until it is', async () => {
  const s = await install();
  const f = await install();
  // The follower votes first; its notice is refused, as the source has not voted. Then the source
  // votes while the follower cannot be heard (a source's walk reads only its own sources, so the vote
  // passes): its notice waits, and is sent again once the follower is back.
  ok(await add(f, realm(s)));
  await pic.stopCanister({ canisterId: f });
  ok(await accept(s, f));
  assert.equal(tag((await follower(s, f)).status), 'Requested');
  await pic.startCanister({ canisterId: f });
  assert.equal(tag((await source(f, s)).status), 'Requested');
  await wait(2);
  assert.equal(tag((await follower(s, f)).status), 'Active');
  assert.equal(tag((await source(f, s)).status), 'Active');

  // The follower leaves while the source cannot be heard: the source learns of it when it is back.
  await pic.stopCanister({ canisterId: s });
  ok(await remove(f, realm(s)));
  assert.equal(tag((await source(f, s)).status), 'Ended');
  await pic.startCanister({ canisterId: s });
  assert.equal(tag((await follower(s, f)).status), 'Active');
  await wait(2);
  assert.equal(tag((await follower(s, f)).status), 'Ended');
});

test('a follower leaves, and the source\'s link_notify event carries Ended', async () => {
  const installed = layers(await releases(c));
  assert.deepEqual(ok(await remove(c, realm(a))), { Done: [] });
  const ended = (await source(c, a)).status;
  assert.equal(tag(ended), 'Ended');
  assert.equal(ended.Ended.by.toText(), c.toText());
  const onSource = (await follower(a, c)).status;
  assert.equal(tag(onSource), 'Ended');
  assert.equal(onSource.Ended.by.toText(), c.toText());

  const events = ok(await on(a).ggg_events({ cursor: [], limit: [100] })).items;
  const notices = events.filter((e) => e.op === 'link_notify' && e.user[0]?.toText() === c.toText());
  assert.ok(notices.length > 0, 'the source audited the notice');
  const status = notices[0].args.Map.find(([key]) => key === 'status')[1];
  assert.equal(status.Map[0][0], 'Ended');

  // The link is no longer active: no report, no second removal, and the follower keeps its layers.
  refusedWith(await on(a, c).ggg_follower_report({ layers: [], compliance: { Unknown: null }, population: 0n }), 'Conflict');
  refusedWith(await remove(c, realm(a)), 'Conflict');
  refusedWith(await on(a, bob).ggg_follower_remove({ follower: c }), 'Conflict');
  assert.deepEqual(layers(await releases(c)), installed);
});
