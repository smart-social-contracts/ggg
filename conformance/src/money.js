// The money rule (layered codex §3.3, model §5 and D23) as code, so a GOS can check its arithmetic
// against it: one amount computed from ratios is the exact result rounded once, an exact half away from
// zero, to the nearest cent, a multiple of 10^(decimals − 2) smallest units. Amounts are BigInt in the
// token's smallest unit; ratios are in hundred-millionths (100 % is 100 000 000).

export const WHOLE = 100_000_000n;

/** `numerator / denominator` rounded to the nearest integer, an exact half away from zero. */
export function roundHalfAwayFromZero(numerator, denominator) {
  if (denominator < 0n) return roundHalfAwayFromZero(-numerator, -denominator);
  const sign = numerator < 0n ? -1n : 1n;
  const magnitude = numerator < 0n ? -numerator : numerator;
  return sign * ((2n * magnitude + denominator) / (2n * denominator));
}

/** A cent in a token's smallest units: 10^(decimals − 2), or one unit for a token with fewer decimals. */
export function cent(decimals) {
  return 10n ** BigInt(Math.max(decimals - 2, 0));
}

/** `numerator / denominator` in smallest units, rounded once to the nearest cent. */
function toCents(numerator, denominator, decimals) {
  const unit = cent(decimals);
  return roundHalfAwayFromZero(numerator, denominator * unit) * unit;
}

/** `amount` at `rate`: one product, rounded once. */
export function share(amount, rate, decimals) {
  return toCents(amount * rate, WHOLE, decimals);
}

/**
 * A progressive tax on `base`: each bracket `{ upTo, rate }` taxes the part of the base between the
 * previous bracket's `upTo` and its own at its rate; the bounds increase, and the last bracket is open
 * (`upTo` null). The brackets' exact shares are summed, and the total is rounded once. Rounding each
 * bracket's share instead would move the total by up to half a cent per bracket.
 */
export function progressiveTax(base, brackets, decimals) {
  if (brackets.length === 0) throw new Error('a progressive tax has at least one bracket');
  let bound = 0n;
  brackets.forEach(({ upTo }, i) => {
    const last = i === brackets.length - 1;
    if (last && upTo != null) throw new Error('brackets have increasing bounds, and the last is open');
    if (!last && (upTo == null || upTo <= bound)) throw new Error('brackets have increasing bounds, and the last is open');
    if (upTo != null) bound = upTo;
  });
  let numerator = 0n;
  let from = 0n;
  for (const { upTo, rate } of brackets) {
    const to = upTo == null || upTo > base ? base : upTo;
    if (to > from) numerator += (to - from) * rate;
    from = to;
  }
  return toCents(numerator, WHOLE, decimals);
}
