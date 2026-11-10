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
// Every ratio is in hundred-millionths: 100 % is 100 000 000.
const WHOLE = 100_000_000n;
// A nonzero ratio under 1 % is more likely a basis-point value nobody converted (50 % was 5 000) than
// a real quorum, so the suite warns about it.
const SUSPICIOUSLY_SMALL = 1_000_000n;

export const looksLikeBasisPoints = (ratio) => ratio > 0n && ratio < SUSPICIOUSLY_SMALL;

// A time zone name has the shape of the IANA database's: `Area/Location`, up to three parts, with
// one of its areas, or `UTC`. The shape is checked, not each city, so no zone list ships here.
const TIMEZONE_AREAS = 'Africa|America|Antarctica|Arctic|Asia|Atlantic|Australia|Europe|Indian|Pacific|Etc';
const TIMEZONE = new RegExp(`^(UTC|(${TIMEZONE_AREAS})/[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)?)$`);

export const isTimezoneName = (name) => TIMEZONE.test(name);

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
    assert(p[field] <= WHOLE, `proposal ${p.id}: ${field} is ${p[field]}, above ${WHOLE} (100 %)`);
  }
  assert(tag(p.status) !== 'ExecutionScheduled' || opt(p.effective_at) !== null, `proposal ${p.id} is scheduled but has no effective_at`);
  assert(tag(p.status) !== 'ExecutionScheduled' || tag(p.action) !== 'Motion', `proposal ${p.id}: a motion has nothing to schedule`);
  const linked = p.links.map((l) => l.proposal);
  assert(new Set(linked).size === linked.length, `proposal ${p.id}: its links name a proposal twice`);
  assert(!linked.includes(p.id), `proposal ${p.id} links to itself`);
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

