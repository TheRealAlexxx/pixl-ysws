"use client";

import { motion, useMotionValue } from "framer-motion";
import { useEffect, useRef } from "react";

function wrap(value: number, min: number, max: number) {
  const range = max - min;
  return min + ((((value - min) % range) + range) % range);
}

/**
 * Auto-scrolling row that loops seamlessly. Expects its children to be the same
 * list rendered twice: it scrolls the first copy out of view, then jumps back
 * by exactly one copy, which is invisible only if that distance is exact.
 *
 * Getting that distance right is the whole job, and the old copies of this got
 * it wrong twice over:
 *
 *  - scrollWidth / 2 is not one copy. With N items and a flex gap there are
 *    2N-1 gaps in the track, so half of it lands half a gap short and the row
 *    visibly hops on every lap.
 *  - it measured once on mount, before any image had loaded. Every image that
 *    arrived afterwards widened the track, and the loop point stayed where it
 *    was, so the jump grew to hundreds of pixels.
 *
 * Both are fixed by measuring the offset of the first item of the second copy
 * (exact, whatever the gaps are) and re-measuring whenever the track resizes.
 */
export function Marquee({
  children,
  duration = 40,
  className = "",
  swallowClickAfterDrag = false,
}: {
  children: React.ReactNode;
  /** seconds for one full lap */
  duration?: number;
  /** classes for the moving track, e.g. gap and padding */
  className?: string;
  /** stop a drag from registering as a click on a card underneath */
  swallowClickAfterDrag?: boolean;
}) {
  const x = useMotionValue(0);
  const trackRef = useRef<HTMLDivElement>(null);
  const halfWidthRef = useRef(0);
  const rafRef = useRef<number | null>(null);
  const lastTsRef = useRef<number | null>(null);
  const pausedRef = useRef(false);
  const draggingRef = useRef(false);
  const draggedRef = useRef(false);
  const dragStartXRef = useRef(0);
  const dragStartValueRef = useRef(0);

  useEffect(() => {
    const track = trackRef.current;
    if (!track) return;

    function measure() {
      if (!track) return;
      const items = track.children;
      const half = items.length / 2;
      if (half < 1) return;
      // distance from the start of the list to the start of its duplicate
      const next = (items[half] as HTMLElement).offsetLeft;
      const first = (items[0] as HTMLElement).offsetLeft;
      const width = next - first;
      if (width <= 0) return;

      const had = halfWidthRef.current;
      halfWidthRef.current = width;
      // keep the current position inside the new range, and on first measure
      // start one copy in so dragging right has somewhere to go
      x.set(had ? wrap(x.get(), -width, 0) : -width);
    }

    measure();

    // fires as images load and lay out, which is when the old measurement went
    // stale, plus on any viewport change
    const observer = new ResizeObserver(measure);
    observer.observe(track);
    for (const child of Array.from(track.children)) observer.observe(child);

    function tick(ts: number) {
      const dt = lastTsRef.current == null ? 0 : ts - lastTsRef.current;
      lastTsRef.current = ts;
      if (!pausedRef.current && !draggingRef.current && halfWidthRef.current) {
        const speed = halfWidthRef.current / (duration * 1000);
        x.set(wrap(x.get() - speed * dt, -halfWidthRef.current, 0));
      }
      rafRef.current = requestAnimationFrame(tick);
    }
    rafRef.current = requestAnimationFrame(tick);

    return () => {
      observer.disconnect();
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
    };
  }, [x, duration]);

  function onPointerDown(e: React.PointerEvent) {
    draggingRef.current = true;
    draggedRef.current = false;
    dragStartXRef.current = e.clientX;
    dragStartValueRef.current = x.get();
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  }

  function onPointerMove(e: React.PointerEvent) {
    if (!draggingRef.current) return;
    const delta = e.clientX - dragStartXRef.current;
    if (Math.abs(delta) > 5) draggedRef.current = true;
    const halfWidth = halfWidthRef.current;
    if (halfWidth) x.set(wrap(dragStartValueRef.current + delta, -halfWidth, 0));
  }

  function endDrag() {
    if (!draggingRef.current) return;
    draggingRef.current = false;
    if (draggedRef.current) pausedRef.current = false;
  }

  function onClickCapture(e: React.MouseEvent) {
    if (swallowClickAfterDrag && draggedRef.current) {
      e.stopPropagation();
      e.preventDefault();
      draggedRef.current = false;
    }
  }

  return (
    <div
      className="w-full overflow-hidden cursor-grab active:cursor-grabbing select-none touch-pan-y"
      style={{
        maskImage:
          "linear-gradient(to right, transparent, black 8%, black 92%, transparent)",
      }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={endDrag}
      onPointerCancel={endDrag}
      onClickCapture={onClickCapture}
      onMouseEnter={() => {
        pausedRef.current = true;
      }}
      onMouseLeave={() => {
        if (!draggingRef.current) pausedRef.current = false;
      }}
    >
      <motion.div
        ref={trackRef}
        className={`flex ${className}`}
        style={{ x, width: "max-content", willChange: "transform" }}
        draggable={false}
      >
        {children}
      </motion.div>
    </div>
  );
}
