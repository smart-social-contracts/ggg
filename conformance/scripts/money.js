// The money rule (layered codex §3.3, model §5 and D23) as code, so a GOS can check its arithmetic
// against it: money computed from ratios is the exact result rounded once, an exact half away from
// zero, to the token's smallest unit. Amounts are BigInt in the token's smallest unit; ratios are in
// hundred-millionths (100 % is 100 000 000).

export const WHOLE = 100_000_000n;

/** `numerator / denominator` rounded to the nearest integer, an exact half away from zero. */
export function roundHalfAwayFromZero(numerator, denominator) {
  if (denominator < 0n) return roundHalfAwayFromZero(-numerator, -denominator);
  const sign = numerator < 0n ? -1n : 1n;
  const magnitude = numerator < 0n ? -numerator : numerator;
  return sign * ((2n * magnitude + denominator) / (2n * denominator));
}

/** `amount` at `rate`: one product, rounded once. */
export function share(amount, rate) {
  return roundHalfAwayFromZero(amount * rate, WHOLE);
}

/**
 * A progressive tax on `base`: each bracket `{ upTo, rate }` taxes the part of the base between the
 * previous bracket's `upTo` and its own (`null` for the last, open bracket) at its rate. The brackets'
 * exact shares are summed, and the total is rounded once. Rounding each bracket's share instead would
 * move the total by up to a unit per bracket.
 */
export function progressiveTax(base, brackets) {
  let numerator = 0n;
  let from = 0n;
  for (const { upTo, rate } of brackets) {
    const to = upTo === null || upTo > base ? base : upTo;
    if (to > from) numerator += (to - from) * rate;
    from = to;
    if (from >= base) break;
  }
  return roundHalfAwayFromZero(numerator, WHOLE);
}
