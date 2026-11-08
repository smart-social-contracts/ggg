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

test('every kind is declared by a named alias of ggg.did, with the ratio scale and the Period units', () => {
  const { kinds } = committed;
  assert.deepEqual(Object.keys(kinds).sort(), [...new Set(Object.values(KINDS).map((k) => k.kind))].sort());
  for (const [kind, { alias }] of Object.entries(kinds)) assert.ok(types.has(alias), `${kind}: ggg.did has no type ${alias}`);
  assert.equal(kinds.ratio.min, 0);
  assert.equal(kinds.ratio.max, WHOLE);
  assert.equal(kinds.money.min, 0);
  assert.equal(kinds.period.candid, 'record { count : nat; unit : PeriodUnit }');
  assert.deepEqual(types.get('PeriodUnit').variant.map((unit) => unit.name), ['Day', 'WorkingDay', 'Month', 'Year']);
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
  const rows = [...section.matchAll(/^\| `(\w+)` \| `(\w+)` \| (.+?) \|/gm)].map(([, kind, alias, candid]) => ({ kind, alias, candid }));
  assert.deepEqual(
    rows,
    Object.entries(committed.kinds).map(([kind, k]) => ({ kind, alias: k.alias, candid: `\`${k.candid}\`` })),
  );
});
