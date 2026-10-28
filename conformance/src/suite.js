import { Actor, AnonymousIdentity, HttpAgent } from '@icp-sdk/core/agent';
import { IDL } from '@icp-sdk/core/candid';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { Principal } from '@icp-sdk/core/principal';
import { idlFactory } from '../idl/ggg.js';

const PAGE = 2;
const MAX_PAGES = 50;
const BAD_CURSOR = 'ggg-conformance:not-a-cursor';
const NO_PROPOSAL = 'ggg-conformance-no-such-proposal';
const NO_DEPARTMENT = 'ggg-conformance-no-such-department';
const NO_METHOD = 'ggg_conformance_no_such_method';
const UNKNOWN = 'ggg-conformance-no-such-record';

export class Skip extends Error {}

const tag = (variant) => Object.keys(variant)[0];
const opt = (o) => (o.length ? o[0] : null);
const show = (v) =>
  JSON.stringify(v, (_, x) => {
    if (typeof x === 'bigint') return x.toString();
    if (x instanceof Principal) return x.toText();
    if (x instanceof Uint8Array) return `blob(${x.length})`;
    return x;
  });

function ok(result, what) {
  if ('Ok' in result) return result.Ok;
  throw new Error(`${what} returned Err ${show(result.Err)}`);
}

