/**
 * Applies drizzle/*.sql in journal order, one transaction per migration.
 *
 *   node dist/scripts/apply-migrations.js           (dry run: what would apply)
 *   node dist/scripts/apply-migrations.js --write
 *
 * `drizzle-kit migrate` gets OOM-killed here: it loads all 106 migrations and
 * runs them as a single transaction, so a failure anywhere rolls back
 * everything and reports nothing useful. This does the same bookkeeping -
 * same drizzle.__drizzle_migrations table, same sha256 hashes, so drizzle-kit
 * stays in sync afterwards - but commits per migration and names the file that
 * failed.
 *
 * Each file is executed whole rather than split on semicolons: several define
 * functions whose $$-quoted bodies contain semicolons of their own.
 */
import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import postgres from "postgres";

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) throw new Error("DATABASE_URL must be set");
const WRITE = process.argv.includes("--write");

const DIR = join(import.meta.dirname, "..", "..", "drizzle");
const journal = JSON.parse(await readFile(join(DIR, "meta", "_journal.json"), "utf8")) as {
  entries: { idx: number; when: number; tag: string }[];
};

const sql = postgres(DATABASE_URL, { max: 1, onnotice: () => {} });

await sql.unsafe(`create schema if not exists drizzle`);
await sql.unsafe(`create table if not exists drizzle.__drizzle_migrations (
  id serial primary key, hash text not null, created_at bigint)`);

const applied = await sql<{ hash: string }[]>`select hash from drizzle.__drizzle_migrations`;
const done = new Set(applied.map((r) => r.hash));

const files = new Set(await readdir(DIR));
const todo: { tag: string; when: number; hash: string; body: string }[] = [];

for (const entry of journal.entries) {
  const name = `${entry.tag}.sql`;
  if (!files.has(name)) {
    console.log(`missing file, skipping: ${name}`);
    continue;
  }
  const body = await readFile(join(DIR, name), "utf8");
  const hash = createHash("sha256").update(body).digest("hex");
  if (!done.has(hash)) todo.push({ tag: entry.tag, when: entry.when, hash, body });
}

console.log(`already applied: ${done.size}`);
console.log(`to apply: ${todo.length}`);

if (!WRITE) {
  for (const t of todo.slice(0, 5)) console.log(`  would apply ${t.tag}`);
  if (todo.length > 5) console.log(`  ... and ${todo.length - 5} more`);
  console.log("\ndry run - pass --write to apply");
  await sql.end();
  process.exit(0);
}

let ok = 0;
for (const m of todo) {
  try {
    await sql.begin(async (tx) => {
      await tx.unsafe(m.body);
      await tx`insert into drizzle.__drizzle_migrations (hash, created_at) values (${m.hash}, ${m.when})`;
    });
    ok++;
  } catch (err) {
    console.error(`\nFAILED at ${m.tag} (after ${ok} applied)`);
    console.error(`  ${(err as Error).message.split("\n")[0]}`);
    await sql.end();
    process.exit(1);
  }
}

const [{ c: tables }] = await sql<{ c: number }[]>`
  select count(*)::int c from information_schema.tables
  where table_schema = 'public' and table_type = 'BASE TABLE'`;
console.log(`applied ${ok} migrations, public tables now: ${tables}`);
await sql.end();
