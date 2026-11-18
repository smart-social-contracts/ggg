// The writing rules of model/ontology.md §10, as far as a test can check them.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readdirSync, readFileSync } from 'node:fs';
import { MODEL_PAGES } from './readme.js';

const ROOT = new URL('../../', import.meta.url);
const SKIP = new Set(['.git', 'node_modules']);
const LIMIT = 1000;

/** Every markdown page in the repository, by its path from the root. */
function pages(dir = '') {
  const found = [];
  for (const entry of readdirSync(new URL(dir, ROOT), { withFileTypes: true })) {
    if (SKIP.has(entry.name)) continue;
    const path = dir + entry.name;
    if (entry.isDirectory()) found.push(...pages(`${path}/`));
    else if (entry.name.endsWith('.md')) found.push(path);
  }
  return found;
}

test('no page is longer than 1000 lines', () => {
  const tooLong = pages()
    .map((path) => [path, readFileSync(new URL(path, ROOT), 'utf8').split('\n').length])
    .filter(([, lines]) => lines > LIMIT)
    .map(([path, lines]) => `${path} (${lines} lines)`);
  assert.deepEqual(tooLong, [], 'split the page by subject (ontology §10)');
});

// A model page the static tests do not read is a page whose operation tables nothing checks.
test('the static tests read every page of the model', () => {
  const standalone = ['model/ontology.md', 'model/codex.md'];
  const found = pages().filter((p) => p.startsWith('model/') && !standalone.includes(p));
  assert.deepEqual(found.sort(), [...MODEL_PAGES].sort(), 'add the new page to MODEL_PAGES in readme.js');
});
