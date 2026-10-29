// Constant-time comparison for shared secrets (no early exit on the first
// differing byte, so response timing doesn't leak how much matched).
export function secretsMatch(given: string | null, expected: string): boolean {
  if (given === null || expected.length === 0) return false;
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}
