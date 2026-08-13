// Guards against SSRF when fetching a URL that ultimately comes from
// user/DB-sourced data (e.g. a shop item's image_url) rather than a literal
// in this codebase. Used by shop-og.ts before it fetches an item's photo.
//
// Checks: scheme must be http/https, hostname can't be localhost/0.0.0.0,
// and every IP the hostname resolves to must be public (no loopback,
// private, or link-local range). This doesn't defend against DNS rebinding
// between the check and the actual fetch - undici doesn't expose a way to
// pin the resolved IP for a single fetch() call - but it stops the common
// case of an item pointed at an internal service or cloud metadata endpoint.
import { lookup } from "node:dns/promises";

const BLOCKED_HOSTNAMES = new Set(["localhost", "0.0.0.0"]);

function ipv4ToInt(ip: string): number {
  const parts = ip.split(".").map(Number);
  return ((parts[0]! << 24) | (parts[1]! << 16) | (parts[2]! << 8) | parts[3]!) >>> 0;
}

function inRange(ip: number, base: string, bits: number): boolean {
  const baseInt = ipv4ToInt(base);
  const mask = bits === 0 ? 0 : (~0 << (32 - bits)) >>> 0;
  return (ip & mask) === (baseInt & mask);
}

function isPrivateV4(ip: string): boolean {
  const n = ipv4ToInt(ip);
  return (
    inRange(n, "127.0.0.0", 8) ||
    inRange(n, "10.0.0.0", 8) ||
    inRange(n, "172.16.0.0", 12) ||
    inRange(n, "192.168.0.0", 16) ||
    inRange(n, "169.254.0.0", 16)
  );
}

function isPrivateV6(ip: string): boolean {
  const lower = ip.toLowerCase();
  if (lower === "::1") return true;
  if (/^fe[89ab][0-9a-f]:/.test(lower)) return true; // fe80::/10 link-local
  if (/^f[cd][0-9a-f]{2}:/.test(lower)) return true; // fc00::/7 unique local
  // IPv4-mapped/compatible addresses (::ffff:127.0.0.1, ::127.0.0.1) - check
  // the embedded v4 the same way.
  const mapped = lower.match(/(?:^::ffff:|^::)(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return isPrivateV4(mapped[1]!);
  return false;
}

/**
 * Throws if `rawUrl` isn't safe to fetch server-side: bad scheme, a
 * blocked hostname literal, or a hostname that resolves to a private/
 * loopback/link-local address.
 */
export async function assertSafeUrl(rawUrl: string): Promise<URL> {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new Error(`invalid URL: ${rawUrl}`);
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error(`blocked scheme: ${url.protocol}`);
  }

  const hostname = url.hostname.toLowerCase();
  if (BLOCKED_HOSTNAMES.has(hostname)) {
    throw new Error(`blocked hostname: ${hostname}`);
  }

  const addresses = await lookup(hostname, { all: true });
  if (addresses.length === 0) {
    throw new Error(`could not resolve hostname: ${hostname}`);
  }
  for (const { address, family } of addresses) {
    if (family === 4 ? isPrivateV4(address) : isPrivateV6(address)) {
      throw new Error(`hostname resolves to a private address: ${hostname} -> ${address}`);
    }
  }

  return url;
}

/** Validates `rawUrl` via assertSafeUrl, then fetches it with a 10s timeout. */
export async function safeFetch(rawUrl: string, init: RequestInit = {}): Promise<Response> {
  const url = await assertSafeUrl(rawUrl);
  return fetch(url, { ...init, signal: init.signal ?? AbortSignal.timeout(10_000) });
}
