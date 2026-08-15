"use client";
import Link from "next/link";
import { LanguageSwitcher } from "./LanguageSwitcher";

export function Menu() {
  return (
    <div className="flex items-center justify-between fixed z-1000 w-full">
      <a href="https://hackclub.com" target="_blank">
        <img
          src="/hc-logo.png"
          alt="Hack Club"
          className="w-28 sm:w-40 lg:w-64"
        />
      </a>
      <div className="flex items-center gap-2 sm:gap-3 mr-3 lg:mr-6">
        <LanguageSwitcher />
        <Link
          href="/docs"
          className="font-pixel text-center px-3 py-1.5 text-lg sm:text-xl lg:text-2xl bg-[#ff8c37] text-[#F5EED2] cursor-pointer border-black border-r-4 border-t-2 border-l-2 border-b-4 hover:border-b-8 hover:-translate-y-0.5 hover:-translate-x-0.5 transition-all"
        >
          open docs
        </Link>
      </div>
    </div>
  );
}