function err(result, tags, what) {
  if ('Ok' in result) throw new Error(`${what} returned Ok ${show(result.Ok)}, expected Err ${tags.join(' or ')}`);
  if (!tags.includes(tag(result.Err))) {
    throw new Error(`${what} returned Err ${show(result.Err)}, expected ${tags.join(' or ')}`);
  }
  return result.Err;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

/** Skips when a read is refused for lack of the model permission, which the standards allow. */
function refused(error, what) {
  if (error && ['Forbidden', 'Unauthenticated'].includes(tag(error))) {
    throw new Skip(`${what} is refused to this caller (${tag(error)})`);
  }
}

/** Reads every page of a list, checking the pagination rules. */
async function walk(call, key) {
  const seen = new Set();
  const items = [];
  let cursor = [];
  for (let i = 0; i < MAX_PAGES; i++) {
    const result = await call({ cursor, limit: [PAGE] });
    if ('Err' in result) return { err: result.Err, items };
    const { items: pageItems, next } = result.Ok;
    assert(pageItems.length <= PAGE, `a page has ${pageItems.length} items with limit ${PAGE}`);
    assert(!(next.length && pageItems.length === 0), 'a page with a next cursor is empty');
    for (const item of pageItems) {
      const k = key(item);
      assert(!seen.has(k), `${k} appears twice while paging`);
      seen.add(k);
      items.push(item);
    }
    if (!next.length) return { items, complete: true };
    cursor = next;
  }
  return { items, complete: false };
}

function checkWalk(walked, what) {
  refused(walked.err, what);
  if (walked.err) throw new Error(`${what} returned Err ${show(walked.err)}`);
  return walked.complete
    ? `${walked.items.length} listed`
    : `first ${walked.items.length} listed (stopped after ${MAX_PAGES} pages)`;
}

function checkUrl(value, where) {
  const url = opt(value);
  assert(url === null || /^https:\/\/\S+$/.test(url), `${where} is not an https URL: "${url}"`);
}

function checkUser({ user, member }) {
  const where = `user ${user.id.toText()}`;
  assert(!user.id.isAnonymous(), `${where}: the anonymous principal is listed`);
  assert(user.profiles.every((p) => p.length > 0), `${where}: a profile name is empty`);
  const m = opt(member);
  assert(m === null || m.user.toText() === user.id.toText(), `${where}: the membership is for ${m?.user.toText()}`);
}

function checkProposal(p) {
  assert(p.id.length > 0, 'a proposal has an empty id');
  assert(p.title.length > 0, `proposal ${p.id}: the title is empty`);
  if (tag(p.action) === 'Code') {
    const { checksum } = p.action.Code;
    assert(/^sha256:[0-9a-f]{64}$/.test(checksum), `proposal ${p.id}: checksum "${checksum}" is not sha256:<hex>`);
  }
  if (tag(p.action) === 'Call') {
    assert(p.action.Call.method.length > 0, `proposal ${p.id}: the method name is empty`);
  }
  for (const field of ['threshold', 'quorum']) {
    assert(p[field] <= 10_000n, `proposal ${p.id}: ${field} is ${p[field]}, above 10000`);
  }
  const opens = opt(p.opens_at);
  const deadline = opt(p.deadline);
  assert(opens === null || deadline === null || opens <= deadline, `proposal ${p.id}: the deadline is before voting opens`);
  const { yes, no, abstain } = p.tally;
  const eligible = opt(p.tally.eligible);
  assert(eligible === null || yes + no + abstain <= eligible, `proposal ${p.id}: more votes than eligible voters`);
  const result = opt(p.result);
  if (result) {
    assert(['Executed', 'Failed'].includes(tag(p.status)), `proposal ${p.id} is ${tag(p.status)} but has a result`);
  }
}

function sameProposal(listed, p) {
  for (const field of ['title', 'proposer', 'department', 'status', 'action']) {
    assert(show(p[field]) === show(listed[field]), `proposal ${p.id}: ${field} differs between list and get`);
  }
}

const getArgs = (id, cursor = [], limit = []) => ({ id, cursor, limit });

async function getProposal(actor, id) {
  return opt(ok(await actor.ggg_proposal_get(getArgs(id)), `ggg_proposal_get(${id})`));
}

/** ggg_proposal_get's votes, as pages for walk(). */
const votePages = (actor, id) => async ({ cursor, limit }) => {
  const result = await actor.ggg_proposal_get(getArgs(id, cursor, limit));
  if ('Err' in result) return result;
  const detail = opt(result.Ok);
  if (!detail) return { Err: { NotFound: null } };
  return { Ok: { items: detail.votes, next: detail.next } };
};

const idText = (id) => (id instanceof Principal ? id.toText() : id);

function itemKey(x) {
  if (typeof x === 'string' || x instanceof Principal) return idText(x);
  if (x.id !== undefined) return idText(x.id);
  if (x.verdict) return x.verdict.id;
  if (x.position) return x.position.id;
  return show(x);
}

/** A reply that holds one page in `field`, as a page for walk(). */
const pageOf = (field) => (result) => {
  if ('Err' in result) return result;
  const reply = Array.isArray(result.Ok) ? opt(result.Ok) : result.Ok;
  if (!reply) return { Err: { NotFound: null } };
  return { Ok: { items: reply[field], next: reply.next } };
};

const none = { cursor: [], limit: [] };

/**
 * Every bound list, in the order the suite walks them. `pages()` returns the list as pages for walk(), and
 * may throw Skip when it needs a record from an earlier list that the realm doesn't have.
 */
function listTable(actor) {
  let department = null;
  let scope = null;
  const list = (what, call, field = 'items', seen) => ({
    what,
    pages: () => {
      const page = pageOf(field);
      const send = call();
      return async (a) => page(await send(a));
    },
    seen,
  });
  const needDepartment = () => {
    if (!department) throw new Skip('the realm lists no department');
    return department;
  };
  const needScope = () => {
    if (!scope) throw new Skip('the caller can open no key scope');
    return scope;
  };
  return [
    list('ggg_invite_list', () => (a) => actor.ggg_invite_list(a)),
    list('ggg_delegation_list (as grantor)', () => (a) => actor.ggg_delegation_list({ ...a, role: { Grantor: null } })),
    list('ggg_delegation_list (as delegate)', () => (a) => actor.ggg_delegation_list({ ...a, role: { Delegate: null } })),
    list('ggg_department_list', () => (a) => actor.ggg_department_list(a), 'items', (items) => {
      department = items[0]?.id ?? null;
    }),
    list('ggg_department_get (seats)', () => {
      const id = needDepartment();
      return (a) => actor.ggg_department_get({ ...a, id });
    }, 'seats'),
    list('ggg_department_chart (sub-departments)', () => (a) => actor.ggg_department_chart({ ...a, department: [] }), 'children'),
    list('ggg_organization_list', () => (a) => actor.ggg_organization_list({ ...a, status: [] })),
    list('ggg_treasury_view (funds)', () => (a) => actor.ggg_treasury_view(a), 'funds'),
    list('ggg_ledger_view', () => (a) =>
      actor.ggg_ledger_view({ ...a, transaction: [], symbol: [], kind: [], fund: [], period: [] })),
    list('ggg_report_view', () => (a) => actor.ggg_report_view({ ...a, id: [] })),
    list('ggg_land_list', () => (a) => actor.ggg_land_list({ ...a, owner: [] })),
    list('ggg_land_map (zones)', () => (a) => actor.ggg_land_map({ ...a, x: 0n, y: 0n, w: 32n, h: 32n }), 'zones'),
    list('ggg_license_list', () => (a) => actor.ggg_license_list({ ...a, holder: [], kind: [], status: [] })),
    list('ggg_dispute_list_all', () => (a) => actor.ggg_dispute_list_all({ ...a, status: [] })),
    list('ggg_resolution_query', () => (a) => actor.ggg_resolution_query({ ...a, since: [], court: [], search: [] })),
    list('ggg_tender_list', () => (a) => actor.ggg_tender_list({ ...a, status: [] })),
    list('ggg_quarter_directory', () => (a) => actor.ggg_quarter_directory(a)),
    list('ggg_codex_status (history)', () => async (a) => {
      const result = await actor.ggg_codex_status(a);
      if ('Ok' in result) {
        const checksum = opt(result.Ok.checksum);
        assert(checksum === null || /^sha256:[0-9a-f]{64}$/.test(checksum), `active codex checksum "${checksum}" is not sha256:<hex>`);
      }
      return result;
    }, 'history', (items) => {
      for (const checksum of items) {
        assert(/^sha256:[0-9a-f]{64}$/.test(checksum), `codex history checksum "${checksum}" is not sha256:<hex>`);
      }
    }),
    list('ggg_notification_list', () => (a) =>
      actor.ggg_notification_list({ ...a, recipient: [], unread: [], on_behalf_of: [] })),
    list('ggg_events', () => (a) => actor.ggg_events(a)),
    list('ggg_crypto_scopes', () => (a) => actor.ggg_crypto_scopes(a), 'items', (items) => {
      scope = items[0] ?? null;
    }),
    list('ggg_crypto_access', () => {
      const s = needScope();
      return (a) => actor.ggg_crypto_access({ ...a, scope: s });
    }),
    list('ggg_document_list', () => {
      const d = needDepartment();
      return (a) => actor.ggg_document_list({ ...a, department: d });
    }),
  ];
}

/** Every bound lookup by id. */
const getTable = (actor) => [
  ['ggg_department_get', (id) => actor.ggg_department_get({ id, ...none })],
  ['ggg_organization_get', (id) => actor.ggg_organization_get({ id, ...none })],
  ['ggg_tender_get', (id) => actor.ggg_tender_get({ id, ...none })],
  ['ggg_dispute_get', (id) => actor.ggg_dispute_get({ id, on_behalf_of: [] })],
  ['ggg_crypto_envelope', (id) => actor.ggg_crypto_envelope(id)],
  ['ggg_document_get', (id) => actor.ggg_document_get(id)],
];

/** Update methods any caller may use, so the anonymous check skips them. */
export const PUBLIC_UPDATES = new Set(['ggg_federal_vote_finalize']);

/** A value of the type that decodes, with nothing in it: empty options and lists, zeros, the first variant. */
function blank(type) {
  if (type instanceof IDL.RecClass) return blank(type.getType());
  if (type instanceof IDL.TupleClass) return type._components.map(blank);
  if (type instanceof IDL.RecordClass) return Object.fromEntries(type._fields.map(([k, t]) => [k, blank(t)]));
  if (type instanceof IDL.VariantClass) return { [type._fields[0][0]]: blank(type._fields[0][1]) };
  if (type instanceof IDL.OptClass || type instanceof IDL.VecClass) return [];
  if (type instanceof IDL.TextClass) return UNKNOWN;
  if (type instanceof IDL.NatClass || type instanceof IDL.IntClass) return 0n;
  if (type instanceof IDL.FixedNatClass || type instanceof IDL.FixedIntClass) return type._bits > 32 ? 0n : 0;
  if (type instanceof IDL.BoolClass) return false;
  if (type instanceof IDL.PrincipalClass) return Principal.anonymous();
  if (type instanceof IDL.FloatClass) return 0;
  return null;
}

/** Every update method of ggg.did, with blank arguments. */
export function updateTable() {
  return idlFactory({ IDL })
    ._fields.filter(([name, fn]) => name.startsWith('ggg_') && !fn.annotations.includes('query'))
    .map(([name, fn]) => [name, fn.argTypes.map(blank)]);
}

/**
 * Runs the conformance checks against one canister.
 *
 * Without `writes`, only queries run, plus update calls that a compliant canister refuses without changing
 * anything. With `writes` and a `member` identity, the suite files a Motion proposal and votes on it.
 * Reads run as the member when one is given, since a GOS may refuse them to anonymous callers.
 */
export async function runSuite({ host, canisterId, fetchRootKey = false, member = null, writes = false, onResult }) {
  const results = [];
  const actors = async (identity) => {
    const agent = await HttpAgent.create({ host, identity, shouldFetchRootKey: fetchRootKey });
    return Actor.createActor(idlFactory, { agent, canisterId });
  };
  const anon = await actors(new AnonymousIdentity());
  const mine = member ? await actors(member) : null;
  const reader = mine ?? anon;

  async function check(standard, id, title, fn, level = 'must') {
    let result;
    try {
      result = { standard, id, title, outcome: 'pass', detail: (await fn()) || '' };
    } catch (e) {
      const outcome = e instanceof Skip ? 'skip' : level === 'must' ? 'fail' : 'warn';
      result = { standard, id, title, outcome, detail: e.message };
    }
    results.push(result);
    onResult?.(result);
    return result;
  }

  let declared = new Set();
  let proposals = [];

  await check('GGG', 'D1', 'icrc10_supported_standards lists ICRC-10 and GGG', async () => {
    const list = await anon.icrc10_supported_standards();
    const names = list.map((s) => s.name);
    declared = new Set(names);
    assert(declared.size === names.length, `duplicate names in ${show(names)}`);
    for (const s of list) assert(/^https:\/\/\S+$/.test(s.url), `${s.name} has no https URL: "${s.url}"`);
    const missing = ['ICRC-10', 'GGG'].filter((n) => !declared.has(n));
    assert(!missing.length, `${missing.join(', ')} missing from ${show(names)}`);
    return names.join(', ');
  });

  await check('GGG', 'D2', 'icrc10_supported_standards lists ICRC-21 (consent messages)', async () => {
    assert(declared.has('ICRC-21'), 'ICRC-21 is not listed, so wallets cannot show what a member signs');
  }, 'should');

  await check('GGG', 'R1', 'ggg_realm_info describes the realm to anyone', async () => {
    const realm = await anon.ggg_realm_info();
    assert(realm.name.length > 0, 'name is empty');
    assert(realm.installed_version.length > 0, 'installed_version is empty');
    checkUrl(realm.logo_url, 'logo_url');
    checkUrl(realm.background_image_url, 'background_image_url');
    const currency = opt(realm.accounting_currency);
    assert(currency === null || currency.length > 0, 'accounting_currency is empty');
    return `${realm.name}: ${realm.installed_version}, ${tag(realm.status)}`;
  });

  await check('GGG', 'M1', 'ggg_user_get answers a caller about itself', async () => {
    const m = ok(await anon.ggg_user_get(Principal.anonymous()), 'ggg_user_get(anonymous, as anonymous)');
    assert(m.length === 0, `the anonymous principal is a member: ${show(m)}`);
    if (!mine) return 'anonymous only';
    const me = member.getPrincipal();
    const found = opt(ok(await mine.ggg_user_get(me), 'ggg_user_get(self)'));
    if (found) assert(found.user.id.toText() === me.toText(), `ggg_user_get(${me.toText()}) returns ${found.user.id.toText()}`);
    const membership = found && opt(found.member);
    return membership ? `${me.toText()} is ${tag(membership.status)}` : `${me.toText()} is not a member`;
  });

  await check('GGG', 'M2', 'ggg_user_list paginates, and each user can be looked up', async () => {
    const walked = await walk((a) => reader.ggg_user_list(a), (e) => e.user.id.toText());
    const detail = checkWalk(walked, 'ggg_user_list');
    for (const e of walked.items) checkUser(e);
    for (const e of walked.items.slice(0, 5)) {
      const id = e.user.id;
      const found = opt(ok(await reader.ggg_user_get(id), 'ggg_user_get'));
      assert(found && found.user.id.toText() === id.toText(), `ggg_user_get(${id.toText()}) does not find a listed user`);
      assert(show(found.member) === show(e.member), `user ${id.toText()}: the membership differs between list and get`);
    }
    return detail;
  });

  await check('GGG', 'P1', 'ggg_proposal_list paginates and returns well-formed summaries', async () => {
    const walked = await walk((a) => reader.ggg_proposal_list({ ...a, status: [] }), (p) => p.id);
    const detail = checkWalk(walked, 'ggg_proposal_list');
    walked.items.forEach(checkProposal);
    proposals = walked.items;
    return detail;
  });

  await check('GGG', 'P2', 'ggg_proposal_get finds each listed proposal', async () => {
    if (!proposals.length) throw new Skip('the realm has no proposals, or they could not be listed');
    for (const listed of proposals.slice(0, 5)) {
      const p = (await getProposal(reader, listed.id))?.proposal;
      assert(p && p.id === listed.id, `ggg_proposal_get(${listed.id}) does not find it`);
      sameProposal(listed, p);
    }
  });

  await check('GGG', 'P3', 'ggg_proposal_get returns Ok(null) for an unknown id', async () => {
    const result = await reader.ggg_proposal_get(getArgs(NO_PROPOSAL));
    refused(result.Err, 'ggg_proposal_get');
    const found = ok(result, 'ggg_proposal_get(unknown)');
    assert(found.length === 0, `returned ${show(found)}`);
  });

  await check('GGG', 'P4', 'ggg_proposal_list filters by status', async () => {
    const status = proposals.length ? proposals[0].status : { Voting: null };
    const result = await reader.ggg_proposal_list({ cursor: [], limit: [PAGE], status: [status] });
    refused(result.Err, 'ggg_proposal_list');
    for (const p of ok(result, 'ggg_proposal_list(status)').items) {
      assert(tag(p.status) === tag(status), `filter ${tag(status)} returned proposal ${p.id} with ${tag(p.status)}`);
    }
    return `filtered on ${tag(status)}`;
  });

  await check('GGG', 'P5', 'a malformed cursor returns InvalidArgument', async () => {
    const result = await reader.ggg_proposal_list({ cursor: [BAD_CURSOR], limit: [PAGE], status: [] });
    refused(result.Err, 'ggg_proposal_list');
    err(result, ['InvalidArgument'], 'ggg_proposal_list(malformed cursor)');
  });

  await check('GGG', 'P6', 'proposal ids are at most 64 bytes', async () => {
    const long = proposals.filter((p) => new TextEncoder().encode(p.id).length > 64);
    assert(!long.length, `${long.length} ids are longer, e.g. ${long[0]?.id}`);
  }, 'should');

  await check('GGG', 'V1', 'ggg_proposal_get pages the votes, one per voter', async () => {
    if (!proposals.length) throw new Skip('the realm has no proposals, or they could not be listed');
    const id = proposals[0].id;
    const walked = await walk(votePages(reader, id), (v) => v.voter.toText());
    const detail = checkWalk(walked, 'ggg_proposal_get');
    for (const v of walked.items) assert(v.proposal === id, `a vote listed under ${id} is for ${v.proposal}`);
    return `proposal ${id}: ${detail}`;
  });

  const lists = listTable(reader);
  for (const [i, list] of lists.entries()) {
    await check('GGG', `L${i + 1}`, `${list.what} paginates`, async () => {
      const walked = await walk(list.pages(), itemKey);
      const detail = checkWalk(walked, list.what);
      list.seen?.(walked.items);
      return detail;
    });
  }

  await check('GGG', 'C1', 'every list returns InvalidArgument for a malformed cursor', async () => {
    const refusedTo = [];
    for (const list of lists) {
      let pages;
      try {
        pages = list.pages();
      } catch (e) {
        if (e instanceof Skip) continue;
        throw e;
      }
      const result = await pages({ cursor: [BAD_CURSOR], limit: [PAGE] });
      if ('Err' in result && ['Forbidden', 'Unauthenticated'].includes(tag(result.Err))) refusedTo.push(list.what);
      else err(result, ['InvalidArgument'], `${list.what}(malformed cursor)`);
    }
    return refusedTo.length ? `refused to this caller: ${refusedTo.join(', ')}` : `${lists.length} lists`;
  });

  await check('GGG', 'G1', 'every lookup by id returns Ok(null) for an unknown id', async () => {
    for (const [what, call] of getTable(reader)) {
      const result = await call(UNKNOWN);
      if ('Err' in result && ['Forbidden', 'Unauthenticated'].includes(tag(result.Err))) continue;
      const found = ok(result, `${what}(unknown)`);
      assert(found.length === 0, `${what}(unknown) returned ${show(found)}`);
    }
  });

  const needWrites = () => {
    if (!writes) throw new Skip('update checks are off (--writes)');
  };
  const needMember = () => {
    needWrites();
    if (!mine) throw new Skip('no member identity given (--member-pem)');
  };
  const motion = (title, extra = {}) => ({
    title,
    description: 'Created by the GGG conformance suite. It can be withdrawn or ignored.',
    department: [],
    action: { Motion: null },
    on_behalf_of: [],
    ...extra,
  });
  const vote = (proposal, choice) => ({ proposal, choice: { [choice]: null }, on_behalf_of: [] });
  const votesOf = async (id) => {
    const walked = await walk(votePages(mine, id), (v) => v.voter.toText());
    if (walked.err) throw new Error(`ggg_proposal_get(${id}) returned Err ${show(walked.err)}`);
    return walked.items.filter((v) => v.voter.toText() === member.getPrincipal().toText());
  };
  const proposeAs = async (args, what) => {
    const result = await mine.ggg_proposal_create(args);
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    return err(result, ['InvalidArgument'], what);
  };

  await check('GGG', 'W1', 'every update refuses an anonymous caller', async () => {
    needWrites();
    const updates = updateTable().filter(([method]) => !PUBLIC_UPDATES.has(method));
    for (const [method, args] of updates) err(await anon[method](...args), ['Unauthenticated'], method);
    return `${updates.length} updates`;
  });

  let created = null;
  await check('GGG', 'W2', 'a member files a realm-wide Motion and can read it back', async () => {
    needMember();
    const title = `GGG conformance check ${new Date().toISOString()}`;
    const result = await mine.ggg_proposal_create(motion(title));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    const id = ok(result, 'ggg_proposal_create');
    const p = (await getProposal(mine, id))?.proposal;
    assert(p, `ggg_proposal_get(${id}) does not find the new proposal`);
    checkProposal(p);
    assert(p.title === title, `title is "${p.title}"`);
    assert(p.proposer.toText() === member.getPrincipal().toText(), `proposer is ${p.proposer.toText()}`);
    assert(['Draft', 'Voting'].includes(tag(p.status)), `a new proposal is ${tag(p.status)}`);
    assert(tag(p.action) === 'Motion', `action is ${tag(p.action)}`);
    assert(p.department.length === 0, `a realm-wide proposal has department ${show(p.department)}`);
    created = p;
    return `proposal ${id}, ${tag(p.status)}`;
  });

  await check('GGG', 'W3', 'a member votes, and a second vote replaces the first', async () => {
    needMember();
    if (!created) throw new Skip('no proposal was filed');
    if (tag(created.status) !== 'Voting') throw new Skip('the new proposal is not open for voting yet');
    const me = member.getPrincipal().toText();
    const result = await mine.ggg_proposal_vote(vote(created.id, 'Yes'));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not vote');
    const v = ok(result, 'ggg_proposal_vote');
    assert(v.proposal === created.id, `the vote is for ${v.proposal}`);
    assert(v.voter.toText() === me, `voter is ${v.voter.toText()}`);
    assert(tag(v.choice) === 'Yes', `choice is ${tag(v.choice)}`);
    const castBy = opt(v.cast_by);
    assert(castBy === null || castBy.toText() === me, `cast_by is ${castBy?.toText()}`);
    const recorded = await votesOf(created.id);
    assert(recorded.length === 1 && tag(recorded[0].choice) === 'Yes', `the recorded votes are ${show(recorded)}`);

    ok(await mine.ggg_proposal_vote(vote(created.id, 'No')), 'a second ggg_proposal_vote');
    const changed = await votesOf(created.id);
    assert(changed.length === 1 && tag(changed[0].choice) === 'No', `after voting again, the votes are ${show(changed)}`);
  });

  await check('GGG', 'W4', 'the tally counts the vote once', async () => {
    needMember();
    if (!created || tag(created.status) !== 'Voting') throw new Skip('no proposal open for voting was filed');
    const { tally } = (await getProposal(mine, created.id)).proposal;
    const { yes, no, abstain } = tally;
    assert(yes + no + abstain > 0n, 'the tally is still zero (allowed only with secret ballots)');
    assert(yes === 0n && no === 1n && abstain === 0n, `after Yes then No, the tally is ${show(tally)}`);
  }, 'should');

  await check('GGG', 'W5', 'a vote on an unknown proposal returns NotFound', async () => {
    needMember();
    const result = await mine.ggg_proposal_vote(vote(NO_PROPOSAL, 'Yes'));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not vote');
    err(result, ['NotFound'], 'ggg_proposal_vote(unknown proposal)');
  });

  await check('GGG', 'W6', 'a proposal for an unknown department returns NotFound', async () => {
    needMember();
    const result = await mine.ggg_proposal_create(motion('unknown department', { department: [NO_DEPARTMENT] }));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    err(result, ['NotFound'], 'ggg_proposal_create(unknown department)');
  });

  await check('GGG', 'W7', 'a proposal to call a method the canister lacks returns InvalidArgument', async () => {
    needMember();
    const action = { Call: { method: NO_METHOD, arg: new Uint8Array(IDL.encode([], [])) } };
    await proposeAs(motion('unknown method', { action }), 'ggg_proposal_create(unknown method)');
  });

  await check('GGG', 'W8', 'a proposal whose call arguments do not decode returns InvalidArgument', async () => {
    needMember();
    const arg = new Uint8Array(IDL.encode([IDL.Text], ['not a ProposalVoteArgs']));
    const action = { Call: { method: 'ggg_proposal_vote', arg } };
    await proposeAs(motion('malformed call', { action }), 'ggg_proposal_create(malformed arg)');
  });

  await check('GGG', 'W9', 'acting on behalf of someone without their delegation returns Forbidden', async () => {
    needMember();
    const forStranger = [Ed25519KeyIdentity.generate().getPrincipal()];
    const real = [
      ['ggg_proposal_create', motion('no delegation', { on_behalf_of: forStranger })],
      ['ggg_profile_update', { nickname: ['GGG conformance'], avatar: [], on_behalf_of: forStranger }],
    ];
    if (created) {
      real.push(['ggg_proposal_vote', { ...vote(created.id, 'Yes'), on_behalf_of: forStranger }]);
      real.push(['ggg_proposal_withdraw', { proposal: created.id, on_behalf_of: forStranger }]);
    }
    for (const [method, args] of real) err(await mine[method](args), ['Forbidden'], `${method}(on_behalf_of a stranger)`);
    // With blank arguments, a GOS may find the arguments wrong before it checks the delegation.
    const delegable = updateTable().filter(([method, [args]]) => args?.on_behalf_of && !real.some(([m]) => m === method));
    for (const [method, [args]] of delegable) {
      const result = await mine[method]({ ...args, on_behalf_of: forStranger });
      err(result, ['Forbidden', 'NotFound', 'InvalidArgument'], `${method}(on_behalf_of a stranger)`);
    }
    return `${real.length} with real arguments, ${delegable.length} more with blank ones`;
  });

  await check('GGG', 'W10', "the member's proposal is in the audit log", async () => {
    needMember();
    if (!created) throw new Skip('no proposal was filed');
    const me = member.getPrincipal().toText();
    const result = await mine.ggg_events({ cursor: [], limit: [PAGE * 5] });
    refused(result.Err, 'ggg_events');
    const recent = ok(result, 'ggg_events').items;
    const filed = recent.find((e) => e.op === 'proposal_create' && opt(e.user)?.toText() === me);
    assert(filed, `no proposal_create by ${me} among the ${recent.length} newest events`);
    for (let i = 1; i < recent.length; i++) {
      assert(recent[i - 1].at >= recent[i].at, `events ${recent[i - 1].id} and ${recent[i].id} are not newest first`);
    }
  });

  let withdrawn = false;
  await check('GGG', 'W11', 'a member withdraws their own proposal', async () => {
    needMember();
    if (!created) throw new Skip('no proposal was filed');
    const result = await mine.ggg_proposal_withdraw({ proposal: created.id, on_behalf_of: [] });
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not withdraw proposals');
    const p = ok(result, 'ggg_proposal_withdraw');
    assert(tag(p.status) === 'Withdrawn', `after withdrawing, the proposal is ${tag(p.status)}`);
    const read = (await getProposal(mine, created.id))?.proposal;
    assert(read && tag(read.status) === 'Withdrawn', `ggg_proposal_get shows ${read && tag(read.status)}`);
    withdrawn = true;
  });

  await check('GGG', 'W12', 'a withdrawn proposal takes no votes and cannot be withdrawn again', async () => {
    needMember();
    if (!withdrawn) throw new Skip('no proposal was withdrawn');
    err(await mine.ggg_proposal_vote(vote(created.id, 'Yes')), ['Conflict'], 'ggg_proposal_vote(withdrawn)');
    err(await mine.ggg_proposal_withdraw({ proposal: created.id, on_behalf_of: [] }), ['Conflict'], 'a second ggg_proposal_withdraw');
  });

  return results;
}
