export const SHOP_CATEGORIES = [
  "grants",
  "merch",
  "tech",
  "printers",
  "software",
  "kits",
  "other",
] as const;
export type ShopCategory = (typeof SHOP_CATEGORIES)[number];
export const SHOP_CATEGORY_LABELS: Record<ShopCategory, string> = {
  grants: "Grants",
  merch: "Merch",
  tech: "Tech",
  printers: "3D Printers",
  software: "Software & Licenses",
  kits: "DIY Kits",
  other: "Other",
};
