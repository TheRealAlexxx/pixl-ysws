"use client";
import { useLocale } from "./LocaleProvider";
import { LanguageSwitcher } from "./LanguageSwitcher";

export function Menu() {
  const { dict } = useLocale();
  const t = dict.menu;
  return (
    <div className="flex items-center justify-between fixed z-1000 w-full">
      <a href="https://hackclub.com" target="_blank">
        <img src="/hc-logo.png" alt="Hack Club" className="w-28 sm:w-40 lg:w-64" />
      </a>
      <div className="flex items-center gap-2 mr-3 lg:mr-6">
        <LanguageSwitcher />
        <a
          className="relative text-center px-4 py-2 text-sm sm:text-xl md:text-2xl lg:text-3xl bg-[#ec3750] cursor-pointer text-white hover:-translate-y-1 hover:-translate-x-1 border-black border-r-8 border-t-2 border-l-2 hover:border-b-12 border-b-8 transition-all lg:px-7 lg:py-3"
          href="https://pixl.hackclub.com/play"
        >
          {t.playTheGame}
        </a>
      </div>
    </div>
  );
}
