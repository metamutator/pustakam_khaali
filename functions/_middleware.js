// Optional shared password for the whole book.
//
// Off unless the repo has a BOOK_PASSWORD secret: the publish workflow
// then writes a SHA-256 hash of it into password.js (never committed)
// and every page asks for it. Readers can type any username.
// To switch the password off, delete the BOOK_PASSWORD secret and
// re-run the workflow.

import { PASSWORD_SHA256 } from "../password.js";

const REALM = "Book";

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function sameString(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function passwordFrom(header) {
  if (!header || !header.startsWith("Basic ")) return null;
  try {
    const bytes = Uint8Array.from(atob(header.slice(6).trim()), (c) => c.charCodeAt(0));
    const decoded = new TextDecoder().decode(bytes);   // handles non-ASCII passwords
    const colon = decoded.indexOf(":");
    return colon === -1 ? null : decoded.slice(colon + 1);
  } catch {
    return null;
  }
}

export async function onRequest(context) {
  if (!PASSWORD_SHA256) return context.next();   // no password set: open

  const given = passwordFrom(context.request.headers.get("Authorization"));
  if (given !== null && sameString(await sha256Hex(given), PASSWORD_SHA256)) {
    return context.next();
  }
  return new Response("This book needs a password. Any username will do.\n", {
    status: 401,
    headers: {
      "WWW-Authenticate": `Basic realm="${REALM}", charset="UTF-8"`,
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Robots-Tag": "noindex, nofollow",
    },
  });
}
