import assert from 'node:assert/strict';
import { test } from 'node:test';
import { did, flagged, read } from './readme.js';

const text = read('delegation.json');
const { tiers, groups, everything, conditions, operations } = JSON.parse(text);

const methods = [...did.matchAll(/^\s+ggg_(\w+)\s*:(.*)$/gm)].map((m) => ({ name: m[1], read: m[2].trimEnd().endsWith('query;') }));
const groupIds = groups.map((g) => g.id);

const TIERS = ['direct', 'confirm', 'member', 'founder', 'none'];
const GROUPS = ['see', 'profile', 'vote', 'propose', 'filings', 'justice', 'money', 'payout', 'identity', 'keys', 'poa', 'membership', 'office', 'sign', 'orgs', 'admin', 'setup'];
const DAY = 24 * 3600;
const YEAR = 365 * DAY;
// Calls between canisters: never a member's act.
const BETWEEN_CANISTERS = ['quarter_sync', 'quarter_report', 'federation_message', 'link_notify', 'follower_report'];

const oneSentence = (sentence, where) => assert.ok(typeof sentence === 'string' && sentence.length > 0 && !sentence.includes('\n'), `${where} is not one sentence`);

test('delegation.json lists every method of ggg.did exactly once, and nothing else', () => {
  const names = methods.map((m) => m.name);
  assert.deepEqual(Object.keys(operations).sort(), [...names].sort());
  for (const name of names) {
    const occurrences = text.match(new RegExp(`^\\s*"${name}": \\{`, 'gm')) ?? [];
    assert.equal(occurrences.length, 1, `${name} appears ${occurrences.length} times`);
  }
});

test('every operation names a known tier, a group when it has one, and a known condition', () => {
  assert.deepEqual(Object.keys(tiers).sort(), [...TIERS].sort());
  for (const [id, sentence] of Object.entries(tiers)) oneSentence(sentence, `tiers.${id}`);
  for (const [id, sentence] of Object.entries(conditions)) oneSentence(sentence, `conditions.${id}`);
  for (const [name, op] of Object.entries(operations)) {
    assert.ok(TIERS.includes(op.tier), `${name}: unknown tier ${op.tier}`);
    if (['direct', 'confirm'].includes(op.tier)) assert.ok(groupIds.includes(op.group), `${name}: unknown group ${op.group}`);
    else assert.equal(op.group, undefined, `${name}: a ${op.tier} operation belongs to no group`);
    if (op.confirm_if !== undefined) {
      assert.equal(op.tier, 'direct', `${name}: only a direct operation asks on a condition`);
      assert.ok(conditions[op.confirm_if], `${name}: unknown condition ${op.confirm_if}`);
    }
    if (op.after_launch !== undefined) {
      assert.equal(op.group, 'setup', `${name}: only a setup operation moves to another group at launch`);
      assert.ok(groupIds.includes(op.after_launch), `${name}: unknown group ${op.after_launch}`);
    }
    const unknown = Object.keys(op).filter((key) => !['tier', 'group', 'confirm_if', 'after_launch'].includes(key));
    assert.deepEqual(unknown, [], `${name}: unknown keys`);
  }
  const used = new Set(Object.values(operations).map((op) => op.confirm_if).filter(Boolean));
  assert.deepEqual([...used].sort(), Object.keys(conditions).sort(), 'every condition is used, and only known ones');
});

test('the groups are the design\'s, each with its texts, parameter and longest duration', () => {
  assert.deepEqual(groupIds, GROUPS);
  for (const group of groups) {
    for (const field of ['label', 'summary', 'risk']) oneSentence(group[field], `${group.id}.${field}`);
    const longest = { money: 90 * DAY, admin: 90 * DAY, setup: 30 * DAY }[group.id] ?? YEAR;
    assert.equal(group.longest, longest, `${group.id}.longest`);
    assert.equal(group.parameter, { office: 'department', orgs: 'organization' }[group.id], `${group.id}.parameter`);
    assert.ok(Object.values(operations).some((op) => op.group === group.id), `${group.id} holds no operation`);
  }
  assert.equal(everything.scope, 'group:*');
  assert.equal(everything.longest, 90 * DAY);
  assert.deepEqual(everything.never, ['member', 'founder']);
  oneSentence(everything.summary, 'everything.summary');
  oneSentence(everything.warning, 'everything.warning');
});

test('signing acts ask each time in the sign group, Launch is the founder\'s, reads never ask, canisters hold no power of attorney', () => {
  const signing = new Set(flagged('signing'));
  assert.ok(signing.size > 0, 'no signing operation found in the model');
  for (const name of signing) assert.deepEqual([operations[name].tier, operations[name].group], ['confirm', 'sign'], name);
  for (const [name, op] of Object.entries(operations)) if (op.group === 'sign') assert.ok(signing.has(name), `${name} is in the sign group but is not a signing act`);
  assert.equal(operations.setup_launch.tier, 'founder');
  for (const { name, read: isRead } of methods) if (isRead) assert.notEqual(operations[name].tier, 'confirm', `${name} is a read`);
  for (const name of BETWEEN_CANISTERS) assert.equal(operations[name].tier, 'none', name);
});

test('the model\'s flags agree with delegation.json: delegable is the direct tier, confirm the confirm tier', () => {
  const delegable = new Set(flagged('delegable'));
  const confirm = new Set(flagged('confirm'));
  for (const { name } of methods) {
    const { tier } = operations[name];
    assert.equal(delegable.has(name), tier === 'direct', `${name}: the delegable flag does not match tier ${tier}`);
    assert.equal(confirm.has(name), tier === 'confirm', `${name}: the confirm flag does not match tier ${tier}`);
  }
});
