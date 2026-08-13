const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function POST(req: Request) {
  const { email } = await req.json();
  if (!email) return Response.json({ error: "No email" }, { status: 400 });
  if (typeof email !== "string" || email.length > 254 || !EMAIL_RE.test(email)) {
    return Response.json({ error: "Invalid email" }, { status: 400 });
  }

  const baseUrl = `https://api.airtable.com/v0/${process.env.AIRTABLE_BASE_ID}/Signups`;
  const authHeader = `Bearer ${process.env.AIRTABLE_TOKEN}`;

  // Escape backslashes before quotes , escaping quotes alone lets a
  // "\" + '"' pair in the input smuggle an unescaped quote through and
  // close the formula string literal early (Airtable formula injection).
  const escapedEmail = email.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  const filter = encodeURIComponent(`{Email} = "${escapedEmail}"`);
  const existing = await fetch(
    `${baseUrl}?filterByFormula=${filter}&maxRecords=1`,
    { headers: { Authorization: authHeader }, signal: AbortSignal.timeout(10_000) },
  );
  const existingData = await existing.json();
  if (existingData.records?.length > 0) {
    return Response.json({ ok: true, skipped: true });
  }

  const res = await fetch(
    baseUrl,
    {
      method: "POST",
      headers: {
        Authorization: authHeader,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields: { Email: email } }),
      signal: AbortSignal.timeout(10_000),
    },
  );

  const data = await res.json();
  console.log("Airtable response:", data);

  return Response.json({ ok: true, airtable: data });
}
