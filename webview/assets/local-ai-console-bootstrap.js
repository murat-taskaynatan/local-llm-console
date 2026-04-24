(() => {
  const SETTINGS_PATH = `/settings/general-settings`;
  const SESSION_STATE_PATH = `/__local-llm-console/state`;
  const SESSION_MODE_PATH = `/__local-llm-console/session-mode`;
  const SESSION_STATE_EVENT = `local-llm-console-state`;
  const ANNOUNCEMENT_PRIMARY_PATTERNS = [
    /introducing gpt-5(?:\.[0-9]+)?/i,
    /the most capable model for complex,\s*professional work,\s*coding and agentic workflows/i,
    /smarter,\s*faster,\s*and more reliable/i,
  ];
  const ANNOUNCEMENT_ACTION_PATTERNS = [
    /try gpt-5(?:\.[0-9]+)?(?:[- ]codex)? now/i,
    /continue with (?:the )?current model/i,
    /learn more/i,
  ];
  const ROOT_SELECTORS = [
    `[role="dialog"]`,
    `dialog`,
    `[aria-modal="true"]`,
    `[data-radix-popper-content-wrapper]`,
    `[data-radix-portal]`,
    `[data-state="open"]`,
    `[data-state="delayed-open"]`,
    `.fixed`,
    `.absolute`,
  ].join(`,`);

  function normalizeText(value) {
    return (value || ``).replace(/\s+/g, ` `).trim();
  }

  function isAnnouncementText(value) {
    const text = normalizeText(value);
    if (!text || text.length > 2400) {
      return false;
    }
    const hasPrimary = ANNOUNCEMENT_PRIMARY_PATTERNS.some((pattern) => pattern.test(text));
    const hasAction = ANNOUNCEMENT_ACTION_PATTERNS.some((pattern) => pattern.test(text));
    return hasPrimary && hasAction;
  }

  function currentWindowHostId() {
    try {
      return new URL(window.location.href).searchParams.get(`hostId`)?.trim() || ``;
    } catch {
      return ``;
    }
  }

  function currentWindowHasRemoteHost() {
    const hostId = currentWindowHostId().toLowerCase();
    return hostId.length > 0 && hostId !== `local`;
  }

  function openLocalSettings(section = `general-settings`) {
    const nextSection =
      typeof section === `string` && section.trim().length > 0 ? section.trim() : `general-settings`;
    const nextPath = `/settings/${nextSection}`;
    if (window.location.pathname === nextPath) {
      return;
    }
    window.history.pushState({}, ``, nextPath);
    window.dispatchEvent(new PopStateEvent(`popstate`));
  }

  function normalizeMode(value) {
    return value === `remote` ? `remote` : `local`;
  }

  function normalizeState(value) {
    const state = value && typeof value === `object` ? value : {};
    return {
      currentMode: currentWindowHasRemoteHost() ? `remote` : normalizeMode(state.currentMode),
      hasRemoteSettings: Boolean(state.hasRemoteSettings),
      remoteUrl:
        typeof state.remoteUrl === `string` && state.remoteUrl.trim().length > 0
          ? state.remoteUrl.trim()
          : ``,
      remoteTransport:
        typeof state.remoteTransport === `string` && state.remoteTransport.trim().length > 0
          ? state.remoteTransport.trim()
          : `tailscale-websocket`,
    };
  }

  function setSessionState(nextState) {
    const normalized = normalizeState(nextState);
    window.__localLLMConsoleState = normalized;
    window.dispatchEvent(
      new CustomEvent(SESSION_STATE_EVENT, {
        detail: normalized,
      }),
    );
    return normalized;
  }

  function getSessionState() {
    if (!window.__localLLMConsoleState) {
      window.__localLLMConsoleState = normalizeState({});
    }
    return window.__localLLMConsoleState;
  }

  function isRemoteConnected() {
    return getSessionState().currentMode === `remote` && currentWindowHasRemoteHost();
  }

  async function refreshSessionState() {
    if (window.location.protocol === `file:` || window.location.protocol === `app:`) {
      return getSessionState();
    }
    const response = await fetch(SESSION_STATE_PATH, {
      cache: `no-store`,
      headers: {
        Accept: `application/json`,
      },
    });
    if (!response.ok) {
      throw new Error(`Unable to read Local LLM Console session state.`);
    }
    const payload = await response.json();
    return setSessionState(payload);
  }

  async function switchSessionMode(mode) {
    if (window.location.protocol === `file:` || window.location.protocol === `app:`) {
      return setSessionState({
        ...getSessionState(),
        currentMode: currentWindowHasRemoteHost() ? `remote` : normalizeMode(mode),
      });
    }
    const response = await fetch(SESSION_MODE_PATH, {
      method: `POST`,
      headers: {
        Accept: `application/json`,
        "Content-Type": `application/json`,
      },
      body: JSON.stringify({ mode: normalizeMode(mode) }),
    });
    let payload = {};
    try {
      payload = await response.json();
    } catch (error) {
      payload = {};
    }
    if (!response.ok) {
      throw new Error(
        typeof payload.error === `string` && payload.error.trim().length > 0
          ? payload.error
          : `Unable to switch Local LLM Console session mode.`,
      );
    }
    return setSessionState({
      ...getSessionState(),
      ...payload,
      currentMode: currentWindowHasRemoteHost() ? `remote` : normalizeMode(mode),
    });
  }

  async function ensureCurrentSessionSwitchHelper() {
    if (typeof window.__localLLMConsoleSwitchCurrentSession === `function`) {
      return window.__localLLMConsoleSwitchCurrentSession;
    }
    try {
      await import(`./local-models-settings-Dt4h1YLM.js`);
    } catch (error) {
      console.error(error);
    }
    return typeof window.__localLLMConsoleSwitchCurrentSession === `function`
      ? window.__localLLMConsoleSwitchCurrentSession
      : null;
  }

  async function handleRemotePicker() {
    let state;
    try {
      state = await refreshSessionState();
    } catch (error) {
      state = getSessionState();
    }
    if (!state.hasRemoteSettings) {
      openLocalSettings(`remote-settings`);
      return { action: `configure`, state };
    }
    if (state.currentMode === `remote`) {
      return { action: `ready`, state };
    }
    const switchCurrentSession = await ensureCurrentSessionSwitchHelper();
    if (switchCurrentSession == null) {
      openLocalSettings(`remote-settings`);
      return { action: `configure`, state };
    }
    await switchCurrentSession(`remote`, { remoteUrl: state.remoteUrl });
    return { action: `switching`, state: { ...state, currentMode: `remote` } };
  }

  function findAnnouncementContainer(node) {
    let current = node instanceof Element ? node : node?.parentElement ?? null;
    while (current && current !== document.body) {
      if (current.matches(ROOT_SELECTORS)) {
        return current;
      }
      current = current.parentElement;
    }
    return node instanceof Element ? node : null;
  }

  function suppressAnnouncement(node) {
    const container = findAnnouncementContainer(node);
    if (!(container instanceof Element)) {
      return;
    }
    const target =
      container.closest(`[data-radix-portal]`) ??
      container.closest(`[data-radix-popper-content-wrapper]`) ??
      container;
    if (!(target instanceof Element) || target.dataset.localLlmConsoleSuppressed === `true`) {
      return;
    }
    target.dataset.localLlmConsoleSuppressed = `true`;
    target.style.setProperty(`display`, `none`, `important`);
    target.remove();
  }

  function scanNode(node) {
    if (!(node instanceof Element)) {
      return;
    }
    if (isAnnouncementText(node.textContent)) {
      suppressAnnouncement(node);
      return;
    }
    for (const candidate of node.querySelectorAll(ROOT_SELECTORS)) {
      if (isAnnouncementText(candidate.textContent)) {
        suppressAnnouncement(candidate);
      }
    }
  }

  function startObserver() {
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === `childList`) {
          for (const addedNode of mutation.addedNodes) {
            scanNode(addedNode);
          }
          continue;
        }
        if (mutation.type === `characterData`) {
          const parent = mutation.target.parentElement;
          if (parent && isAnnouncementText(parent.textContent)) {
            suppressAnnouncement(parent);
          }
        }
      }
    });

    scanNode(document.body);
    observer.observe(document.documentElement, {
      childList: true,
      characterData: true,
      subtree: true,
    });
    window.setTimeout(() => scanNode(document.body), 250);
    window.setTimeout(() => scanNode(document.body), 1000);
  }

  window.__openLocalSettings = openLocalSettings;
  window.__getLocalLLMConsoleState = getSessionState;
  window.__isLocalLLMConsoleRemoteConnected = isRemoteConnected;
  window.__refreshLocalLLMConsoleState = refreshSessionState;
  window.__switchLocalLLMConsoleMode = switchSessionMode;
  window.__handleLocalLLMConsoleRemotePicker = () =>
    handleRemotePicker().catch((error) => {
      console.error(error);
      openLocalSettings(`remote-settings`);
    });
  setSessionState(getSessionState());

  if (document.readyState === `loading`) {
    document.addEventListener(
      `DOMContentLoaded`,
      () => {
        startObserver();
        refreshSessionState().catch(() => {});
      },
      { once: true },
    );
  } else {
    startObserver();
    refreshSessionState().catch(() => {});
  }
})();
