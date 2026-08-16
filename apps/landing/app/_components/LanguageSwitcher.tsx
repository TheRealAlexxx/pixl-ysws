"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useLocale } from "./LocaleProvider";

const LANGS: [string, string][] = [
  ["en", "English"],
  ["fr", "Français"],
  ["es", "Español"],
  ["pt", "Português"],
];

export function LanguageSwitcher() {
  const { dict, lang } = useLocale();
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onPointerDown(e: PointerEvent) {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    }
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  function switchTo(next: string) {
    setOpen(false);
    if (next === lang) return;
    // pathname looks like "/fr" or "/fr/whatever" , swap the leading locale.
    const rest = pathname.replace(/^\/[a-z]{2}(?=\/|$)/, "");
    router.push(`/${next}${rest || ""}`);
  }

  const current = LANGS.find(([value]) => value === lang)?.[1] ?? lang;

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={dict.menu.language}
        className="flex cursor-pointer items-center gap-1.5 border-black border-b-4 border-l-2 border-r-4 border-t-2 bg-[#F5EED2] px-2.5 py-1 font-pixel text-xs text-black transition-all hover:-translate-x-0.5 hover:-translate-y-0.5 hover:border-b-6 sm:gap-2 sm:px-3 sm:py-1.5 sm:text-sm lg:text-base"
      >
        {current}
        <svg
          width="10"
          height="10"
          viewBox="0 0 24 24"
          fill="none"
          stroke="black"
          strokeWidth="4"
          strokeLinecap="round"
          strokeLinejoin="round"
          className={`shrink-0 transition-transform ${open ? "rotate-180" : ""}`}
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>
      {open && (
        <ul
          role="listbox"
          aria-label={dict.menu.language}
          className="absolute right-0 top-full z-10 mt-2 min-w-full overflow-hidden border-2 border-black bg-[#F5EED2]"
          style={{ boxShadow: "4px 4px 0 #000" }}
        >
          {LANGS.map(([value, label]) => (
            <li key={value} role="option" aria-selected={value === lang}>
              <button
                type="button"
                onClick={() => switchTo(value)}
                className={`block w-full whitespace-nowrap px-3 py-1.5 text-left font-pixel text-xs transition-colors sm:text-sm ${
                  value === lang
                    ? "bg-black text-[#F5EED2]"
                    : "text-black hover:bg-[#ec3750] hover:text-[#F5EED2]"
                }`}
              >
                {label}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
