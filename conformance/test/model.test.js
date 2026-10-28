import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { IDL } from '@icp-sdk/core/candid';
import { idlFactory } from '../idl/ggg.js';
import { PUBLIC_UPDATES, updateTable } from '../src/suite.js';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = read('model/README.md');
const did = read('ggg.did');

/** The rows of the model's tables under a "### <heading>", by their first cell. */
function rows(heading) {
  const found = [];
  let inside = false;
  for (const line of model.split('\n')) {
    if (line.startsWith('#')) inside = line === `### ${heading}`;
    else if (inside && line.startsWith('| `')) found.push(line.split(' | '));
  }
  return found;
}

function withoutParentheses(text) {
  let previous;
  do {
    previous = text;
    text = text.replace(/\([^()]*\)/g, '');
  } while (text !== previous);
  return text;
}

const names = (cell) => [...cell.matchAll(/`([^`]+)`/g)].map((m) => m[1]);

const entities = new Map(
  rows('Entities').filter(([first]) => /^\| `[A-Z]/.test(first)).map(([first, fields]) => [
    names(first)[0],
    names(withoutParentheses(fields).replace(/→ `\w+`\*?/g, '')).sort(),
  ]),
);

const records = new Map(
  [...did.matchAll(/^type (\w+) = record \{([^]*?)\};/gm)].map(([, name, body]) => [
    name,
    [...body.matchAll(/"?(\w+)"?\s*:/g)].map((m) => m[1]).sort(),
  ]),
);

const operations = new Set(rows('Operations').flatMap(([first]) => names(withoutParentheses(first).replace(/^\| /, ''))));

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
    .flatMap((r) => names(withoutParentheses(r[0].slice(2))))
    .map((op) => `ggg_${op}`)
    .filter((m) => did.includes(`  ${m} :`));
  assert.deepEqual([...PUBLIC_UPDATES].sort(), pub.sort());
});

/** The bound operations whose Flags cell includes `flag`. */
function flagged(flag) {
  return rows('Operations')
    .filter((r) => r[2]?.split(', ').includes(flag))
    .flatMap((r) => names(withoutParentheses(r[0].slice(2))))
    .filter((op) => did.includes(`  ggg_${op} :`));
}

test('governed operations, and only they, reply Governed', () => {
  const replies = [...did.matchAll(/^  ggg_(\w+) : .* -> \(variant \{ Ok : Governed;/gm)].map((m) => m[1]);
  assert.deepEqual(replies.sort(), [...new Set(flagged('governed'))].sort());
});

test('delegable operations, and only they, take on_behalf_of', () => {
  const service = idlFactory({ IDL });
  const taking = service._fields
    .filter(([, fn]) => fn.argTypes.length && fn.argTypes[0] instanceof IDL.RecordClass && fn.argTypes[0]._fields.some(([k]) => k === 'on_behalf_of'))
    .map(([name]) => name.replace(/^ggg_/, ''));
  assert.deepEqual(taking.sort(), [...new Set(flagged('delegable'))].sort());
});
