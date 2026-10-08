// Onboarding, ayuda y demo guiada del playground. Vive en un archivo propio (y no inline en el
// template) porque el CSP del router (`script-src 'self'`) bloquea los <script> inline.
(() => {
  const ONBOARD_KEY = "cp:onboarded";
  const modal = document.getElementById("onboarding-modal");
  const helpModal = document.getElementById("help-modal");
  const callout = document.getElementById("demo-callout");
  const demoBtn = document.getElementById("guided-demo-btn");
  const demoLabel = document.getElementById("guided-demo-label");

  const wait = (ms) => new Promise((r) => setTimeout(r, ms));

  // Element.click() no existe en nodos SVG (el <g> de cada nodo del canvas),
  // asi que disparamos el MouseEvent a mano para que sirva con botones y con SVG.
  function fireClick(el) {
    el?.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
  }

  // El <select> de entrada de trafico y el <input type="range"> de RPS usan
  // phx-change, que LiveView escucha sobre el evento "change" nativo —
  // no alcanza con asignar .value.
  function fireChange(el, value) {
    if (!el) return;
    el.value = value;
    el.dispatchEvent(new Event("change", { bubbles: true, cancelable: true }));
  }

  function closeOnboarding() {
    modal.classList.add("hidden");
    localStorage.setItem(ONBOARD_KEY, "1");
  }

  if (!localStorage.getItem(ONBOARD_KEY)) {
    modal.classList.remove("hidden");
  }

  document.getElementById("onboarding-skip").addEventListener("click", closeOnboarding);
  document.getElementById("onboarding-start-demo").addEventListener("click", () => {
    closeOnboarding();
    runGuidedDemo();
  });

  const helpBtn = document.getElementById("help-open");
  if (helpBtn) helpBtn.addEventListener("click", () => helpModal.classList.remove("hidden"));
  document.getElementById("help-close").addEventListener("click", () => helpModal.classList.add("hidden"));
  helpModal.addEventListener("click", (e) => {
    if (e.target === helpModal) helpModal.classList.add("hidden");
  });

  const calloutStep = document.getElementById("demo-callout-step");
  const calloutText = document.getElementById("demo-callout-text");
  const skipBtn = document.getElementById("demo-skip");

  // callout es position:fixed -> las coordenadas son relativas al viewport,
  // no hace falta (ni corresponde) sumar window.scrollY. Ancho/alto se miden
  // ya visible (con el texto del paso puesto) porque w-[calc(100vw-24px)]
  // hace que el tamaño real dependa del viewport y del contenido.
  function positionCallout(target) {
    if (!target) return;
    const margin = 12;
    const rect = target.getBoundingClientRect();
    const calloutW = callout.offsetWidth;
    const calloutH = callout.offsetHeight;

    const left = Math.min(
      Math.max(margin, rect.left + rect.width / 2 - calloutW / 2),
      window.innerWidth - calloutW - margin,
    );

    let top = rect.bottom + 10;
    if (top + calloutH > window.innerHeight - margin) {
      top = rect.top - 10 - calloutH; // no entra abajo -> lo mostramos arriba
    }
    top = Math.max(margin, Math.min(top, window.innerHeight - calloutH - margin));

    callout.style.left = `${left}px`;
    callout.style.top = `${top}px`;
  }

  let calloutTarget = null;

  function showCallout(target, step, total, text) {
    calloutTarget = target;
    calloutStep.textContent = `Paso ${step}/${total}`;
    calloutText.textContent = text;
    callout.classList.remove("hidden");
    positionCallout(target);
  }

  function hideCallout() {
    callout.classList.add("hidden");
    calloutTarget = null;
  }

  window.addEventListener("resize", () => {
    if (calloutTarget) positionCallout(calloutTarget);
  });

  let demoRunning = false;
  let demoCancelled = false;

  // Cada paso explica ANTES de actuar (le da tiempo a leer), despues actua,
  // y deja el resultado a la vista un rato antes de pasar al siguiente paso.
  async function runStep({ target, step, total, text, before = 1400, action = null, after = 2600 }) {
    if (demoCancelled) return;
    showCallout(target, step, total, text);
    await wait(before);
    if (demoCancelled) return;
    if (action) action();
    await wait(after);
  }

  async function runGuidedDemo() {
    if (demoRunning) return;
    demoRunning = true;
    demoCancelled = false;
    demoBtn.disabled = true;
    demoLabel.textContent = "Corriendo demo…";
    skipBtn.classList.remove("hidden");

    const metricsTarget = document.getElementById("metrics-dl");
    const inspector = document.getElementById("inspector-panel");
    const total = 10;

    // Arranca siempre desde cero: si quedó Chaos Monkey prendido o tráfico
    // corriendo de una sesión anterior (propia o de otro visitante, el canvas
    // es compartido), la demo pisa todo antes del primer paso narrado.
    const chaosMonkeyBtn = document.querySelector('button[phx-click="toggle_chaos_monkey"]');
    if (chaosMonkeyBtn && chaosMonkeyBtn.classList.contains("btn-error")) {
      chaosMonkeyBtn.click();
    }
    const presetBtn = document.querySelector('button[phx-value-name="Monolith vs Microservices"]');
    if (presetBtn) fireClick(presetBtn);
    await wait(400);

    await runStep({
      target: metricsTarget,
      step: 1,
      total,
      text: "Esta es 'Monolith vs Microservices': dos arquitecturas equivalentes corriendo en paralelo. Vamos a romper cada una y comparar cómo aguantan.",
      before: 3200,
      after: 400,
    });

    await runStep({
      target: metricsTarget,
      step: 2,
      total,
      text: "Primero reiniciamos la topología en limpio: esto mata y vuelve a levantar todos los procesos de nodo.",
      before: 1200,
      action: () => fireClick(document.querySelector('button[phx-value-name="Monolith vs Microservices"]')),
      after: 2200,
    });

    await runStep({
      target: metricsTarget,
      step: 3,
      total,
      text: "Arrancamos tráfico simulado, entrando por el load balancer del monolito. Cada partícula es un paquete real recorriendo las conexiones.",
      before: 1400,
      action: () => {
        const startBtn = document.querySelector('button[phx-click="start_traffic"]');
        if (startBtn && !startBtn.disabled) startBtn.click();
      },
      after: 3400,
    });

    await runStep({
      target: metricsTarget,
      step: 4,
      total,
      text: "Vamos a elegir el nodo de API del monolito para intervenirlo. Un clic abre su Inspector, a la derecha.",
      before: 1400,
      action: () => fireClick(document.querySelector('[data-node-id="monolith-app"]')),
      after: 2000,
    });

    await runStep({
      target: inspector,
      step: 5,
      total,
      text: "Es un proceso real de Erlang/OTP. Cuando lo matemos, termina de verdad — y como es un Single Point of Failure, se lleva puesto todo lo que depende de él.",
      before: 2600,
      action: () => fireClick(document.querySelector('button[phx-click="kill_node"]')),
      after: 3400,
    });

    await runStep({
      target: metricsTarget,
      step: 6,
      total,
      text: "Proceso terminado. Mirá el ERROR%: sin ese único camino, todo el tráfico del monolito falla — no es una animación, es tráfico real sin adónde ir.",
      before: 0,
      after: 3200,
    });

    const entryForm = document.getElementById("entry-node-form");

    await runStep({
      target: entryForm,
      step: 7,
      total,
      text: "Probemos lo mismo en microservicios: cambiamos la entrada de tráfico a su load balancer, con 3 instancias de API corriendo en paralelo.",
      before: 1400,
      action: () => fireChange(document.getElementById("entry-node-select"), "micro-lb"),
      after: 3000,
    });

    await runStep({
      target: metricsTarget,
      step: 8,
      total,
      text: "Vamos a matar una de las tres réplicas de API, micro-svc-a — exactamente lo mismo que le hicimos al monolito.",
      before: 1400,
      action: () => fireClick(document.querySelector('[data-node-id="micro-svc-a"]')),
      after: 2000,
    });

    await runStep({
      target: inspector,
      step: 9,
      total,
      text: "Mismo proceso real, mismo botón. A diferencia del monolito, acá no hay un solo punto de falla.",
      before: 2600,
      action: () => fireClick(document.querySelector('button[phx-click="kill_node"]')),
      after: 3400,
    });

    await runStep({
      target: metricsTarget,
      step: 10,
      total,
      text: "Mirá el ERROR%: apenas se nota. Las otras dos instancias absorbieron el tráfico sin drama — esa es la diferencia entre un SPOF y una arquitectura redundante.",
      before: 0,
      after: 3600,
    });

    if (!demoCancelled) {
      // Deja todo como estaba antes de la demo: nodos revividos, trafico
      // pausado, RPS y entrada de trafico en su valor por defecto — para
      // que quien mire despues no se encuentre el canvas roto.
      fireClick(document.querySelector('[data-node-id="monolith-app"]'));
      await wait(300);
      fireClick(document.querySelector('button[phx-click="revive_node"]'));
      await wait(400);
      fireClick(document.querySelector('[data-node-id="micro-svc-a"]'));
      await wait(300);
      fireClick(document.querySelector('button[phx-click="revive_node"]'));
      await wait(400);

      const pauseBtn = document.querySelector('button[phx-click="pause_traffic"]');
      if (pauseBtn && !pauseBtn.disabled) pauseBtn.click();
      fireChange(document.getElementById("entry-node-select"), "monolith-lb");
      fireChange(document.getElementById("rps-input"), "5");
      fireClick(document.querySelector('button[phx-click="clear_selection"]'));

      showCallout(
        document.getElementById("guided-demo-btn"),
        total,
        total,
        "Repusimos los nodos y volvimos todo a como estaba. Ahora te toca a vos: seguí rompiendo cosas.",
      );
      await wait(3800);
    }

    hideCallout();
    skipBtn.classList.add("hidden");
    demoBtn.disabled = false;
    demoLabel.textContent = "Demo guiada (45s)";
    demoRunning = false;
  }

  skipBtn.addEventListener("click", () => {
    demoCancelled = true;
    hideCallout();
    skipBtn.classList.add("hidden");
    demoBtn.disabled = false;
    demoLabel.textContent = "Demo guiada (45s)";
    demoRunning = false;
  });

  demoBtn.addEventListener("click", runGuidedDemo);

  // Los presets built-in son fijos (no cambian en runtime), asi que alcanza con
  // engancharlos una vez al cargar la pagina en vez de un phx-hook.
  document.querySelectorAll(".copy-preset-link").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const url = `${location.origin}${location.pathname}?preset=${encodeURIComponent(btn.dataset.preset)}`;
      const icon = btn.querySelector("span");
      try {
        await navigator.clipboard.writeText(url);
        if (icon) {
          icon.classList.replace("hero-link", "hero-check");
          setTimeout(() => icon.classList.replace("hero-check", "hero-link"), 1200);
        }
      } catch {
        window.prompt("Copiá el link:", url);
      }
    });
  });
})();
