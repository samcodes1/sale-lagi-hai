// robots.txt (RFC 9309): which paths our crawler may fetch.
//
// We obey the group for our product token ("SaleLagiHaiBot") if there is
// one, else the "*" group. Within a group the longest matching rule wins;
// on a tie, Allow wins. "*" matches any characters and a trailing "$"
// anchors the end. A missing robots.txt (404) allows everything; one we
// can't read (5xx, timeout) disallows everything until we can.

export type RobotsRules = { allow: string[]; disallow: string[]; crawlDelaySeconds: number | null };

export const ALLOW_ALL: RobotsRules = { allow: [], disallow: [], crawlDelaySeconds: null };
export const DISALLOW_ALL: RobotsRules = { allow: [], disallow: ['/'], crawlDelaySeconds: null };

export function parseRobots(text: string, productToken: string): RobotsRules {
  type Group = { agents: string[]; allow: string[]; disallow: string[]; delay: number | null };
  const groups: Group[] = [];
  let current: Group | null = null;
  let lastWasAgent = false;

  // RFC 9309 limits parsing to the first 500 KiB.
  for (const raw of text.slice(0, 500 * 1024).split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    const colon = line.indexOf(':');
    if (colon < 0) continue;
    const key = line.slice(0, colon).trim().toLowerCase();
    const value = line.slice(colon + 1).trim();
    if (key === 'user-agent') {
      if (!lastWasAgent || current === null) {
        current = { agents: [], allow: [], disallow: [], delay: null };
        groups.push(current);
      }
      current.agents.push(value.toLowerCase());
      lastWasAgent = true;
      continue;
    }
    lastWasAgent = false;
    if (current === null) continue;
    if (key === 'allow' && value) current.allow.push(value);
    else if (key === 'disallow' && value) current.disallow.push(value);
    else if (key === 'crawl-delay') {
      const delay = Number(value);
      if (Number.isFinite(delay) && delay >= 0) current.delay = delay;
    }
  }

  const token = productToken.toLowerCase();
  const mine = groups.filter((g) => g.agents.some((a) => a !== '*' && token.startsWith(a)));
  const chosen = mine.length > 0 ? mine : groups.filter((g) => g.agents.includes('*'));
  return {
    allow: chosen.flatMap((g) => g.allow),
    disallow: chosen.flatMap((g) => g.disallow),
    crawlDelaySeconds: chosen.map((g) => g.delay).find((d) => d !== null) ?? null,
  };
}

function ruleMatches(rule: string, path: string): number {
  const anchored = rule.endsWith('$');
  const body = anchored ? rule.slice(0, -1) : rule;
  const pattern = body.split('*').map((part) => part.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('.*');
  const match = new RegExp(`^${pattern}${anchored ? '$' : ''}`).exec(path);
  return match ? body.length : -1;
}

/** May we fetch `pathWithQuery` (e.g. "/products.json?page=2")? */
export function isAllowed(rules: RobotsRules, pathWithQuery: string): boolean {
  if (pathWithQuery === '/robots.txt') return true;
  let best = -1;
  let allowed = true;
  for (const rule of rules.disallow) {
    const len = ruleMatches(rule, pathWithQuery);
    if (len > best) {
      best = len;
      allowed = false;
    }
  }
  for (const rule of rules.allow) {
    const len = ruleMatches(rule, pathWithQuery);
    if (len >= best && len >= 0) {
      best = len;
      allowed = true;
    }
  }
  return allowed;
}
