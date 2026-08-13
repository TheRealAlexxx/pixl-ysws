import jwt from "jsonwebtoken";

const JWT_SECRET: string = (() => {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET is not set");
  return secret;
})();

export interface SessionPayload {
  userId: string;
  displayName: string;
}

// Sessions can't be revoked server side, so keep the window short enough that a
// leaked token dies on its own. An expired token closes the socket with 4001
// and the client sends the player back to the login screen.
export function issueSessionToken(payload: SessionPayload): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "14d" });
}

export function verifySessionToken(token: string): SessionPayload | null {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as unknown as SessionPayload;
    return decoded;
  } catch {
    return null;
  }
}
