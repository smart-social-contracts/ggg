// The money rule as the model states it (§5, D23; layered codex §3.3): one rounding, an exact half
// away from zero, and a progressive tax rounded once over all its brackets.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { progressiveTax, roundHalfAwayFromZero, share } from '../scripts/money.js';

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
  // Amounts in cents: a base of 150.08 under 10 % up to 100.05 and 20 % above.
  const brackets = [{ upTo: 10_005n, rate: percent(10) }, { upTo: null, rate: percent(20) }];
  assert.equal(progressiveTax(15_008n, brackets), 2_001n); // 10.005 + 10.006 = 20.011, rounded once: 20.01
  assert.equal(share(10_005n, percent(10)) + share(5_003n, percent(20)), 2_002n); // bracket by bracket: 20.02
  // A base inside the first bracket pays that bracket's rate alone; one above the last pays every bracket.
  assert.equal(progressiveTax(5_000n, brackets), 500n);
  assert.equal(progressiveTax(20_000n, brackets), 3_000n); // 1 000.5 + 1 999 = 2 999.5, rounded once: 3 000
});
