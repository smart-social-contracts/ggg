// The operation tables of model/README.md, as the static tests read them.
import { readFileSync } from 'node:fs';

export const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
export const model = read('model/README.md');
export const did = read('ggg.did');

/** The rows of the model's tables under a "### <heading>", by their first cell. */
export function rows(heading) {
  const found = [];
  let inside = false;
  for (const line of model.split('\n')) {
    if (line.startsWith('#')) inside = line === `### ${heading}`;
    else if (inside && line.startsWith('| `')) found.push(line.split(' | '));
  }
  return found;
}

export function withoutParentheses(text) {
  let previous;
  do {
    previous = text;
    text = text.replace(/\([^()]*\)/g, '');
  } while (text !== previous);
  return text;
}

export const names = (cell) => [...cell.matchAll(/`([^`]+)`/g)].map((m) => m[1]);

/** The operations a row of an Operations table names in its first cell. */
export const rowOperations = (row) => names(withoutParentheses(row[0].slice(2)));

/** The bound operations whose Flags cell includes `flag`. */
export function flagged(flag) {
  return rows('Operations')
    .filter((r) => r[2]?.split(', ').includes(flag))
    .flatMap(rowOperations)
    .filter((op) => did.includes(`  ggg_${op} :`));
}
