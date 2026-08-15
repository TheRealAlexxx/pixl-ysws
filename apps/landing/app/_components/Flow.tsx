"use client";

import { motion } from "framer-motion";
import { useLocale } from "./LocaleProvider";
import {
  config,
  pxPerHourFor,
  projectPayoutPx,
  rePerHour,
  reForHours,
} from "../_generated/config";

// Every number in this section is derived, never typed in: the tier rates, the
// px/hr floor and ceiling and the example ladder all come out of
// packages/config/pixl.json via the generated copy. The one number deliberately
// left out is the chapter goal, which lives in vault_levels and moves per
// chapter, so the copy talks about filling the goal without naming it.
const LADDER = [
  { hours: 10, tier: 2, img: "/shop/blahaj.webp", price: 575 },
  { hours: 35, tier: 3, img: "/shop/rpi.webp", price: 2000 },
  { hours: 100, tier: 4, img: "/shop/ipad.webp", price: 5725 },
];

const fadeUp = {
  initial: { opacity: 0, y: 20 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, amount: 0.3 },
};

const num = (n: number) => Math.round(n).toLocaleString("en-US");

function ArrowHead({ className = "" }: { className?: string }) {
  return (
    <span
      aria-hidden
      className={`absolute w-6 h-4 bg-black ${className}`}
      style={{ clipPath: "polygon(0 0, 100% 0, 50% 100%)" }}
    />
  );
}

/** Straight drop between two stacked nodes. */
function Down({ height = "h-28" }: { height?: string }) {
  return (
    <div aria-hidden className={`relative w-full ${height} shrink-0`}>
      <span className="absolute left-1/2 top-0 bottom-0 w-1 -translate-x-1/2 bg-black" />
      <ArrowHead className="left-1/2 bottom-0 -translate-x-1/2" />
    </div>
  );
}

