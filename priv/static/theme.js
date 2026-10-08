// Tema light/dark. Vive en un archivo propio (y no inline en el layout) porque el CSP del router
// (`script-src 'self'`) bloquea los <script> inline. Se carga en <head>, sin defer, para fijar
// `data-theme` antes del primer paint.
(() => {
  const systemTheme = () => matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";

  const setTheme = (theme) => {
    if (theme === "system") {
      localStorage.removeItem("phx:theme");
      document.documentElement.setAttribute("data-theme", systemTheme());
      document.documentElement.setAttribute("data-theme-source", "system");
    } else {
      localStorage.setItem("phx:theme", theme);
      document.documentElement.setAttribute("data-theme", theme);
      document.documentElement.setAttribute("data-theme-source", "user");
    }
  };
  if (!document.documentElement.hasAttribute("data-theme")) {
    setTheme(localStorage.getItem("phx:theme") || "dark");
  }
  window.addEventListener("storage", (e) => e.key === "phx:theme" && setTheme(e.newValue || "system"));
  window.addEventListener("phx:set-theme", (e) => setTheme(e.target.dataset.phxTheme));

  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
    if (document.documentElement.getAttribute("data-theme-source") === "system") {
      document.documentElement.setAttribute("data-theme", systemTheme());
    }
  });
})();

(() => {
  document.addEventListener("click", (e) => {
    const btn = e.target.closest("#theme-toggle");
    if (!btn) return;

    const current = document.documentElement.getAttribute("data-theme");
    const next = current === "dark" ? "light" : "dark";
    const apply = () => {
      btn.dataset.phxTheme = next;
      btn.dispatchEvent(new CustomEvent("phx:set-theme", { bubbles: true }));
    };

    if (!document.startViewTransition) {
      apply();
      return;
    }

    const { clientX: x, clientY: y } = e;
    const radius = Math.hypot(
      Math.max(x, innerWidth - x),
      Math.max(y, innerHeight - y),
    );
    const root = document.documentElement.style;
    root.setProperty("--theme-toggle-x", `${x}px`);
    root.setProperty("--theme-toggle-y", `${y}px`);
    root.setProperty("--theme-toggle-radius", `${radius}px`);
    document.startViewTransition(apply);
  });
})();
