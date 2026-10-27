import { Actor, AnonymousIdentity, HttpAgent } from '@icp-sdk/core/agent';
import { Principal } from '@icp-sdk/core/principal';
import { idlFactory as ggg1Idl } from '../idl/ggg1.js';
import { idlFactory as ggg2Idl } from '../idl/ggg2.js';

const PAGE = 2;
const MAX_PAGES = 50;
const BAD_CURSOR = 'ggg-conformance:not-a-cursor';
const NO_PROPOSAL = 'ggg-conformance-no-such-proposal';
const NO_DEPARTMENT = 'ggg-conformance-no-such-department';
const NO_OPERATION = 'ggg_conformance.no_such_operation';
const OP_NAME = /^[a-z0-9_.]{1,64}$/;
const MODEL_OP_NAME = /^[a-z][a-z0-9_]{0,63}$/;
const PROVIDED_BY = /^(ggg|codex:\S+|extension:\S+|[a-z0-9][a-z0-9_.-]*)$/;

export class Skip extends Error {}

const tag = (variant) => Object.keys(variant)[0];
const opt = (o) => (o.length ? o[0] : null);
const show = (v) =>
  JSON.stringify(v, (_, x) => {
    if (typeof x === 'bigint') return x.toString();
    if (x instanceof Principal) return x.toText();
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

/** Skips when a read is refused for lack of the model permission, which GGG-1 allows. */
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

function checkMember(m) {
  const where = `member ${m.id.toText()}`;
  assert(!m.id.isAnonymous(), `${where}: the anonymous principal is listed as a member`);
  assert(m.profiles.every((p) => p.length > 0), `${where}: a profile name is empty`);
}

function checkSummary(p) {
  assert(p.id.length > 0, 'a proposal has an empty id');
  assert(p.title.length > 0, `proposal ${p.id}: the title is empty`);
}

function checkProposal(p) {
  checkSummary(p);
  if (tag(p.action) === 'Code') {
    const { checksum } = p.action.Code;
    assert(/^sha256:[0-9a-f]{64}$/.test(checksum), `proposal ${p.id}: checksum "${checksum}" is not sha256:<hex>`);
  }
  if (tag(p.action) === 'Operation') {
    assert(p.action.Operation.op.length > 0, `proposal ${p.id}: the operation name is empty`);
  }
  for (const field of ['threshold_bps', 'quorum_bps']) {
    assert(p[field] <= 10_000n, `proposal ${p.id}: ${field} is ${p[field]}, above 10000`);
  }
  const opens = opt(p.opens_at);
  const deadline = opt(p.deadline);
  assert(opens === null || deadline === null || opens <= deadline, `proposal ${p.id}: the deadline is before voting opens`);
  const { yes, no, abstain } = p.tally;
  const eligible = opt(p.tally.eligible);
  assert(eligible === null || yes + no + abstain <= eligible, `proposal ${p.id}: more votes than eligible voters`);
}

function sameSummary(summary, p) {
  assert(p.title === summary.title, `proposal ${p.id}: the title differs between list and get`);
  assert(p.proposer.toText() === summary.proposer.toText(), `proposal ${p.id}: the proposer differs between list and get`);
  assert(show(p.department) === show(summary.department), `proposal ${p.id}: the department differs between list and get`);
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
    return {
      g1: Actor.createActor(ggg1Idl, { agent, canisterId }),
      g2: Actor.createActor(ggg2Idl, { agent, canisterId }),
    };
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

  await check('GGG-1', 'D1', 'icrc10_supported_standards lists ICRC-10 and GGG-1', async () => {
    const list = await anon.g1.icrc10_supported_standards();
    const names = list.map((s) => s.name);
    declared = new Set(names);
    assert(declared.size === names.length, `duplicate names in ${show(names)}`);
    for (const s of list) assert(/^https:\/\/\S+$/.test(s.url), `${s.name} has no https URL: "${s.url}"`);
    assert(declared.has('ICRC-10'), `ICRC-10 is missing from ${show(names)}`);
    assert(declared.has('GGG-1'), `GGG-1 is missing from ${show(names)}`);
    return names.join(', ');
  });

  await check('GGG-1', 'D2', 'icrc10_supported_standards lists ICRC-21 (consent messages)', async () => {
    assert(declared.has('ICRC-21'), 'ICRC-21 is not listed, so wallets cannot show what a member signs');
  }, 'should');

  await check('GGG-1', 'R1', 'ggg1_realm_info describes the realm to anyone', async () => {
    const realm = await anon.g1.ggg1_realm_info();
    assert(realm.name.length > 0, 'name is empty');
    assert(realm.implementation.name.length > 0, 'implementation.name is empty');
    assert(realm.implementation.version.length > 0, 'implementation.version is empty');
    checkUrl(realm.logo_url, 'logo_url');
    checkUrl(realm.background_image_url, 'background_image_url');
    checkUrl(realm.implementation.url, 'implementation.url');
    const currency = opt(realm.accounting_currency);
    assert(currency === null || currency.symbol.length > 0, 'accounting_currency has an empty symbol');
    const count = opt(realm.member_count);
    return `${realm.name}: ${realm.implementation.name} ${realm.implementation.version}, ${tag(realm.status)}` +
      (count === null ? '' : `, ${count} active members`);
  });

  await check('GGG-1', 'M1', 'ggg1_user_get answers a caller about itself', async () => {
    const m = ok(await anon.g1.ggg1_user_get(Principal.anonymous()), 'ggg1_user_get(anonymous, as anonymous)');
    assert(m.length === 0, `the anonymous principal is a member: ${show(m)}`);
    if (!mine) return 'anonymous only';
    const me = member.getPrincipal();
    const found = opt(ok(await mine.g1.ggg1_user_get(me), 'ggg1_user_get(self)'));
    if (found) assert(found.id.toText() === me.toText(), `ggg1_user_get(${me.toText()}) returns ${found.id.toText()}`);
    return found ? `${me.toText()} is ${tag(found.status)}` : `${me.toText()} is not a member`;
  });

  await check('GGG-1', 'M2', 'ggg1_user_list paginates, and each user can be looked up', async () => {
    const walked = await walk((a) => reader.g1.ggg1_user_list(a), (m) => m.id.toText());
    const detail = checkWalk(walked, 'ggg1_user_list');
    for (const m of walked.items) checkMember(m);
    for (const m of walked.items.slice(0, 5)) {
      const found = opt(ok(await reader.g1.ggg1_user_get(m.id), 'ggg1_user_get'));
      assert(found && found.id.toText() === m.id.toText(), `ggg1_user_get(${m.id.toText()}) does not find a listed user`);
      assert(tag(found.status) === tag(m.status), `user ${m.id.toText()}: the status differs between list and get`);
    }
    return detail;
  });

  await check('GGG-1', 'P1', 'ggg1_proposal_list paginates and returns well-formed summaries', async () => {
    const walked = await walk((a) => reader.g1.ggg1_proposal_list({ ...a, status: [] }), (p) => p.id);
    const detail = checkWalk(walked, 'ggg1_proposal_list');
    walked.items.forEach(checkSummary);
    proposals = walked.items;
    return detail;
  });

  await check('GGG-1', 'P2', 'ggg1_proposal_get finds each listed proposal, well-formed', async () => {
    if (!proposals.length) throw new Skip('the realm has no proposals, or they could not be listed');
    for (const s of proposals.slice(0, 5)) {
      const p = opt(ok(await reader.g1.ggg1_proposal_get(s.id), `ggg1_proposal_get(${s.id})`));
      assert(p && p.id === s.id, `ggg1_proposal_get(${s.id}) does not find it`);
      checkProposal(p);
      sameSummary(s, p);
    }
  });

  await check('GGG-1', 'P3', 'ggg1_proposal_get returns Ok(null) for an unknown id', async () => {
    const result = await reader.g1.ggg1_proposal_get(NO_PROPOSAL);
    refused(result.Err, 'ggg1_proposal_get');
    const found = ok(result, 'ggg1_proposal_get(unknown)');
    assert(found.length === 0, `returned ${show(found)}`);
  });

  await check('GGG-1', 'P4', 'ggg1_proposal_list filters by status', async () => {
    const status = proposals.length ? proposals[0].status : { Voting: null };
    const result = await reader.g1.ggg1_proposal_list({ cursor: [], limit: [PAGE], status: [status] });
    refused(result.Err, 'ggg1_proposal_list');
    for (const p of ok(result, 'ggg1_proposal_list(status)').items) {
      assert(tag(p.status) === tag(status), `filter ${tag(status)} returned proposal ${p.id} with ${tag(p.status)}`);
    }
    return `filtered on ${tag(status)}`;
  });

  await check('GGG-1', 'P5', 'a malformed cursor returns InvalidArgument', async () => {
    const result = await reader.g1.ggg1_proposal_list({ cursor: [BAD_CURSOR], limit: [PAGE], status: [] });
    refused(result.Err, 'ggg1_proposal_list');
    err(result, ['InvalidArgument'], 'ggg1_proposal_list(malformed cursor)');
  });

  await check('GGG-1', 'P6', 'proposal ids are at most 64 bytes', async () => {
    const long = proposals.filter((p) => new TextEncoder().encode(p.id).length > 64);
    assert(!long.length, `${long.length} ids are longer, e.g. ${long[0]?.id}`);
  }, 'should');

  await check('GGG-1', 'V1', 'ggg1_proposal_votes paginates, one vote per voter', async () => {
    if (!proposals.length) throw new Skip('the realm has no proposals, or they could not be listed');
    const id = proposals[0].id;
    const walked = await walk((a) => reader.g1.ggg1_proposal_votes({ ...a, proposal_id: id, voter: [] }),
      (v) => v.voter.toText());
    const detail = checkWalk(walked, 'ggg1_proposal_votes');
    for (const v of walked.items) assert(v.proposal_id === id, `a vote listed under ${id} is for ${v.proposal_id}`);
    const voter = walked.items[0]?.voter;
    if (voter) {
      const result = await reader.g1.ggg1_proposal_votes({ proposal_id: id, voter: [voter], cursor: [], limit: [] });
      const only = ok(result, 'ggg1_proposal_votes(voter)').items;
      assert(only.length === 1 && only[0].voter.toText() === voter.toText(),
        `filtering on voter ${voter.toText()} returns ${only.length} votes`);
    }
    return `proposal ${id}: ${detail}`;
  });

  await check('GGG-1', 'V2', 'ggg1_proposal_votes returns NotFound for an unknown proposal', async () => {
    const result = await reader.g1.ggg1_proposal_votes({ proposal_id: NO_PROPOSAL, voter: [], cursor: [], limit: [] });
    refused(result.Err, 'ggg1_proposal_votes');
    err(result, ['NotFound'], 'ggg1_proposal_votes(unknown proposal)');
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
  const vote = (proposal_id, choice) => ({ proposal_id, choice: { [choice]: null }, on_behalf_of: [] });
  const votesOf = async (id) => {
    const args = { proposal_id: id, voter: [member.getPrincipal()], cursor: [], limit: [] };
    return ok(await mine.g1.ggg1_proposal_votes(args), 'ggg1_proposal_votes(self)').items;
  };

  await check('GGG-1', 'W1', 'an anonymous caller cannot file a proposal or vote', async () => {
    needWrites();
    err(await anon.g1.ggg1_proposal_create(motion('anonymous')), ['Unauthenticated'], 'ggg1_proposal_create');
    const id = proposals[0]?.id ?? NO_PROPOSAL;
    err(await anon.g1.ggg1_proposal_vote(vote(id, 'Yes')), ['Unauthenticated'], 'ggg1_proposal_vote');
  });

  let created = null;
  await check('GGG-1', 'W2', 'a member files a realm-wide Motion and can read it back', async () => {
    needMember();
    const title = `GGG conformance check ${new Date().toISOString()}`;
    const result = await mine.g1.ggg1_proposal_create(motion(title));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    const id = ok(result, 'ggg1_proposal_create');
    const p = opt(ok(await mine.g1.ggg1_proposal_get(id), `ggg1_proposal_get(${id})`));
    assert(p, `ggg1_proposal_get(${id}) does not find the new proposal`);
    checkProposal(p);
    assert(p.title === title, `title is "${p.title}"`);
    assert(p.proposer.toText() === member.getPrincipal().toText(), `proposer is ${p.proposer.toText()}`);
    assert(['Draft', 'Voting'].includes(tag(p.status)), `a new proposal is ${tag(p.status)}`);
    assert(tag(p.action) === 'Motion', `action is ${tag(p.action)}`);
    assert(p.department.length === 0, `a realm-wide proposal has department ${show(p.department)}`);
    created = p;
    return `proposal ${id}, ${tag(p.status)}`;
  });

  await check('GGG-1', 'W3', 'a member votes, and a second vote replaces the first', async () => {
    needMember();
    if (!created) throw new Skip('no proposal was filed');
    if (tag(created.status) !== 'Voting') throw new Skip('the new proposal is not open for voting yet');
    const me = member.getPrincipal().toText();
    const result = await mine.g1.ggg1_proposal_vote(vote(created.id, 'Yes'));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not vote');
    const v = ok(result, 'ggg1_proposal_vote');
    assert(v.proposal_id === created.id, `the vote is for ${v.proposal_id}`);
    assert(v.voter.toText() === me, `voter is ${v.voter.toText()}`);
    assert(tag(v.choice) === 'Yes', `choice is ${tag(v.choice)}`);
    const castBy = opt(v.cast_by);
    assert(castBy === null || castBy.toText() === me, `cast_by is ${castBy?.toText()}`);
    const recorded = await votesOf(created.id);
    assert(recorded.length === 1 && tag(recorded[0].choice) === 'Yes', `the recorded votes are ${show(recorded)}`);

    ok(await mine.g1.ggg1_proposal_vote(vote(created.id, 'No')), 'a second ggg1_proposal_vote');
    const changed = await votesOf(created.id);
    assert(changed.length === 1 && tag(changed[0].choice) === 'No', `after voting again, the votes are ${show(changed)}`);
  });

  await check('GGG-1', 'W4', 'the tally counts the vote once', async () => {
    needMember();
    if (!created || tag(created.status) !== 'Voting') throw new Skip('no proposal open for voting was filed');
    const p = opt(ok(await mine.g1.ggg1_proposal_get(created.id), 'ggg1_proposal_get'));
    const { yes, no, abstain } = p.tally;
    assert(yes + no + abstain > 0n, 'the tally is still zero (allowed only with secret ballots)');
    assert(yes === 0n && no === 1n && abstain === 0n, `after Yes then No, the tally is ${show(p.tally)}`);
  }, 'should');

  await check('GGG-1', 'W5', 'a vote on an unknown proposal returns NotFound', async () => {
    needMember();
    const result = await mine.g1.ggg1_proposal_vote(vote(NO_PROPOSAL, 'Yes'));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not vote');
    err(result, ['NotFound'], 'ggg1_proposal_vote(unknown proposal)');
  });

  await check('GGG-1', 'W6', 'a proposal for an unknown department returns NotFound', async () => {
    needMember();
    const result = await mine.g1.ggg1_proposal_create(motion('unknown department', { department: [NO_DEPARTMENT] }));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    err(result, ['NotFound'], 'ggg1_proposal_create(unknown department)');
  });

  await check('GGG-1', 'W7', 'a proposal to run an unknown operation returns InvalidArgument', async () => {
    needMember();
    const action = { Operation: { op: NO_OPERATION, args: { Map: [] } } };
    const result = await mine.g1.ggg1_proposal_create(motion('unknown operation', { action }));
    if ('Err' in result && tag(result.Err) === 'Forbidden') throw new Skip('this member may not propose');
    err(result, ['InvalidArgument'], 'ggg1_proposal_create(unknown operation)');
  });

  const needGgg2 = () => {
    if (!declared.has('GGG-2')) throw new Skip('GGG-2 is not declared');
  };
  let operations = [];

  await check('GGG-2', 'O1', 'ggg2_operations paginates and describes each operation', async () => {
    needGgg2();
    const walked = await walk((a) => reader.g2.ggg2_operations(a), (o) => o.name);
    const detail = checkWalk(walked, 'ggg2_operations');
    for (const o of walked.items) {
      assert(OP_NAME.test(o.name), `operation name "${o.name}" is not [a-z0-9_.], up to 64 bytes`);
      assert(PROVIDED_BY.test(o.provided_by), `${o.name}: provided_by "${o.provided_by}" is not a known form`);
      if (o.provided_by === 'ggg') assert(MODEL_OP_NAME.test(o.name), `${o.name} is not a model operation name`);
      assert(!(o.read && o.governed), `${o.name} is both read and governed`);
      for (const field of ['args_schema', 'result_schema']) {
        const schema = opt(o[field]);
        if (schema === null) continue;
        try {
          JSON.parse(schema);
        } catch {
          throw new Error(`${o.name}: ${field} is not JSON`);
        }
      }
    }
    operations = walked.items;
    return detail;
  });

  await check('GGG-2', 'O2', 'ggg2_operation finds each listed operation, and not an unknown one', async () => {
    needGgg2();
    for (const o of operations.slice(0, 5)) {
      const found = opt(ok(await reader.g2.ggg2_operation(o.name), `ggg2_operation(${o.name})`));
      assert(found && show(found) === show(o), `ggg2_operation(${o.name}) differs from the list`);
    }
    const none = ok(await reader.g2.ggg2_operation(NO_OPERATION), 'ggg2_operation(unknown)');
    assert(none.length === 0, `returned ${show(none)}`);
  });

  const run = (op, extra = {}) => ({ op, args: { Map: [] }, on_behalf_of: [], ...extra });

  await check('GGG-2', 'O3', 'an unknown operation returns Unsupported', async () => {
    needGgg2();
    err(await anon.g2.ggg2_query(run(NO_OPERATION)), ['Unsupported'], 'ggg2_query(unknown)');
    err(await anon.g2.ggg2_call(run(NO_OPERATION)), ['Unsupported'], 'ggg2_call(unknown)');
  });

  await check('GGG-2', 'O4', 'ggg2_query refuses an operation that changes the realm', async () => {
    needGgg2();
    const write = operations.find((o) => !o.read);
    if (!write) throw new Skip('every listed operation is a read');
    err(await anon.g2.ggg2_query(run(write.name)), ['InvalidArgument'], `ggg2_query(${write.name})`);
    return write.name;
  });

  await check('GGG-2', 'O5', 'on_behalf_of on an operation that is not delegable returns InvalidArgument', async () => {
    needGgg2();
    const read = operations.find((o) => o.read && !o.delegable);
    if (!read) throw new Skip('no read operation that is not delegable is listed');
    const args = run(read.name, { on_behalf_of: [Principal.anonymous()] });
    err(await anon.g2.ggg2_query(args), ['InvalidArgument'], `ggg2_query(${read.name}, on_behalf_of)`);
    return read.name;
  });

  await check('GGG-2', 'O6', 'a malformed cursor returns InvalidArgument', async () => {
    needGgg2();
    const result = await reader.g2.ggg2_operations({ cursor: [BAD_CURSOR], limit: [PAGE] });
    refused(result.Err, 'ggg2_operations');
    err(result, ['InvalidArgument'], 'ggg2_operations(malformed cursor)');
  });

  await check('GGG-2', 'O7', 'operations that are not in the model have a prefix', async () => {
    needGgg2();
    const bare = operations.filter((o) => o.provided_by !== 'ggg' && !o.name.includes('.'));
    assert(!bare.length, `${bare.map((o) => o.name).join(', ')} could clash with a model operation`);
  }, 'should');

  return results;
}
