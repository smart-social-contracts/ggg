import assert from 'node:assert/strict';
import { test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { idlFactory } from '../idl/ggg.js';
import { PUBLIC_UPDATES, isTimezoneName, looksLikeBasisPoints, updateTable } from '../src/suite.js';
import { did, flagged, names, read, rowOperations, rows, withoutParentheses } from './readme.js';

const entities = new Map(
  rows('Entities').filter(([first]) => /^\| `[A-Z]/.test(first)).map(([first, fields]) => [
    names(first)[0],
    names(withoutParentheses(fields).replace(/→ `\w+`\*?/g, '')).sort(),
  ]),
);

const records = new Map(
  [...did.matchAll(/^type (\w+) = record \{([^]*?)\};/gm)].map(([, name, body]) => [
    name,
    // Comments inside the record may hold a colon, so they go first.
    [...body.replace(/\/\/[^\n]*/g, '').matchAll(/"?(\w+)"?\s*:/g)].map((m) => m[1]).sort(),
  ]),
);

const operations = new Set(rows('Operations').flatMap(rowOperations));

const methods = [...did.matchAll(/^\s+(ggg_\w+)\s*:/gm)].map((m) => m[1]);

test('the model lists its entities', () => {
  assert.ok(entities.size > 50, `only ${entities.size} entities parsed`);
});

test('ggg.did has a record for every entity, with the model fields', () => {
  for (const [entity, fields] of entities) {
    assert.ok(records.has(entity), `ggg.did has no record ${entity}`);
    assert.deepEqual(records.get(entity), fields, `${entity}: ggg.did fields differ from the model`);
  }
});

test('every ggg_ method binds a model operation', () => {
  assert.ok(methods.length > 0, 'no ggg_ methods parsed');
  for (const method of methods) {
    const op = method.slice('ggg_'.length);
    assert.ok(operations.has(op), `${method}: the model has no operation ${op}`);
  }
});

test('the JavaScript binding has every update method of ggg.did', () => {
  const updates = [...did.matchAll(/^  (ggg_\w+) : .*\);$/gm)].filter((m) => !m[0].endsWith(') query;')).map((m) => m[1]);
  assert.deepEqual(updateTable().map(([method]) => method).sort(), updates.sort());
});

test('the updates the anonymous check skips are the public ones in the model', () => {
  const pub = rows('Operations')
    .filter((r) => r[1].includes('(public)') && !r[2].includes('read'))
    .flatMap(rowOperations)
    .map((op) => `ggg_${op}`)
    .filter((m) => did.includes(`  ${m} :`));
  assert.deepEqual([...PUBLIC_UPDATES].sort(), pub.sort());
});

test('governed operations, and only they, reply Governed', () => {
  const replies = [...did.matchAll(/^  ggg_(\w+) : .* -> \(variant \{ Ok : Governed;/gm)].map((m) => m[1]);
  assert.deepEqual(replies.sort(), [...new Set(flagged('governed'))].sort());
});

test('an operation that takes on_behalf_of is delegable, or the member\'s own and refuses it', () => {
  const { operations: tiers } = JSON.parse(read('delegation.json'));
  const service = idlFactory({ IDL });
  const taking = service._fields
    .filter(([, fn]) => fn.argTypes.length && fn.argTypes[0] instanceof IDL.RecordClass && fn.argTypes[0]._fields.some(([k]) => k === 'on_behalf_of'))
    .map(([name]) => name.replace(/^ggg_/, ''));
  const delegable = new Set(flagged('delegable'));
  for (const op of taking) {
    const { tier } = tiers[op];
    assert.ok(tier === 'member' || delegable.has(op), `${op} takes on_behalf_of but is ${tier} and not delegable`);
  }
  // Every member-only operation carries the field, so that its refusal can be checked over Candid.
  const memberOnly = Object.entries(tiers).filter(([, op]) => op.tier === 'member').map(([name]) => name);
  assert.deepEqual(memberOnly.filter((op) => !taking.includes(op)), []);
  assert.ok(memberOnly.includes('delegation_revoke_all'));
});

test('a time zone name is Area/Location or UTC', () => {
  const valid = ['Europe/Madrid', 'America/Argentina/Buenos_Aires', 'America/Port-au-Prince', 'Etc/GMT+5', 'UTC'];
  const invalid = ['', 'CET', 'Madrid', 'europe/madrid', '+01:00', 'Europe/', 'Europe/Madrid/', 'Mars/Olympus', 'Europe/Mad rid'];
  for (const name of valid) assert.ok(isTimezoneName(name), `${name} is valid`);
  for (const name of invalid) assert.ok(!isTimezoneName(name), `"${name}" is not valid`);
});

test('a nonzero ratio under 1 % looks like an unconverted basis-point value', () => {
  for (const ratio of [1n, 5_000n, 999_999n]) assert.ok(looksLikeBasisPoints(ratio), `${ratio} looks like basis points`);
  for (const ratio of [0n, 1_000_000n, 50_000_000n, 100_000_000n]) assert.ok(!looksLikeBasisPoints(ratio), `${ratio} is a ratio`);
});
