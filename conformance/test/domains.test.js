import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const { version, domains } = JSON.parse(read('domains.json'));

const STARTING = ['realm', 'tax', 'procedure', 'register', 'local_regime', 'water', 'data_protection', 'language', 'treasury', 'federation'];

test('the domain list is versioned with a whole number', () => {
  assert.ok(Number.isInteger(version) && version >= 1, `version is ${version}`);
});

test('the domain list starts with the agreed domains', () => {
  assert.deepEqual(domains.slice(0, STARTING.length).map((d) => d.id), STARTING);
});

test('a domain id is lowercase letters and underscores, and appears once', () => {
  const ids = domains.map((d) => d.id);
  for (const id of ids) assert.match(id, /^[a-z][a-z_]*$/, `"${id}" is not a valid domain id`);
  assert.equal(new Set(ids).size, ids.length, 'a domain id appears twice');
});

test('a domain has a one-line description, in the model\'s words', () => {
  for (const { id, description } of domains) {
    assert.ok(description.length > 0 && !description.includes('\n'), `${id}: the description is not one line`);
    assert.doesNotMatch(description, /\blaws?\b/i, `${id}: say "legislation", not "law"`);
  }
});

test('the table in docs/layered-codex.md is the list in domains.json', () => {
  const page = read('docs/layered-codex.md');
  const section = page.slice(page.indexOf('## 2. The domain list'), page.indexOf('## 3.'));
  const rows = [...section.matchAll(/^\| `(\w+)` \| (.+) \|$/gm)].map(([, id, description]) => ({ id, description }));
  assert.deepEqual(rows, domains);
});
