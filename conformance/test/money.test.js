// The money rule as the model states it (§5, D23; layered codex §3.3): one rounding, an exact half
// away from zero, to the nearest cent of the token, and a progressive tax rounded once over all its brackets.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cent, progressiveTax, roundHalfAwayFromZero, share } from '../src/money.js';

const percent = (n) => BigInt(Math.round(n * 1_000_000));

test('an exact half rounds away from zero, in both directions', () => {
  assert.equal(roundHalfAwayFromZero(2345n, 1000n), 2n); // 2.345 to the unit: 2
  assert.equal(roundHalfAwayFromZero(2345n, 10n), 235n); // 2.345 to the cent: 2.35
  assert.equal(roundHalfAwayFromZero(-2345n, 10n), -235n); // and −2.345 to −2.35
  assert.equal(roundHalfAwayFromZero(25n, 10n), 3n);
  assert.equal(roundHalfAwayFromZero(-25n, 10n), -3n);
  assert.equal(roundHalfAwayFromZero(24n, 10n), 2n);
});

test("the model's example: a progressive tax is the exact total rounded once, not the rounded brackets summed", () => {
  // Amounts in cents (a token with two decimals): a base of 150.08 under 10 % up to 100.05 and 20 % above.
  const brackets = [{ upTo: 10_005n, rate: percent(10) }, { upTo: null, rate: percent(20) }];
  assert.equal(progressiveTax(15_008n, brackets, 2), 2_001n); // 10.005 + 10.006 = 20.011, rounded once: 20.01
  assert.equal(share(10_005n, percent(10), 2) + share(5_003n, percent(20), 2), 2_002n); // bracket by bracket: 20.02
  // A base inside the first bracket pays that bracket's rate alone; one above the last pays every bracket.
  assert.equal(progressiveTax(5_000n, brackets, 2), 500n);
  assert.equal(progressiveTax(20_000n, brackets, 2), 3_000n); // 1 000.5 + 1 999 = 2 999.5, rounded once: 3 000
  // The bounds increase and the last bracket is open.
  assert.throws(() => progressiveTax(1n, [{ upTo: 10n, rate: 1n }, { upTo: 5n, rate: 1n }, { upTo: null, rate: 1n }]));
  assert.throws(() => progressiveTax(1n, [{ upTo: 10n, rate: 1n }]));
});

test('a token with eight decimals rounds to its cent, a million smallest units', () => {
  assert.equal(cent(8), 1_000_000n);
  assert.equal(cent(2), 1n);
  assert.equal(cent(0), 1n);
  // A base of 1 000.5 under 2 % up to 1 000 and 3 % above: 20 + 0.015 = 20.015, rounded once: 20.02.
  const unit = 100_000_000n; // one token
  const brackets = [{ upTo: 1_000n * unit, rate: percent(2) }, { upTo: null, rate: percent(3) }];
  assert.equal(progressiveTax(1_000n * unit + unit / 2n, brackets, 8), 2_002_000_000n);
});
