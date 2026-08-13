// 1200x630 Open Graph card, drawn in the shell's LEDGER palette. Colors come
// from packages/theme/palette.json's web.dark tokens - the card renders the
// same LEDGER DARK a visitor sees on the page, not a third hand-copied palette.
//
// Reads the palette with node:fs rather than Bun.file: this module also runs
// inside Vercel's Node.js serverless function runtime (the shop item preview
// cards), which has no Bun global.
import { readFileSync } from "node:fs";
import { Canvas, hex, type Rgb } from "./png.ts";
import { drawText, textWidth, wrap, GLYPH_H } from "./font.ts";

const W = 1200;
const H = 630;

const paletteJson = JSON.parse(
  readFileSync(new URL("../../theme/palette.json", import.meta.url), "utf8"),
);
const LEDGER = paletteJson.web.dark;

export const BG = hex(LEDGER["panel-deep"]);
export const PANEL = hex(LEDGER.panel);
export const STROKE = hex(LEDGER.stroke);
export const GOLD = hex(LEDGER.gold);
export const INK = hex(LEDGER.ink);
export const DIM = hex(LEDGER.dim);

export interface CardInput {
  title: string;
  eyebrow: string;
  url: string;
}

export function shard(canvas: Canvas, x: number, y: number, unit: number, color: Rgb): void {
  [1, 2, 3, 4, 3, 2, 1].forEach((w, i) => {
    canvas.fill(x - (w * unit) / 2, y + i * unit, w * unit, unit, color);
  });
}

export function renderCard({ title, eyebrow, url }: CardInput): Uint8Array {
  const canvas = new Canvas(W, H, BG);

  const pad = 48;
  canvas.fill(pad, pad, W - pad * 2, H - pad * 2, PANEL);
  canvas.stroke(pad, pad, W - pad * 2, H - pad * 2, 3, STROKE);
  canvas.fill(pad, pad, 8, H - pad * 2, GOLD);

  const left = pad + 64;
  const right = W - pad - 64;
  const maxWidth = right - left;

  shard(canvas, left + 10, pad + 78, 5, GOLD);
  drawText(canvas, eyebrow.toUpperCase(), left + 34, pad + 80, 4, GOLD, 2);

  const blockTop = pad + 168;
  const footY = H - pad - 78;
  const available = footY - blockTop - 28;
  const lineHeightAt = (s: number) => GLYPH_H * s + 22;

  // Shrink until the wrapped block fits vertically too, or a long title wraps
  // happily and then lands on top of the URL.
  let scale = 13;
  let lines = wrap(title.toUpperCase(), scale, maxWidth);
  while (scale > 5 && lines.length * lineHeightAt(scale) > available) {
    scale -= 1;
    lines = wrap(title.toUpperCase(), scale, maxWidth);
  }
  const lineHeight = lineHeightAt(scale);
  const top = blockTop + Math.max(0, (available - lines.length * lineHeight) / 2);
  lines.forEach((line, i) => drawText(canvas, line, left, top + i * lineHeight, scale, INK));

  canvas.fill(left, footY, maxWidth, 2, STROKE);
  drawText(canvas, url.toUpperCase(), left, footY + 26, 3, DIM, 2);
  canvas.fill(right - textWidth(url.toUpperCase(), 3, 2) - 24, footY + 26, 14, GLYPH_H * 3, GOLD);

  return canvas.encode();
}
