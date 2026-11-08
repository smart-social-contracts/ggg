// Links between realms (I-NEST-1 to 3) and the published record (model §11), on PocketIC with three
// fixture canisters: b, a source; a, which takes legislation from b; and c, which takes it from a. The
// root of each decides alone, so a vote to add a source or accept a follower applies at once, and the
// canisters call each other's ggg_link_notify. A follower's own calls to a source (ggg_follower_report)
// are made here with the follower canister's principal as the sender, which PocketIC allows.
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
const UNKNOWN = `sha256:${'f'.repeat(64)}`;

let server;
let pic;
let a;
let b;
let c;

before(async () => {
  server = await PocketIcServer.start();
  pic = await PocketIc.create(server.getUrl());
  const wasm = readFileSync(new URL('../fixture/ggg_fixture.wasm', import.meta.url));
  const install = async (chapters) => {
    const canisterId = await pic.createCanister();
    const members = [alice.getPrincipal(), bob.getPrincipal()];
    const arg = IDL.encode([IDL.Vec(IDL.Principal), IDL.Vec(IDL.Tuple(IDL.Text, IDL.Vec(IDL.Nat8)))], [members, chapters]);
    await pic.installCode({ canisterId, wasm, arg });
    return canisterId;
  };
  b = await install([[CHAPTER_B, [1, 2, 3]]]);
  a = await install([[CHAPTER_A, [4, 5, 6]]]);
  c = await install([]);
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

const realm = (p) => ({ Realm: p });
const sources = async (canisterId) => (await on(canisterId).ggg_realm_info()).sync_sources;
const source = async (canisterId, p) => (await sources(canisterId)).find((s) => 'Realm' in s.source && s.source.Realm.toText() === p.toText());
const followers = async (canisterId) => ok(await on(canisterId).ggg_follower_list(none)).items;
const follower = async (canisterId, p) => (await followers(canisterId)).find((f) => f.capital.toText() === p.toText());
const releases = async (canisterId) => ok(await on(canisterId).ggg_legislation_releases(none)).items;
const layers = (items) => items.map((r) => `${r.source} ${r.version}`);

const add = (canisterId, ref, name = 'A source') => on(canisterId, bob).ggg_sync_source_add({ source: ref, name });
const accept = (canisterId, p) => on(canisterId, bob).ggg_follower_accept({ follower: p });

const publication = (source, version, checksum) => ({
  source,
  version,
  effective_from: 1_800_000_000_000_000_000n,
  commit: 'c'.repeat(40),
  chapters: [{ domain: 'tax', checksum }],
  calendar: [],
  notes: { Map: [] },
});
const release = (source, version) => ({ Release: { source, version } });

test('a link is active only after both votes, in either order', async () => {
  // The follower votes first: its side is requested, and the source, which has not voted, has no entry.
  assert.deepEqual(ok(await add(a, realm(b), 'The source')), { Done: [] });
  assert.deepEqual(tag((await source(a, b)).status), 'Requested');
  assert.equal(await follower(b, a), undefined);
  // The source's vote completes the link on both sides.
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

test('a stand-in record is active on the follower\'s vote alone, and a second add of its URL pins a new checksum', async () => {
  const url = 'https://example.org/releases.json';
  const record = (checksum) => ({ Record: { url, checksum } });
  ok(await add(a, record(`sha256:${'1'.repeat(64)}`), 'A stand-in'));
  const pinned = (await sources(a)).filter((s) => 'Record' in s.source);
  assert.equal(pinned.length, 1);
  assert.equal(tag(pinned[0].status), 'Active');

  ok(await add(a, record(`sha256:${'2'.repeat(64)}`), 'A stand-in'));
  const repinned = (await sources(a)).filter((s) => 'Record' in s.source);
  assert.equal(repinned.length, 1);
  assert.equal(repinned[0].source.Record.checksum, `sha256:${'2'.repeat(64)}`);
  assert.equal(tag(repinned[0].status), 'Active');
});

test('a cycle is refused, directly or through other realms', async () => {
  refusedWith(await add(b, realm(b)), 'Conflict');
  // a takes legislation from b, so b cannot take it from a; c takes it from a, so b cannot take it from c.
  refusedWith(await add(b, realm(a)), 'Conflict');
  refusedWith(await add(b, realm(c)), 'Conflict');
  assert.deepEqual(await sources(b), []);
});

test('link_notify from a principal that is not the other side\'s capital is refused', async () => {
  const notice = { side: { Follower: null }, status: { Requested: null } };
  refusedWith(await on(b, stranger).ggg_link_notify(notice), 'Forbidden');
  refusedWith(await on(b, alice).ggg_link_notify(notice), 'Forbidden');
  // c has no link with b.
  refusedWith(await on(b, c).ggg_link_notify(notice), 'Forbidden');
  refusedWith(await on(b, c).ggg_link_notify({ side: { SyncSource: null }, status: { Active: null } }), 'Forbidden');
  assert.equal(tag((await follower(b, a)).status), 'Active');
});

test('a follower\'s report updates its entry on the source', async () => {
  const report = { layers: [{ version: '1.0.0', checksum: CHAPTER_B }], compliance: { Compliant: null }, population: 800_000n };
  const reported = ok(await on(b, a).ggg_follower_report(report));
  assert.equal(reported.population, 800_000n);
  assert.equal(reported.reported_at.length, 1);
  const entry = await follower(b, a);
  assert.deepEqual(entry.layers, report.layers);
  assert.equal(tag(entry.compliance), 'Compliant');
  assert.equal(entry.population, 800_000n);
  // Only a follower's capital reports.
  refusedWith(await on(b, c).ggg_follower_report(report), 'Forbidden');
  refusedWith(await on(b, alice).ggg_follower_report(report), 'Forbidden');
});

test('publishing refuses an unknown checksum, a second version once, and another source id', async () => {
  refusedWith(await on(b, bob).ggg_legislation_release_publish(publication('b', '1.0.0', UNKNOWN)), 'InvalidArgument');
  assert.deepEqual(await releases(b), []);
  assert.deepEqual(ok(await on(b, bob).ggg_legislation_release_publish(publication('b', '1.0.0', CHAPTER_B))), { Done: [] });
  refusedWith(await on(b, bob).ggg_legislation_release_publish(publication('b', '1.0.0', CHAPTER_B)), 'Conflict');
  refusedWith(await on(b, bob).ggg_legislation_release_publish(publication('other', '1.1.0', CHAPTER_B)), 'InvalidArgument');
  const [published] = await releases(b);
  assert.equal(published.source, 'b');
  assert.equal(published.version, '1.0.0');
  assert.deepEqual(published.chapters, [{ domain: 'tax', checksum: CHAPTER_B }]);
  assert.ok(published.published > 0n);
  assert.deepEqual(ok(await on(b).ggg_legislation_chapter(CHAPTER_B)), [new Uint8Array([1, 2, 3])]);
  assert.deepEqual(ok(await on(b).ggg_legislation_chapter(UNKNOWN)), []);
});

test('the record lists the relayed layers top to bottom, each with its source, then the realm\'s own', async () => {
  // a installs b's release from b's record, then publishes its own.
  assert.deepEqual(ok(await on(a, bob).ggg_codex_install(release('b', '1.0.0'))), { Done: [] });
  assert.deepEqual(layers(await releases(a)), ['b 1.0.0']);
  refusedWith(await on(a, bob).ggg_codex_install(release('b', '9.9.9')), 'NotFound');
  refusedWith(await on(a, bob).ggg_codex_install({ Registry: { codex: 'agora', version: '1.0.0' } }), 'InvalidArgument');
  ok(await on(a, bob).ggg_legislation_release_publish(publication('a', '1.0.0', CHAPTER_A)));
  assert.deepEqual(layers(await releases(a)), ['b 1.0.0', 'a 1.0.0']);

  // c takes legislation from a alone, and installs both layers as a's record vouches for them.
  ok(await on(c, bob).ggg_codex_install(release('b', '1.0.0')));
  ok(await on(c, bob).ggg_codex_install(release('a', '1.0.0')));
  assert.deepEqual(layers(await releases(c)), ['b 1.0.0', 'a 1.0.0']);
  assert.equal((await releases(c))[1].chapters[0].checksum, CHAPTER_A);
});

test('an install from a release is also a proposal\'s Call action', async () => {
  const arg = new Uint8Array(IDL.encode([idlFactory({ IDL })._fields.find(([name]) => name === 'ggg_codex_install')[1].argTypes[0]], [release('b', '1.0.0')]));
  const id = ok(await on(c).ggg_proposal_create({
    title: 'Install b 1.0.0',
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
  const finalized = await on(c, bob).ggg_proposal_finalize(id);
  const status = 'Ok' in finalized ? tag(finalized.Ok.status) : tag(ok(await on(c).ggg_proposal_get({ id, ...none }))[0].proposal.status);
  const executed = status === 'Accepted' ? ok(await on(c, bob).ggg_proposal_execute(id)) : ok(await on(c).ggg_proposal_get({ id, ...none }))[0].proposal;
  assert.equal(tag(executed.status), 'Executed');
  assert.deepEqual(executed.result.map(tag), ['Reply']);
  assert.deepEqual(layers(await releases(c)), ['b 1.0.0', 'a 1.0.0']);
});

test('a follower leaves, and the source\'s link_notify event carries Ended', async () => {
  assert.deepEqual(ok(await on(c, bob).ggg_sync_source_remove({ source: realm(a) })), { Done: [] });
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
  refusedWith(await on(c, bob).ggg_sync_source_remove({ source: realm(a) }), 'Conflict');
  refusedWith(await on(a, bob).ggg_follower_remove({ follower: c }), 'Conflict');
  assert.deepEqual(layers(await releases(c)), ['b 1.0.0', 'a 1.0.0']);
});
