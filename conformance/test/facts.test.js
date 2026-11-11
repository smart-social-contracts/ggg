import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { generate, KINDS, parseDid } from '../scripts/facts.js';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const committed = JSON.parse(read('facts.json'));
const generated = generate();
const { types, methods } = parseDid(read('ggg.did'));

const WHOLE = 100_000_000;

test('facts.json is what scripts/facts.js generates from ggg.did', () => {
  assert.deepEqual(committed, generated, 'run `npm run facts` and commit facts.json');
});

test('every ggg_ method has an action with its facts, and read operations are marked', () => {
  for (const { name, query } of methods.filter((m) => m.name.startsWith('ggg_'))) {
    const action = committed.actions[name.slice('ggg_'.length)];
    assert.ok(action, `no action for ${name}`);
    assert.equal(action.operation, name);
    assert.equal(action.read ?? false, query, `${name}: read is ${action.read}`);
    assert.equal(typeof action.facts, 'object');
  }
});

test('a per-list action names its operation and the list it ranges over, and its facts are the element\'s fields', () => {
  const perList = Object.entries(committed.actions).filter(([id]) => id.includes('.'));
  assert.ok(perList.length > 0, 'no per-list actions');
  for (const [id, action] of perList) {
    const [operation, list] = id.split('.');
    assert.equal(action.operation, `ggg_${operation}`);
    assert.equal(action.list.field, list);
    assert.equal(committed.actions[operation].lists[list], id, `${operation} does not name ${id} among its lists`);
    assert.ok(Object.keys(action.facts).length > 0, `${id} has no facts`);
  }
  assert.ok(committed.actions['tax_policy_propose.taxes'], 'a forbid on tax_policy_propose ranges over the saved policy\'s taxes');
  assert.ok(committed.actions['tax_policy_draft.taxes'], 'the same forbids run when a draft is saved');
  assert.deepEqual(committed.actions['tax_policy_propose.taxes'].facts, committed.actions['tax_policy_draft.taxes'].facts);
});

test('every kind is declared by named aliases of ggg.did, with the ratio scale and the Period units', () => {
  const { kinds, actions } = committed;
  assert.deepEqual(Object.keys(kinds).sort(), Object.keys(KINDS).sort());
  for (const [kind, { aliases }] of Object.entries(kinds)) {
    for (const alias of aliases) assert.ok(types.has(alias), `${kind}: ggg.did has no type ${alias}`);
  }
  const quorum = actions.department_set_policy.facts.policy.fields.quorum;
  assert.deepEqual([quorum.kind, quorum.min, quorum.max], ['ratio', 0, WHOLE]);
  const rate = actions['tax_policy_draft.taxes'].facts.rate;
  assert.deepEqual([rate.kind, rate.min, rate.max, rate.optional], ['ratio', 0, 100 * WHOLE, true]);
  const amount = actions.invoice_create.facts.amount;
  assert.deepEqual([amount.kind, amount.type, amount.min, amount.max], ['money', 'nat', 0, 9_007_199_254_740_991]);
  const line = actions['invoice_create.items'].facts.amount;
  assert.deepEqual([line.kind, line.type, line.min, line.max], ['money', 'int', -9_007_199_254_740_991, 9_007_199_254_740_991]);
  const deadline = actions.procedure_define.facts.decision_deadline;
  assert.deepEqual([deadline.kind, deadline.optional, deadline.fields.count.min, deadline.fields.count.max], ['period', true, 0, 1_000_000]);
  assert.deepEqual(deadline.fields.unit.values, ['Day', 'WorkingDay', 'Month', 'Year']);
  assert.deepEqual(kinds.period.candid, ['record { count : nat; unit : PeriodUnit }']);
  assert.deepEqual(types.get('PeriodUnit').variant.map((unit) => unit.name), ['Day', 'WorkingDay', 'Month', 'Year']);
});

test('a reserved value is one a text argument never takes', () => {
  for (const operation of ['transfer_create', 'budget_draft']) {
    const { category } = committed.actions[operation].facts;
    assert.equal(category.type, 'text');
    assert.deepEqual(category.reserved, ['ledger_fee']);
  }
  const reserved = Object.values(committed.actions).flatMap((a) => Object.values(a.facts)).filter((f) => f.reserved);
  assert.equal(reserved.length, 2, 'reserved values are few and declared one by one');
});

test('a derived fact says what the GOS computes it from, and never shadows an argument', () => {
  const { published_in } = committed.actions.tender_award.facts;
  assert.equal(published_in.type, 'vec');
  assert.match(published_in.derived, /notices/);
  for (const total of ['revenue', 'expense']) {
    const fact = committed.actions.budget_propose.facts[total];
    assert.equal(fact.kind, 'money');
    assert.match(fact.derived, /sum/);
  }
  for (const operation of ['transfer_create', 'quarter_report']) {
    const fact = committed.actions[operation].facts.follower_compliance;
    assert.deepEqual(fact.values, ['Compliant', 'NonCompliant', 'Unknown']);
    assert.match(fact.derived, /compliance/);
  }
  const derived = Object.values(committed.actions).flatMap((a) => Object.values(a.facts)).filter((f) => f.derived);
  assert.equal(derived.length, 6, 'derived facts are few and declared one by one');
  const did = read('ggg.did').replace('type TenderAwardArgs = record { tender : text;', 'type TenderAwardArgs = record { tender : text; published_in : text;');
  assert.throws(() => generate(did), /published_in collides with an argument/);
});

test('every fact has a finite range, where it is a number', () => {
  const unbounded = [];
  const visit = (fact, where) => {
    if (['nat', 'nat8', 'nat32', 'nat64', 'int'].includes(fact.type) && (fact.min === undefined || fact.max === undefined)) unbounded.push(where);
    for (const [name, field] of Object.entries(fact.fields ?? {})) visit(field, `${where}.${name}`);
    if (fact.element) visit(fact.element, `${where}[]`);
    for (const [name, payload] of Object.entries(fact.cases ?? {})) visit(payload, `${where}.${name}`);
  };
  for (const [id, action] of Object.entries(committed.actions)) {
    for (const [name, fact] of Object.entries(action.facts)) visit(fact, `${id}.${name}`);
  }
  assert.deepEqual(unbounded, []);
});

test('a fact\'s unit is in its schema entry, never in its name', () => {
  const names = [];
  const visit = (facts, where) => {
    for (const [name, fact] of Object.entries(facts)) {
      names.push(`${where}.${name}`);
      if (fact.fields) visit(fact.fields, `${where}.${name}`);
    }
  };
  for (const [id, action] of Object.entries(committed.actions)) visit(action.facts, id);
  const suffixed = names.filter((n) => /_(bp|pct|ppm|cents|ns|ms|days|months|years)$/.test(n));
  assert.deepEqual(suffixed, [], 'a fact name carries a unit suffix');
});

test('the kinds table in docs/layered-codex.md is the kinds of facts.json', () => {
  const page = read('docs/layered-codex.md');
  const section = page.slice(page.indexOf('### 3.3'), page.indexOf('## 4.'));
  const code = (names) => names.map((n) => `\`${n}\``).join(', ');
  const rows = [...section.matchAll(/^\| `(\w+)` \| (.+?) \| (.+?) \| (.+?) \| (.+?) \|$/gm)].map(
    ([, kind, aliases, candid, unit, range]) => ({ kind, aliases, candid, unit, range }),
  );
  assert.deepEqual(
    rows,
    Object.entries(committed.kinds).map(([kind, k]) => ({ kind, aliases: code(k.aliases), candid: code(k.candid), unit: k.unit, range: k.range })),
  );
});
