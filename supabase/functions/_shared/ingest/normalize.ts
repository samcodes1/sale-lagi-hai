// Validation and de-duplication for scraped deals. Everything a site sends
// is untrusted: lengths, links and numbers are checked here, and again by
// the database's constraints.
import type { NormalizedDeal, ScrapedDeal, Source } from './types.ts';

/** sha256 of the source and the deal's stable id: the same deal on the next
 * run gets the same fingerprint, so it updates instead of duplicating. */
export async function fingerprint(sourceSlug: string, externalId: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`${sourceSlug}\u0000${externalId.trim().toLowerCase()}`),
  );
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const collapse = (s: string) => s.replace(/\s+/g, ' ').trim();

function isHttpsUrl(value: string | undefined): boolean {
  if (!value) return false;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname.includes('.') && value.length <= 2048;
  } catch {
    return false;
  }
}

const isPercent = (n: number | undefined) => Number.isInteger(n) && n! >= 1 && n! <= 99;
const isRupees = (n: number | undefined) => Number.isInteger(n) && n! >= 0 && n! <= 100_000_000;

/** A clean deal, or the reason it was rejected. */
export async function normalize(
  source: Source,
  raw: ScrapedDeal,
  now: Date,
): Promise<{ deal: NormalizedDeal } | { rejected: string }> {
  const title = collapse(raw.title ?? '');
  if (title.length < 3 || title.length > 140) return { rejected: 'title length' };
  if (!raw.externalId || raw.externalId.length > 200) return { rejected: 'external id' };
  if (!isHttpsUrl(raw.url)) return { rejected: 'url must be https' };
  if (raw.imageUrl !== undefined && !isHttpsUrl(raw.imageUrl)) return { rejected: 'image url must be https' };
  if (raw.endsAt && raw.endsAt <= now) return { rejected: 'already ended' };
  if (raw.startsAt && raw.endsAt && raw.endsAt <= raw.startsAt) return { rejected: 'ends before it starts' };

  const o = raw.offer;
  switch (o.kind) {
    case 'percent_off':
    case 'up_to_percent_off':
    case 'flat_percent_off':
      if (!isPercent(o.percent)) return { rejected: 'percent must be 1-99' };
      break;
    case 'amount_off':
      if (!isRupees(o.amountOffPkr) || o.amountOffPkr === 0) return { rejected: 'amount off' };
      break;
    case 'fixed_price':
      if (!isRupees(o.pricePkr)) return { rejected: 'price' };
      break;
    case 'text': {
      const text = collapse(o.text ?? '');
      if (text.length < 1 || text.length > 60) return { rejected: 'offer text' };
      break;
    }
  }
  if (o.originalPricePkr !== undefined) {
    if (!isRupees(o.pricePkr) || !isRupees(o.originalPricePkr) || o.originalPricePkr <= o.pricePkr!) {
      return { rejected: 'original price must be above the price' };
    }
    // Never a fake discount: a badge next to two prices must match them
    // (the database checks the same rules).
    const real = Math.floor(((o.originalPricePkr - o.pricePkr!) * 100) / o.originalPricePkr);
    if ((o.kind === 'percent_off' || o.kind === 'flat_percent_off') && o.percent !== real) {
      return { rejected: `percent ${o.percent} is not the real ${real}` };
    }
    if (o.kind === 'amount_off' && o.amountOffPkr !== o.originalPricePkr - o.pricePkr!) {
      return { rejected: 'amount off is not the price difference' };
    }
    if (o.kind === 'up_to_percent_off') return { rejected: '"up to" never comes with one price pair' };
  }

  return {
    deal: {
      ...raw,
      title,
      description: raw.description ? collapse(raw.description).slice(0, 2000) : undefined,
      offer: o.kind === 'text' ? { ...o, text: collapse(o.text!) } : o,
      fingerprint: await fingerprint(source.slug, raw.externalId),
    },
  };
}
