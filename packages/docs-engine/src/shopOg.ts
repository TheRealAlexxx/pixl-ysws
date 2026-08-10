// 1200x630 shop item preview card - same LEDGER-branded frame as renderCard
// (src/og.ts), but with the item's own photo inset in a bordered box instead
// of the card being all text, since a shared /shop/item?id= link should show
// the actual item, not a generic "Pixl Shop" placeholder.
import { Canvas, decodePNG, type DecodedImage } from "./png.ts";
import { drawText, wrap, GLYPH_H } from "./font.ts";
import { BG, PANEL, STROKE, GOLD, INK, DIM, shard } from "./og.ts";

const W = 1200;
const H = 630;

export interface ItemCardInput {
  name: string;
  price: number;
  // Raw bytes of the item's image_url response, or null if it couldn't be
  // fetched/decoded - the card still renders fine without it.
  imageBytes: Uint8Array | null;
}

export function renderItemCard({ name, price, imageBytes }: ItemCardInput): Uint8Array {
  const canvas = new Canvas(W, H, BG);

  const pad = 48;
  canvas.fill(pad, pad, W - pad * 2, H - pad * 2, PANEL);
  canvas.stroke(pad, pad, W - pad * 2, H - pad * 2, 3, STROKE);
  canvas.fill(pad, pad, 8, H - pad * 2, GOLD);

  // Photo box: a fixed square inset on the left, framed the same way the
  // item detail page frames #detail-img.
  const boxSize = 440;
  const boxX = pad + 64;
  const boxY = (H - boxSize) / 2;
  canvas.fill(boxX, boxY, boxSize, boxSize, BG);
  canvas.stroke(boxX, boxY, boxSize, boxSize, 2, STROKE);

  let image: DecodedImage | null = null;
  if (imageBytes) {
    try {
      image = decodePNG(imageBytes);
    } catch {
      image = null; // unsupported format (e.g. not a PNG) - card still works without it
    }
  }
  if (image) {
    const inset = 20;
    canvas.drawImage(image, boxX + inset, boxY + inset, boxSize - inset * 2, boxSize - inset * 2);
  }

  const left = boxX + boxSize + 56;
  const right = W - pad - 64;
  const maxWidth = right - left;

  shard(canvas, left + 10, pad + 78, 5, GOLD);
  drawText(canvas, "PIXL SHOP", left + 34, pad + 80, 4, GOLD, 2);

  const blockTop = pad + 168;
  const footY = H - pad - 78;
  const available = footY - blockTop - 44;
  const lineHeightAt = (s: number) => GLYPH_H * s + 22;

  let scale = 10;
  let lines = wrap(name.toUpperCase(), scale, maxWidth);
  while (scale > 5 && lines.length * lineHeightAt(scale) > available) {
    scale -= 1;
    lines = wrap(name.toUpperCase(), scale, maxWidth);
  }
  const lineHeight = lineHeightAt(scale);
  const nameTop = blockTop;
  lines.forEach((line, i) => drawText(canvas, line, left, nameTop + i * lineHeight, scale, INK));

  const priceText = `${Math.round(price).toLocaleString()} PX`;
  const priceY = nameTop + lines.length * lineHeight + 20;
  drawText(canvas, priceText, left, priceY, 6, GOLD);

  // No trailing accent block here (renderCard has one) - the right column is
  // narrower than a full-width card, and short item names left it colliding
  // with the "PIXL.RSVP/SHOP" text.
  canvas.fill(left, footY, maxWidth, 2, STROKE);
  drawText(canvas, "PIXL.RSVP/SHOP", left, footY + 26, 3, DIM, 2);

  return canvas.encode();
}
