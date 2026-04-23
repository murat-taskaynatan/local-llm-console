(() => {
  const SETTINGS_PATH = `/settings/general-settings`;
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

  function openLocalSettings() {
    if (window.location.pathname === SETTINGS_PATH) {
      return;
    }
    window.history.pushState({}, ``, SETTINGS_PATH);
    window.dispatchEvent(new PopStateEvent(`popstate`));
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

  if (document.readyState === `loading`) {
    document.addEventListener(`DOMContentLoaded`, startObserver, { once: true });
  } else {
    startObserver();
  }
})();
