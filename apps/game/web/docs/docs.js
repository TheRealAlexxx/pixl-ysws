// Behaviour for the generated doc pages. No routing here: every page is a real
// document now, so this is only the sidebar groups, the on-this-page rail,
// theme, and code copy buttons.
(() => {
  const GAME = location.hostname.startsWith("play.") ? "/" : "/play";
  const brand = document.getElementById("docs-brand");
  if (brand) brand.href = GAME;

  const back = document.getElementById("docs-back");
  if (back) {
    const ref = (() => {
      try {
        const r = document.referrer;
        if (r && new URL(r).origin === location.origin && !/\/docs(\/|$)/.test(new URL(r).pathname)) {
          return r;
        }
      } catch (e) {}
      return "/dashboard/";
    })();
    back.addEventListener("click", () => {
      location.href = ref;
    });
  }

  document.querySelectorAll(".docs-group-head").forEach((head) => {
    head.addEventListener("click", () => head.parentElement.classList.toggle("collapsed"));
  });

  // Same paint-palette icon and swatch table as pixl.js's picker - two
  // independent copies (docs pages don't load pixl.js), kept in sync by eye
  // with packages/theme/palette.json.
  const PALETTE_ICON = '<svg viewBox="0 0 16 16" fill="currentColor"><rect x="4" y="2" width="8" height="2"/><rect x="2" y="4" width="2" height="7"/><rect x="12" y="4" width="2" height="6"/><rect x="4" y="11" width="7" height="2"/><rect x="10" y="10" width="2" height="2"/><rect x="5" y="5" width="2" height="2"/><rect x="9" y="5" width="2" height="2"/><rect x="5" y="8" width="2" height="2"/></svg>';
  // Only one theme right now, so page.ts emits no picker markup and the block
  // below no-ops. Re-add a second entry here (and the markup in page.ts) to
  // bring the picker back.
  const THEMES = [
    { id: "light", label: "Pixl Paper", panel: "#f5eed2", gold: "#ec3750" },
  ];
  const themeBtn = document.getElementById("docs-theme-btn");
  const themeMenu = document.getElementById("docs-theme-menu");
  function setTheme(id) {
    document.documentElement.dataset.theme = id;
    try {
      localStorage.setItem("pixl_theme_v2", id);
    } catch (e) {}
    syncTheme();
  }
  function syncTheme() {
    if (!themeBtn || !themeMenu) return;
    const active = document.documentElement.dataset.theme || "light";
    themeBtn.innerHTML = PALETTE_ICON;
    themeBtn.setAttribute("aria-label", "Change theme");
    themeMenu.innerHTML = THEMES.map(
      (t) => `
      <button class="theme-opt${t.id === active ? " active" : ""}" type="button" data-theme-id="${t.id}">
        <span class="swatch" style="background:${t.panel};box-shadow:inset 0 0 0 2px ${t.gold}"></span>
        <span>${t.label}</span>
      </button>`,
    ).join("");
    themeMenu.querySelectorAll(".theme-opt").forEach((opt) => {
      opt.onclick = () => {
        setTheme(opt.dataset.themeId);
        themeMenu.hidden = true;
        themeBtn.setAttribute("aria-expanded", "false");
      };
    });
  }
  if (themeBtn && themeMenu) {
    themeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      themeMenu.hidden = !themeMenu.hidden;
      themeBtn.setAttribute("aria-expanded", String(!themeMenu.hidden));
    });
    document.addEventListener("click", (e) => {
      if (!themeMenu.hidden && !themeMenu.contains(e.target) && e.target !== themeBtn) {
        themeMenu.hidden = true;
        themeBtn.setAttribute("aria-expanded", "false");
      }
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && !themeMenu.hidden) {
        themeMenu.hidden = true;
        themeBtn.setAttribute("aria-expanded", "false");
      }
    });
    syncTheme();
  }

  const tocLinks = [...document.querySelectorAll(".docs-toc a")];
  tocLinks.forEach((a) =>
    a.addEventListener("click", (e) => {
      e.preventDefault();
      document.getElementById(a.dataset.h)?.scrollIntoView({ behavior: "smooth", block: "start" });
    }),
  );
  function markToc() {
    if (!tocLinks.length) return;
    let current = tocLinks[0].dataset.h;
    const atBottom =
      window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 4;
    if (atBottom) {
      current = tocLinks[tocLinks.length - 1].dataset.h;
    } else {
      for (const a of tocLinks) {
        const el = document.getElementById(a.dataset.h);
        if (el && el.getBoundingClientRect().top <= 96) current = a.dataset.h;
      }
    }
    tocLinks.forEach((a) => a.classList.toggle("active", a.dataset.h === current));
  }
  window.addEventListener("scroll", markToc, { passive: true });
  markToc();

  if (window.hljs) hljs.highlightAll();
  document.querySelectorAll("pre").forEach((pre) => {
    const btn = document.createElement("button");
    btn.className = "copy-btn";
    btn.type = "button";
    btn.textContent = "Copy";
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(pre.querySelector("code").textContent);
        btn.textContent = "Copied";
        btn.classList.add("copied");
        setTimeout(() => {
          btn.textContent = "Copy";
          btn.classList.remove("copied");
        }, 1600);
      } catch (e) {}
    });
    pre.appendChild(btn);
  });
})();