// The branch rows are plain 2-column grids, so the two cards sit at exactly 25%
// and 75%. Drawing the connectors as positioned spans instead of a scaled SVG
// keeps every line a crisp 4px at any width, and square corners suit the pixel
// styling better than curves would.
function Fork({ label, up = false }: { label?: string; up?: boolean }) {
  const stem = up ? "bottom-0" : "top-0";
  const branch = up ? "top-0" : "bottom-0";
  return (
    <div aria-hidden className="relative w-full h-36 shrink-0">
      <span
        className={`absolute left-1/2 ${stem} h-18 w-1 -translate-x-1/2 bg-black`}
      />
      <span className="absolute left-1/4 right-1/4 top-1/2 h-1 -translate-y-1/2 bg-black max-sm:hidden" />
      <span
        className={`absolute left-1/4 ${branch} h-18 w-1 bg-black max-sm:hidden`}
      />
      <span
        className={`absolute right-1/4 ${branch} h-18 w-1 bg-black max-sm:hidden`}
      />
      {/* stacked on mobile: the fork collapses to one line straight through */}
      <span
        className={`absolute left-1/2 ${branch} h-18 w-1 -translate-x-1/2 bg-black sm:hidden`}
      />
      {up ? (
        <ArrowHead className="left-1/2 bottom-0 -translate-x-1/2" />
      ) : (
        <>
          <ArrowHead className="left-1/4 bottom-0 -translate-x-1/2 max-sm:hidden" />
          <ArrowHead className="right-1/4 bottom-0 translate-x-1/2 max-sm:hidden" />
          <ArrowHead className="left-1/2 bottom-0 -translate-x-1/2 sm:hidden" />
        </>
      )}
      {label && (
        <span
          className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-[#F5EED2] border-2 border-black rounded-full px-4 py-1 font-pixel text-sm text-black/60"
          style={{ boxShadow: "2px 2px 0px #000" }}
        >
          {label}
        </span>
      )}
    </div>
  );
}

function Node({
  n,
  title,
  text,
  img,
  alt,
  icon,
  accent = "#000",
  children,
}: {
  n?: string;
  title: string;
  text: string;
  img?: string;
  alt?: string;
  icon?: string;
  accent?: string;
  children?: React.ReactNode;
}) {
  return (
    <motion.div
      className="w-full shrink-0 bg-[#fffaf7] border-2 border-black flex flex-col sm:flex-row overflow-hidden hover:-translate-y-1 hover:-translate-x-1 transition-transform"
      style={{ boxShadow: `6px 6px 0px ${accent}` }}
      {...fadeUp}
      transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
    >
      {img && (
        // The image column stretches to the row height, so the picture itself
        // has to be absolute: a plain h-full img inside an auto-height flex
        // parent resolves to zero and leaves a black box.
        <div className="relative h-44 sm:h-auto sm:w-56 lg:w-64 sm:shrink-0 border-b-2 sm:border-b-0 sm:border-r-2 border-black bg-black">
          <img
            src={img}
            alt={alt ?? ""}
            className="absolute inset-0 w-full h-full object-cover"
            style={{ imageRendering: "pixelated" }}
          />
        </div>
      )}
      <div className="px-6 py-5 lg:px-8 lg:py-6 flex-1 text-left">
        <p className="font-pixel text-xl lg:text-2xl leading-snug flex items-center gap-2.5">
          {n && (
            <span
              className="text-sm px-2 py-0.5 border-2 border-black shrink-0"
              style={{ background: accent, color: "#F5EED2" }}
            >
              {n}
            </span>
          )}
          {icon && (
            <img
              src={icon}
              alt=""
              aria-hidden
              className="w-7 h-7 shrink-0"
              style={{ imageRendering: "pixelated" }}
            />
          )}
          {title}
        </p>
        <p className="font-sans text-base text-black/60 leading-relaxed mt-2.5">
          {text}
        </p>
        {children}
      </div>
    </motion.div>
  );
}

/** Small card for the two branch options and the two chapter satellites. */
function MiniCard({
  title,
  text,
  accent,
  small = false,
}: {
  title: string;
  text: string;
  accent: string;
  small?: boolean;
}) {
  return (
    <motion.div
      className={`bg-[#fffaf7] border-2 border-black text-left h-full hover:-translate-y-1 hover:-translate-x-1 transition-transform ${small ? "px-5 py-4" : "px-6 py-5 lg:px-8 lg:py-6"}`}
      style={{ boxShadow: `${small ? 4 : 6}px ${small ? 4 : 6}px 0px ${accent}` }}
      {...fadeUp}
      transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
    >
      <p
        className={`font-pixel leading-snug ${small ? "text-base" : "text-xl lg:text-2xl"}`}
      >
        {title}
      </p>
      <p
        className={`font-sans text-black/60 leading-relaxed mt-2 ${small ? "text-sm" : "text-base"}`}
      >
        {text}
      </p>
    </motion.div>
  );
}

export function FlowDiagram() {
  const { dict } = useLocale();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const t = (dict.story as any).flow;

  const floorPx = Math.round(pxPerHourFor(0));
  const ceilPx = Math.round(pxPerHourFor(config.economy.reForMaxPayout));

  return (
    // Deliberately wider than every other section: 96vw breaks out of the
    // section's own padding so the graph reads as a canvas rather than another
    // stack of cards. Single nodes stay narrow enough to read, while the forks
    // and the paired rows use the full width.
    <div className="w-full sm:w-[96vw] max-w-[1600px] flex flex-col items-center">
      <div className="w-full max-w-3xl">
        <Node
          n="01"
          title={t.join.title}
          text={t.join.text}
          img="/flow-join.webp"
          alt={t.join.alt}
        />
      </div>

      <Fork label={t.andOr} />

      <div className="w-full grid grid-cols-1 sm:grid-cols-2 gap-6 max-sm:gap-0">
        <MiniCard title={t.trial.title} text={t.trial.text} accent="#ff8c37" />
        {/* the fork collapses on mobile, so the stacked options need a link */}
        <div className="sm:hidden">
          <Down height="h-20" />
        </div>
        <MiniCard title={t.invent.title} text={t.invent.text} accent="#ec3750" />
      </div>

      <Fork up />

      {/* Ship and Energy share a container so the dashed loop can bracket both */}
      <div className="relative w-full max-w-4xl md:pr-32 flex flex-col items-center">
        <Node
          n="02"
          title={t.ship.title}
          text={t.ship.text}
          img="/flow-explore.webp"
          alt={t.ship.alt}
        />

        <Down />

        <Node
          n="03"
          title={t.energy.title}
          text={t.energy.text}
          icon="/pixel_currency_gold-removebg-preview.png"
          accent="#ff8c37"
        >
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mt-4">
            {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
            {(t.energy.tiers as any[]).map((tier: any, i: number) => (
              <div
                key={tier.name}
                className="border-2 border-black px-2 py-2 text-center bg-[#F5EED2]"
              >
                <p className="font-pixel text-sm leading-none">{tier.name}</p>
                <p className="font-sans text-xs text-black/60 mt-1.5">
                  {rePerHour(i + 1)} {t.energy.perHour}
                </p>
              </div>
            ))}
          </div>
        </Node>

        <div
          aria-hidden
          className="hidden md:block absolute right-0 top-20 bottom-28 w-32"
        >
          <span className="absolute left-0 right-10 top-0 border-t-4 border-dashed border-black" />
          <span className="absolute right-10 top-0 bottom-0 border-l-4 border-dashed border-black" />
          <span className="absolute left-0 right-10 bottom-0 border-t-4 border-dashed border-black" />
          <span
            className="absolute left-0 top-0 w-4 h-6 bg-black -translate-y-1/2"
            style={{ clipPath: "polygon(100% 0, 100% 100%, 0 50%)" }}
          />
          <span className="absolute right-0 top-1/2 -translate-y-1/2 w-20 -mr-4 bg-[#F5EED2] py-2 font-pixel text-xs text-black/50 text-center leading-tight">
            {t.loop}
          </span>
        </div>
      </div>

      <Fork />

      <div className="w-full grid grid-cols-1 sm:grid-cols-2 gap-6 max-sm:gap-0 items-start">
        <Node
          n="04"
          title={t.paid.title}
          text={t.paid.text
            .replace("{floor}", String(floorPx))
            .replace("{ceil}", String(ceilPx))}
          icon="/pixel_currency_red-removebg-preview.png"
          accent="#ec3750"
        >
          <div className="mt-4 flex items-center gap-3">
            <span className="font-pixel text-base">{floorPx}</span>
            <span className="relative flex-1 h-4 border-2 border-black bg-[#F5EED2] overflow-hidden">
              <motion.span
                className="absolute inset-y-0 left-0 bg-[#ec3750]"
                initial={{ width: "18%" }}
                whileInView={{ width: "100%" }}
                viewport={{ once: true }}
                transition={{ duration: 1.4, ease: [0.22, 1, 0.36, 1] }}
              />
            </span>
            <span className="font-pixel text-base">{ceilPx}</span>
          </div>
          <p className="font-sans text-xs text-black/40 mt-1.5">
            {t.paid.scale}
          </p>
        </Node>

        <div className="sm:hidden">
          <Down height="h-20" />
        </div>

        {/* no h-full here: the grid row is sized by node 04, and stretching this
            column to match makes its three cards shrink until node 05 clips its
            own text away */}
        <div className="flex flex-col gap-4">
          <Node
            n="05"
            title={t.world.title}
            text={t.world.text}
            img="/world-map.webp"
            alt={t.world.alt}
            accent="#ff8c37"
          />
          {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
          {(t.chips as any[]).map((c: any) => (
            <MiniCard key={c.title} title={c.title} text={c.text} accent="#000" small />
          ))}
        </div>
      </div>

      <Down height="h-36" />

      <motion.div
        className="w-full bg-[#fffaf7] border-2 border-black px-6 py-8 sm:px-10 lg:px-12"
        style={{ boxShadow: "8px 8px 0px #ec3750" }}
        {...fadeUp}
        transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        <p className="font-pixel text-2xl lg:text-3xl text-center">
          {t.example.title}
        </p>
        <p className="font-sans text-base text-black/60 text-center mt-2 max-w-2xl mx-auto">
          {t.example.subtitle}
        </p>

        <div className="mt-8 flex flex-col gap-4">
          {LADDER.map((row, i) => {
            const re = reForHours(row.hours, row.tier);
            const paid = projectPayoutPx(row.hours, row.tier, 0);
            return (
              <motion.div
                key={row.hours}
                className="grid grid-cols-2 sm:grid-cols-4 items-center gap-4 border-2 border-black bg-[#F5EED2] px-5 py-4 lg:px-8 lg:py-5"
                {...fadeUp}
                transition={{
                  duration: 0.45,
                  delay: i * 0.1,
                  ease: [0.22, 1, 0.36, 1],
                }}
              >
                <div>
                  <p className="font-pixel text-2xl lg:text-3xl leading-none">
                    {row.hours}
                    {t.example.h}
                  </p>
                  <p className="font-sans text-xs text-black/50 mt-1.5">
                    {t.example.tier} {row.tier}
                  </p>
                </div>
                <div>
                  <p className="font-pixel text-2xl lg:text-3xl leading-none text-[#ff8c37]">
                    {num(re)}
                  </p>
                  <p className="font-sans text-xs text-black/50 mt-1.5">
                    {t.example.re}
                  </p>
                </div>
                <div>
                  <p className="font-pixel text-2xl lg:text-3xl leading-none text-[#ec3750]">
                    {num(paid)}
                  </p>
                  <p className="font-sans text-xs text-black/50 mt-1.5">
                    {t.example.px}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <img
                    src={row.img}
                    alt=""
                    aria-hidden
                    className="w-14 h-14 object-contain shrink-0"
                  />
                  <p className="font-sans text-sm text-black/60 leading-tight">
                    {t.example.buys} {t.example.items[i]}
                    <br />
                    <span className="text-black/40 text-xs">
                      {num(row.price)} {t.example.px}
                    </span>
                  </p>
                </div>
              </motion.div>
            );
          })}
        </div>

        <p className="font-sans text-xs text-black/40 text-center mt-5">
          {t.example.note}
        </p>
      </motion.div>
    </div>
  );
}
