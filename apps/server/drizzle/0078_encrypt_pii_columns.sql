-- birthday moves from `date` to `text`: encrypted values (src/crypto.ts) are
-- opaque ciphertext, not valid date literals. Existing values are cast to
-- their ISO date string first, so any already-collected birthdays keep
-- reading fine as legacy plaintext (decryptPII returns non-prefixed values
-- as-is) until the player next hits save, at which point they're encrypted.
-- address_line1/line2/city/state/country/postal are already `text`, so no
-- schema change is needed for those - they just start holding ciphertext.
ALTER TABLE users ALTER COLUMN birthday TYPE text USING birthday::text;
