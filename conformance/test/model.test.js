import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { updateTable } from '../src/suite.js';

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

test('the suite calls every update method of ggg.did anonymously', () => {
  const updates = [...did.matchAll(/^  (ggg_\w+) : .*\);$/gm)].filter((m) => !m[0].endsWith(') query;')).map((m) => m[1]);
  assert.deepEqual(updateTable('x').map(([method]) => method).sort(), updates.sort());
});
