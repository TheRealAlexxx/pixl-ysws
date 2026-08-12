import { db } from "./pgCompat.js";

// Talks straight to Orchard Postgres over DATABASE_URL. The name is kept so
// the existing call sites don't all have to change at once; the builder API
// it exposes is the same subset they were already using.
export const supabase = db;

// --- Types matching the table shapes (snake_case, matching Postgres columns) ---
export interface UserRow {
  id: string;
  oauth_provider: string;
  oauth_id: string;
  display_name: string;
  real_name: string;
  avatar_url: string | null;
  skin: string;
  created_at: string;
}

export interface PlayerStateRow {
  user_id: string;
  scene: string;
  pos_x: number;
  pos_y: number;
  direction: string;
  updated_at: string;
}
