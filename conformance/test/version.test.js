import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const declared = read('version.txt').trim();

test('version.txt holds one semantic version', () => {
  assert.match(declared, /^\d+\.\d+\.\d+(-[0-9a-z.]+)?$/, `"${declared}" is not a semantic version`);
});

test('the conformance suite carries the GGG version, not one of its own', () => {
  const pkg = JSON.parse(read('conformance/package.json'));
  assert.equal(pkg.version, declared, 'conformance/package.json and version.txt disagree');
});