/** The vote has ended early: every eligible member has voted, so no vote can be replaced. */
function everyoneVoted(p) {
  const eligible = opt(p.tally.eligible);
  return eligible !== null && p.tally.yes + p.tally.no + p.tally.abstain >= eligible;
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

/** ggg_proposal_linked_from, as pages for walk(). */
const linkPages = (actor, id) => async ({ cursor, limit }) => {
  const result = await actor.ggg_proposal_linked_from({ id, cursor, limit });
  if ('Err' in result) return result;
  const page = opt(result.Ok);
  return page ? { Ok: page } : { Err: { NotFound: null } };
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
  let proposal = null;
  let delegation = null;
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
  const needProposal = () => {
    if (!proposal) throw new Skip('the realm lists no proposal');
    return proposal;
  };
  const needScope = () => {
    if (!scope) throw new Skip('the caller can open no key scope');
    return scope;
  };
  const needDelegation = () => {
    if (!delegation) throw new Skip('the caller has no grant, given or received');
    return delegation;
  };
  const firstDelegation = (items) => {
    delegation ??= items[0]?.id ?? null;
  };
  return [
    list('ggg_proposal_list', () => (a) => actor.ggg_proposal_list({ ...a, status: [], tags: [] }), 'items', (items) => {
      proposal = items[0]?.id ?? null;
    }),
    list('ggg_proposal_linked_from', () => {
      const id = needProposal();
      return (a) => actor.ggg_proposal_linked_from({ ...a, id });
    }),
    list('ggg_invite_list', () => (a) => actor.ggg_invite_list(a)),
    list('ggg_delegation_list (as grantor)', () => (a) => actor.ggg_delegation_list({ ...a, role: { Grantor: null } }), 'items', firstDelegation),
    list('ggg_delegation_list (as delegate)', () => (a) => actor.ggg_delegation_list({ ...a, role: { Delegate: null } }), 'items', firstDelegation),
    list('ggg_delegation_groups', () => (a) => actor.ggg_delegation_groups({ ...a, on_behalf_of: [] })),
    list('ggg_delegation_activity', () => {
      const id = needDelegation();
      return (a) => actor.ggg_delegation_activity({ ...a, delegation: id, on_behalf_of: [] });
    }),
    list('ggg_action_list (as grantor)', () => (a) => actor.ggg_action_list({ ...a, role: { Grantor: null }, status: [] })),
    list('ggg_action_list (as delegate)', () => (a) => actor.ggg_action_list({ ...a, role: { Delegate: null }, status: [] })),
    list('ggg_attribute_list', () => (a) => actor.ggg_attribute_list({ ...a, kind: [], on_behalf_of: [] })),
    list('ggg_department_list', () => (a) => actor.ggg_department_list(a), 'items', (items) => {
      department = items[0]?.id ?? null;
    }),
    list('ggg_department_get (seats)', () => {
      const id = needDepartment();
      return (a) => actor.ggg_department_get({ ...a, id });
    }, 'seats'),
    list('ggg_department_chart (sub-departments)', () => (a) => actor.ggg_department_chart({ ...a, department: [] }), 'children'),
    list('ggg_organization_list', () => (a) => actor.ggg_organization_list({ ...a, status: [], kind: [] })),
    list('ggg_treasury_view (funds)', () => (a) => actor.ggg_treasury_view(a), 'funds'),
    list('ggg_ledger_view', () => (a) =>
      actor.ggg_ledger_view({ ...a, transaction: [], symbol: [], kind: [], fund: [], period: [] })),
    list('ggg_report_view', () => (a) => actor.ggg_report_view({ ...a, id: [] })),
    list('ggg_loan_list', () => (a) => actor.ggg_loan_list({ ...a, status: [] })),
    list('ggg_my_invoices', () => (a) => actor.ggg_my_invoices({ ...a, on_behalf_of: [] })),
    list('ggg_land_list', () => (a) => actor.ggg_land_list({ ...a, owner: [] })),
    list('ggg_land_map (zones)', () => (a) => actor.ggg_land_map({ ...a, x: 0n, y: 0n, w: 32n, h: 32n }), 'zones'),
    list('ggg_license_list', () => (a) => actor.ggg_license_list({ ...a, holder: [], kind: [], status: [] })),
    list('ggg_procedure_list', () => (a) => actor.ggg_procedure_list(a)),
    list('ggg_request_list', () => (a) => actor.ggg_request_list({ ...a, kind: [], status: [] })),
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
    list('ggg_external_list', () => (a) => actor.ggg_external_list(a)),
    list('ggg_dispatch_list', () => (a) => actor.ggg_dispatch_list({ ...a, to: [], status: [] })),
    list('ggg_task_list', () => (a) => actor.ggg_task_list({ ...a, op: [], status: [] })),
    list('ggg_crypto_scopes', () => (a) => actor.ggg_crypto_scopes(a), 'items', (items) => {
      scope = items[0] ?? null;
    }),
    list('ggg_crypto_access', () => {
      const s = needScope();
      return (a) => actor.ggg_crypto_access({ ...a, scope: s });
    }),
    list('ggg_document_list', () => {
      const d = needDepartment();
      return (a) => actor.ggg_document_list({ ...a, department: d, kind: [], language: [] });
    }),
  ];
}

/** Every bound lookup by id. */
const getTable = (actor) => [
  ['ggg_department_get', (id) => actor.ggg_department_get({ id, ...none })],
  ['ggg_proposal_linked_from', (id) => actor.ggg_proposal_linked_from({ id, ...none })],
  ['ggg_organization_get', (id) => actor.ggg_organization_get({ id, ...none })],
  ['ggg_tender_get', (id) => actor.ggg_tender_get({ id, ...none })],
  ['ggg_contract_get', (id) => actor.ggg_contract_get({ id, ...none })],
  ['ggg_dispute_get', (id) => actor.ggg_dispute_get({ id, on_behalf_of: [] })],
  ['ggg_request_get', (id) => actor.ggg_request_get({ id, on_behalf_of: [] })],
  ['ggg_crypto_envelope', (id) => actor.ggg_crypto_envelope(id)],
  ['ggg_document_get', (id) => actor.ggg_document_get(id)],
  ['ggg_action_get', (id) => actor.ggg_action_get(id)],
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

/** A method's arguments, Candid-encoded with its own types, as the generic call carries them. */
function encodeArgs(method, args) {
  const [, fn] = idlFactory({ IDL })._fields.find(([name]) => name === method);
  return new Uint8Array(IDL.encode(fn.argTypes, args));
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

  await check('GGG', 'R2', 'the realm states its voting threshold and quorum in hundred-millionths', async () => {
    const realm = await anon.ggg_realm_info();
    for (const field of ['voting_threshold', 'voting_quorum']) {
      assert(realm[field] <= WHOLE, `${field} is ${realm[field]}, above ${WHOLE} (100 %)`);
    }
    return `threshold ${realm.voting_threshold}, quorum ${realm.voting_quorum}`;
  });

  await check('GGG', 'R3', 'the realm names its time zone with an IANA name', async () => {
    const { timezone } = await anon.ggg_realm_info();
    assert(isTimezoneName(timezone), `timezone "${timezone}" is not an IANA name such as Europe/Madrid, or UTC`);
    return timezone;
  });

  await check('GGG', 'O1', 'department policies state their quorum in hundred-millionths', async () => {
    const walked = await walk((a) => reader.ggg_department_list(a), (d) => d.id);
    const detail = checkWalk(walked, 'ggg_department_list');
    for (const d of walked.items) {
      for (const [name, policy] of [['policy', d.policy], ['target_policy', opt(d.target_policy)]]) {
        if (policy) assert(policy.quorum <= WHOLE, `department ${d.id}: ${name}.quorum is ${policy.quorum}, above ${WHOLE} (100 %)`);
      }
    }
    return detail;
  });

  await check('GGG', 'O2', 'ggg_organization_list filters by kind', async () => {
    let listed = 0;
    for (const kind of ['Company', 'Party', 'Union', 'Association', 'Other']) {
      const walked = await walk((a) => reader.ggg_organization_list({ ...a, status: [], kind: [{ [kind]: null }] }), (o) => o.id);
      checkWalk(walked, `ggg_organization_list(${kind})`);
      for (const o of walked.items) assert(tag(o.kind) === kind, `organization ${o.id} is ${tag(o.kind)}, listed as ${kind}`);
      listed += walked.items.length;
    }
    return `${listed} organizations listed by kind`;
  });

  await check('GGG', 'Q1', 'ggg_join_targets takes a home_zone or none and gives it to no one, and the directory has no zone definitions', async () => {
    const zone = 'ggg-conformance-zone';
    const replies = [
      ok(await anon.ggg_join_targets([]), 'ggg_join_targets with no argument'),
      ok(await anon.ggg_join_targets([{ home_zone: [] }]), 'ggg_join_targets without a home_zone'),
      ok(await anon.ggg_join_targets([{ home_zone: [zone] }]), 'ggg_join_targets with a home_zone'),
    ];
    for (const reply of replies) assert(!show(reply).includes(zone), `ggg_join_targets gives back the zone it was told: ${show(reply)}`);
    const directory = ok(await anon.ggg_quarter_directory({ cursor: [], limit: [] }), 'ggg_quarter_directory');
    assert(opt(directory.zones) === null, `ggg_quarter_directory carries zones, which only quarter_sync does: ${show(directory.zones)}`);
    return `${replies[2].targets.length} quarters take joins`;
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

  await check('GGG', 'M3', 'ggg_me returns the caller, their permissions and their delegations', async () => {
    const result = await reader.ggg_me({ on_behalf_of: [] });
    refused(result.Err, 'ggg_me');
    const card = ok(result, 'ggg_me');
    checkUser({ user: card.user, member: card.member });
    if (mine) {
      const me = member.getPrincipal();
      assert(card.user.id.toText() === me.toText(), `ggg_me returns ${card.user.id.toText()}`);
    }
    assert(card.permissions.every((p) => p.length > 0), 'a permission name is empty');
    return `${card.permissions.length} permissions, ${card.delegations.length} delegations`;
  });

  await check('GGG', 'P1', 'ggg_proposal_list paginates and returns well-formed summaries', async () => {
    const walked = await walk((a) => reader.ggg_proposal_list({ ...a, status: [], tags: [] }), (p) => p.id);
    const detail = checkWalk(walked, 'ggg_proposal_list');
    walked.items.forEach(checkProposal);
    proposals = walked.items;
    return detail;
  });

  await check('GGG', 'R4', 'no ratio looks like an unconverted basis-point value', async () => {
    const realm = await anon.ggg_realm_info();
    const walked = await walk((a) => reader.ggg_department_list(a), (d) => d.id);
    checkWalk(walked, 'ggg_department_list');
    const ratios = [
      ['realm voting_threshold', realm.voting_threshold],
      ['realm voting_quorum', realm.voting_quorum],
    ];
    for (const d of walked.items) {
      ratios.push([`department ${d.id} policy.quorum`, d.policy.quorum]);
      const target = opt(d.target_policy);
      if (target) ratios.push([`department ${d.id} target_policy.quorum`, target.quorum]);
    }
    for (const p of proposals) {
      ratios.push([`proposal ${p.id} threshold`, p.threshold], [`proposal ${p.id} quorum`, p.quorum]);
    }
    const small = ratios.filter(([, value]) => looksLikeBasisPoints(value)).map(([what, value]) => `${what} is ${value}`);
    assert(!small.length, `under 1 % (${SUSPICIOUSLY_SMALL}), so basis points? ${small.join('; ')}`);
    return `${ratios.length} ratios`;
  }, 'should');

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
    const result = await reader.ggg_proposal_list({ cursor: [], limit: [PAGE], status: [status], tags: [] });
    refused(result.Err, 'ggg_proposal_list');
    for (const p of ok(result, 'ggg_proposal_list(status)').items) {
      assert(tag(p.status) === tag(status), `filter ${tag(status)} returned proposal ${p.id} with ${tag(p.status)}`);
    }
    return `filtered on ${tag(status)}`;
  });

  await check('GGG', 'P5', 'a malformed cursor returns InvalidArgument', async () => {
    const result = await reader.ggg_proposal_list({ cursor: [BAD_CURSOR], limit: [PAGE], status: [], tags: [] });
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
    kind: [],
    matter: [],
    threshold: [],
    quorum: [],
    threshold_of: [],
    effective_at: [],
    links: [],
    tags: [],
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

  let replaced = false;
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

    const voted = (await getProposal(mine, created.id)).proposal;
    if (everyoneVoted(voted)) throw new Skip('the vote ended with this vote, as every eligible member has voted, so it cannot be replaced');
    ok(await mine.ggg_proposal_vote(vote(created.id, 'No')), 'a second ggg_proposal_vote');
    const changed = await votesOf(created.id);
    assert(changed.length === 1 && tag(changed[0].choice) === 'No', `after voting again, the votes are ${show(changed)}`);
    replaced = true;
  });

  await check('GGG', 'W4', 'the tally counts the vote once', async () => {
    needMember();
    if (!created || tag(created.status) !== 'Voting') throw new Skip('no proposal open for voting was filed');
    if (!replaced) throw new Skip('no vote was replaced');
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
    const profile = { nickname: ['GGG conformance'], avatar: [], language: [], on_behalf_of: [] };
    const real = [
      ['ggg_proposal_create', motion('no delegation', { on_behalf_of: forStranger })],
      ['ggg_profile_update', { ...profile, on_behalf_of: forStranger }],
      // The member's own act: refused under any grant, so under a stranger's too.
      ['ggg_delegation_revoke_all', { cursor: [], limit: [], on_behalf_of: forStranger }],
      // The generic call and its query twin carry the grantor as a required principal.
      ['ggg_call_for', { method: 'ggg_profile_update', arg: encodeArgs('ggg_profile_update', [profile]), on_behalf_of: forStranger[0], note: [] }],
      ['ggg_read_for', { method: 'ggg_me', arg: encodeArgs('ggg_me', [{ on_behalf_of: [] }]), on_behalf_of: forStranger[0] }],
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

  await check('GGG', 'W13', 'a proposal states an effective_at, and it is read back unchanged', async () => {
    needMember();
    const effective = BigInt(Date.now() + 365 * 24 * 3600 * 1000) * 1_000_000n;
    const title = `GGG conformance check ${new Date().toISOString()} (effective_at)`;
    const result = await mine.ggg_proposal_create(motion(title, { effective_at: [effective] }));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    const id = ok(result, 'ggg_proposal_create(effective_at)');
    try {
      const p = (await getProposal(mine, id))?.proposal;
      assert(p, `ggg_proposal_get(${id}) does not find the new proposal`);
      checkProposal(p);
      assert(opt(p.effective_at) === effective, `effective_at is ${show(p.effective_at)}, not ${effective}`);
      return `proposal ${id}, effective_at ${effective}`;
    } finally {
      await mine.ggg_proposal_withdraw({ proposal: id, on_behalf_of: [] });
    }
  });

  await check('GGG', 'W14', 'an effective_at in the past returns InvalidArgument', async () => {
    needMember();
    await proposeAs(motion('effective in the past', { effective_at: [1n] }), 'ggg_proposal_create(effective_at in the past)');
  });

  const link = (kind, proposal) => ({ kind: { [kind]: null }, proposal });
  /** Files a Motion with the given links, and withdraws it when `then` is done. */
  const fileLinked = async (title, links, then) => {
    const result = await mine.ggg_proposal_create(motion(`GGG conformance check ${new Date().toISOString()} (${title})`, { links: [links] }));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    const id = ok(result, `ggg_proposal_create(${title})`);
    try {
      return await then(id);
    } finally {
      await mine.ggg_proposal_withdraw({ proposal: id, on_behalf_of: [] });
    }
  };
  const linkedFrom = async (id) => {
    const walked = await walk(linkPages(mine, id), (l) => `${tag(l.kind)}:${l.proposal}`);
    if (walked.err) throw new Error(`ggg_proposal_linked_from(${id}) returned Err ${show(walked.err)}`);
    return walked.items.map((l) => `${tag(l.kind)}:${l.proposal}`);
  };

  await check('GGG', 'W15', 'a proposal replaces a withdrawn one, and the replaced one shows it is replaced', async () => {
    needMember();
    await fileLinked('to be replaced', [], async (old) => {
      ok(await mine.ggg_proposal_withdraw({ proposal: old, on_behalf_of: [] }), 'ggg_proposal_withdraw');
      await fileLinked('replacement', [link('Replaces', old)], async (next) => {
        const p = (await getProposal(mine, next)).proposal;
        checkProposal(p);
        assert(show(p.links) === show([link('Replaces', old)]), `links are ${show(p.links)}`);
        assert((await linkedFrom(old)).includes(`Replaces:${next}`), `${old} does not show it is replaced by ${next}`);
        const replaced = opt((await getProposal(mine, old)).replaced_by);
        assert(replaced === next, `ggg_proposal_get(${old}) shows replaced_by ${replaced}, not ${next}`);
        const again = await mine.ggg_proposal_create(motion('a second replacement', { links: [[link('Replaces', old)]] }));
        err(again, ['Conflict'], 'a second Replaces of the same proposal');
      });
    });
  });

  await check('GGG', 'W16', 'a proposal relates to another, and both show it', async () => {
    needMember();
    await fileLinked('referenced', [], async (a) => {
      await fileLinked('relates to', [link('RelatesTo', a)], async (b) => {
        const p = (await getProposal(mine, b)).proposal;
        assert(show(p.links) === show([link('RelatesTo', a)]), `links are ${show(p.links)}`);
        assert((await linkedFrom(a)).includes(`RelatesTo:${b}`), `${a} does not show that ${b} relates to it`);
      });
    });
  });

  await check('GGG', 'W17', 'a link to an unknown proposal, to an open one it replaces, or the same one twice is refused', async () => {
    needMember();
    await fileLinked('open', [], async (open) => {
      const attempt = async (links, tags, what) => {
        const result = await mine.ggg_proposal_create(motion(what, { links: [links] }));
        if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
        err(result, tags, `ggg_proposal_create(${what})`);
      };
      await attempt([link('RelatesTo', UNKNOWN)], ['NotFound'], 'link to an unknown proposal');
      await attempt([link('Replaces', open)], ['Conflict'], 'replaces a proposal that is not withdrawn');
      await attempt([link('RelatesTo', open), link('RelatesTo', open)], ['InvalidArgument'], 'links the same proposal twice');
    });
  });

  /** Files a Motion with `extra` on top of the defaults, runs `then` on the proposal, and withdraws it. */
  const fileRule = async (title, extra, then) => {
    const result = await mine.ggg_proposal_create(motion(`GGG conformance check ${new Date().toISOString()} (${title})`, extra));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    const id = ok(result, `ggg_proposal_create(${title})`);
    try {
      return await then((await getProposal(mine, id)).proposal);
    } finally {
      await mine.ggg_proposal_withdraw({ proposal: id, on_behalf_of: [] });
    }
  };

  await check('GGG', 'W18', "a proposal's rule defaults to the realm's over the votes cast, and its kind and matter are kept", async () => {
    needMember();
    const realm = await anon.ggg_realm_info();
    await fileRule('default rule', { kind: ['motion'], matter: ['conformance'] }, (p) => {
      assert(p.threshold === realm.voting_threshold, `threshold is ${p.threshold}, the realm's is ${realm.voting_threshold}`);
      assert(p.quorum === realm.voting_quorum, `quorum is ${p.quorum}, the realm's is ${realm.voting_quorum}`);
      assert(tag(p.threshold_of) === 'Cast', `threshold_of is ${tag(p.threshold_of)}`);
      assert(show(p.casting_vote) === show(realm.casting_vote), `casting_vote is ${show(p.casting_vote)}, the realm's is ${show(realm.casting_vote)}`);
      assert(opt(p.kind) === 'motion' && opt(p.matter) === 'conformance', `kind and matter are ${show(p.kind)}, ${show(p.matter)}`);
    });
  });

  await check('GGG', 'W19', 'a rule weaker than the default is refused', async () => {
    needMember();
    const realm = await anon.ggg_realm_info();
    const weaker = [];
    if (realm.voting_threshold > 0n) weaker.push(['lower threshold', { threshold: [realm.voting_threshold - 1n] }]);
    if (realm.voting_quorum > 0n) weaker.push(['lower quorum', { quorum: [realm.voting_quorum - 1n] }]);
    if (!weaker.length) throw new Skip('the realm has no threshold and no quorum, so nothing is weaker');
    for (const [what, extra] of weaker) await proposeAs(motion(what, extra), `ggg_proposal_create(${what})`);
    return weaker.map(([what]) => what).join(', ');
  });

  await check('GGG', 'W20', 'a stricter rule is stored as stated', async () => {
    needMember();
    const realm = await anon.ggg_realm_info();
    const stricter = (ratio) => (ratio < WHOLE ? ratio + 1n : ratio);
    const threshold = stricter(realm.voting_threshold);
    const quorum = stricter(realm.voting_quorum);
    await fileRule('stricter rule', { threshold: [threshold], quorum: [quorum], threshold_of: [{ Eligible: null }] }, (p) => {
      assert(p.threshold === threshold && p.quorum === quorum, `the rule is ${p.threshold}, ${p.quorum}, not ${threshold}, ${quorum}`);
      assert(tag(p.threshold_of) === 'Eligible', `threshold_of is ${tag(p.threshold_of)}`);
    });
  });

  await check('GGG', 'W26', "a proposal of a department that counts the votes cast takes a majority of them, its quorum and its head's casting vote", async () => {
    needMember();
    const walked = await walk((a) => reader.ggg_department_list(a), (d) => d.id);
    checkWalk(walked, 'ggg_department_list');
    const counting = walked.items.find((d) => !d.is_root && tag(opt(d.policy.threshold_of) ?? { Eligible: null }) === 'Cast');
    if (!counting) throw new Skip('no department counts the votes cast');
    await fileRule('a majority of the votes cast', { department: [counting.id] }, (p) => {
      assert(tag(p.threshold_of) === 'Cast' && p.threshold === WHOLE / 2n, `the rule is ${p.threshold} of ${tag(p.threshold_of)}, not a majority of the votes cast`);
      assert(p.quorum === counting.policy.quorum, `quorum is ${p.quorum}, the policy's is ${counting.policy.quorum}`);
      assert(opt(p.majority_of_cast) === true, `majority_of_cast is ${show(p.majority_of_cast)}`);
      assert(opt(p.tally.seats) === counting.policy.n, `tally.seats is ${show(p.tally.seats)}, the policy's n is ${counting.policy.n}`);
      assert(show(p.casting_vote) === show(counting.head), `casting_vote is ${show(p.casting_vote)}, the head is ${show(counting.head)}`);
    });
    return counting.id;
  });

  /** The ids of the proposals `ggg_proposal_list` returns for `tags`, every page. */
  const taggedIds = async (tags) => {
    const walked = await walk((a) => reader.ggg_proposal_list({ ...a, status: [], tags: [tags] }), (p) => p.id);
    checkWalk(walked, `ggg_proposal_list(tags ${tags.join(', ')})`);
    for (const p of walked.items) {
      assert(p.tags.some((t) => tags.includes(t)), `proposal ${p.id}, tagged ${show(p.tags)}, carries none of ${tags.join(', ')}`);
    }
    return walked.items.map((p) => p.id);
  };

  await check('GGG', 'W27', 'a proposal keeps its tags, and ggg_proposal_list finds it by any one of them', async () => {
    needMember();
    const mark = `ggg-conformance-${Date.now()}`;
    const tags = [mark, 'Old Town'];
    await fileRule('tags', { tags: [tags] }, async (p) => {
      assert(show(p.tags) === show(tags), `tags are ${show(p.tags)}, not ${show(tags)}`);
      assert((await taggedIds([`${mark}-other`, mark])).includes(p.id), `listing by ${mark} misses proposal ${p.id}`);
      assert(!(await taggedIds([`${mark}-other`])).includes(p.id), `listing by another tag finds proposal ${p.id}`);
    });
  });

  await check('GGG', 'W28', 'tags out of bounds are refused, and only a draft has its tags replaced', async () => {
    needMember();
    const many = Array.from({ length: 17 }, (_, i) => `tag-${i}`);
    for (const [what, tags] of [['17 tags', many], ['an empty tag', ['']], ['a tag of 65 characters', ['x'.repeat(65)]], ['a tag twice', ['a', 'a']]]) {
      await proposeAs(motion(what, { tags: [tags] }), `ggg_proposal_create(${what})`);
    }
    err(await reader.ggg_proposal_list({ cursor: [], limit: [PAGE], status: [], tags: [many] }), ['InvalidArgument'], 'ggg_proposal_list(17 tags)');
    err(await mine.ggg_proposal_set_tags({ proposal: NO_PROPOSAL, tags: [], on_behalf_of: [] }), ['NotFound'], 'ggg_proposal_set_tags(unknown proposal)');
    await fileRule('tags replaced', { tags: [['before']] }, async (p) => {
      const result = await mine.ggg_proposal_set_tags({ proposal: p.id, tags: ['after'], on_behalf_of: [] });
      if (tag(p.status) !== 'Draft') return err(result, ['Conflict'], `ggg_proposal_set_tags(${tag(p.status)})`);
      const replaced = ok(result, 'ggg_proposal_set_tags(draft)').tags;
      assert(show(replaced) === show(['after']), `a draft's tags are ${show(replaced)}, not after`);
    });
  });

  await check('GGG', 'W29', 'amending an unknown contract returns NotFound', async () => {
    needMember();
    const amend = { contract: UNKNOWN, value: [1n], split: [], starts_at: [], ends_at: [] };
    const result = await mine.ggg_contract_amend(amend);
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not amend contracts');
    err(result, ['NotFound'], 'ggg_contract_amend(unknown contract)');
  });

  /** The active grants the member holds as a delegate. */
  const grantsHeld = async () => {
    const grants = await walk((a) => mine.ggg_delegation_list({ ...a, role: { Delegate: null } }), (d) => d.id);
    refused(grants.err, 'ggg_delegation_list');
    if (grants.err) throw new Error(`ggg_delegation_list returned Err ${show(grants.err)}`);
    return grants.items.filter((d) => tag(d.status) === 'Active');
  };
  /** A grant covers an operation by its permission (a grant made before groups) or by its group. */
  const covers = (grant, permission, group) => grant.scope.some((s) => [permission, `group:${group}`, 'group:*'].includes(s));

  await check('GGG', 'W21', 'the generic call refuses to carry a member-only operation on behalf of a stranger', async () => {
    needMember();
    const stranger = Ed25519KeyIdentity.generate().getPrincipal();
    const blanks = Object.fromEntries(updateTable());
    const memberOnly = ['ggg_action_approve', 'ggg_action_decline', 'ggg_delegation_revoke_all'];
    for (const method of memberOnly) {
      const result = await mine.ggg_call_for({ method, arg: encodeArgs(method, blanks[method]), on_behalf_of: stranger, note: [] });
      err(result, ['Forbidden', 'InvalidArgument'], `ggg_call_for(${method})`);
    }
    return memberOnly.join(', ');
  });

  await check('GGG', 'W22', 'approving a pending action that does not exist is refused', async () => {
    needMember();
    const result = await mine.ggg_action_approve({ action: UNKNOWN, hash: 'ggg-conformance:no-such-hash', on_behalf_of: [] });
    err(result, ['NotFound', 'Forbidden', 'InvalidArgument'], 'ggg_action_approve(unknown)');
  });

  await check('GGG', 'W24', 'ggg_read_for refuses a read that asks each time, even under a grant that covers it', async () => {
    needMember();
    // The one read that asks each time (delegation.json): it goes through ggg_call_for, as a pending action.
    const method = 'ggg_attribute_pending_list';
    const bound = idlFactory({ IDL })._fields.find(([name]) => name === method);
    if (!bound) throw new Skip(`${method} is not in this ggg.did`);
    const grant = (await grantsHeld()).find((d) => covers(d, 'attribute.review', 'sign'));
    if (!grant) throw new Skip('the member holds no active grant that covers the sign group');
    const result = await mine.ggg_read_for({ method, arg: encodeArgs(method, bound[1].argTypes.map(blank)), on_behalf_of: grant.grantor });
    err(result, ['Forbidden'], `ggg_read_for(${method}, on behalf of a grantor whose grant covers it)`);
    return `refused for ${grant.grantor.toText()}`;
  });

  await check('GGG', 'W25', 'collecting a pending action that does not exist is refused', async () => {
    needMember();
    err(await mine.ggg_action_collect(UNKNOWN), ['NotFound', 'Forbidden'], 'ggg_action_collect(unknown)');
  });

  await check('GGG', 'W23', 'a delegate never votes on a proposal it filed, whichever grantor it votes for', async () => {
    needMember();
    const active = await grantsHeld();
    const filer = active.find((d) => covers(d, 'proposal.create', 'propose'));
    const voter = filer && active.find((d) => covers(d, 'proposal.vote', 'vote') && d.grantor.toText() !== filer.grantor.toText());
    if (!voter) throw new Skip('the member holds no two active grants: one to propose, and one from another member to vote');
    const filed = await mine.ggg_proposal_create(motion('filed by a delegate for one grantor', { on_behalf_of: [filer.grantor] }));
    if ('Err' in filed && tag(filed.Err) === 'Forbidden') throw new Skip('the grant does not let this delegate propose');
    const id = ok(filed, 'ggg_proposal_create(on behalf of the first grantor)');
    try {
      const result = await mine.ggg_proposal_vote({ ...vote(id, 'Yes'), on_behalf_of: [voter.grantor] });
      err(result, ['Forbidden'], 'ggg_proposal_vote(on behalf of the second grantor, on a proposal the delegate filed)');
    } finally {
      await mine.ggg_proposal_withdraw({ proposal: id, on_behalf_of: [filer.grantor] });
    }
    return `filed for ${filer.grantor.toText()}, refused for ${voter.grantor.toText()}`;
  });

  return results;
}
