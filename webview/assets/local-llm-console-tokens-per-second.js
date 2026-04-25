(() => {
  const MESSAGE_SELECTOR = `div.group.flex.min-w-0.flex-col`;
  const MESSAGE_FALLBACK_SELECTORS = [
    `div.group.flex.min-w-0`,
    `div.group.min-w-0.flex-col`,
    `div.group.flex.flex-col`,
    `div.flex.min-w-0.flex-col`,
  ];
  const COMPLETE_SELECTOR = [
    `button[aria-label="Good response"]`,
    `button[aria-label="Bad response"]`,
    `button[aria-label="Fork from this point"]`,
  ].join(`,`);
  const STYLE_ID = `local-llm-console-tokens-per-second-style`;
  const LABEL_ATTR = `data-local-llm-console-tokens-per-second`;
  const RATE_ATTR = `data-local-llm-console-token-rate`;
  const IDLE_FINALIZE_MS = 1800;
  const MIN_ELAPSED_SECONDS = 0.25;
  const records = new WeakMap();
  let pendingScan = false;

  function installStyle() {
    if (document.getElementById(STYLE_ID)) {
      return;
    }
    const style = document.createElement(`style`);
    style.id = STYLE_ID;
    style.textContent = `
      .local-llm-console-tokens-per-second-badge {
        display: block;
        margin-top: 0.35rem;
        margin-right: auto;
        color: var(--text-token-description-foreground, rgb(142 142 160));
        font-size: 0.7rem;
        line-height: 1rem;
        font-variant-numeric: tabular-nums;
        pointer-events: none;
        white-space: nowrap;
      }
    `;
    document.head.appendChild(style);
  }

  function now() {
    return typeof performance !== `undefined` && typeof performance.now === `function`
      ? performance.now()
      : Date.now();
  }

  function normalizeText(value) {
    return (value || ``).replace(/\s+/g, ` `).trim();
  }

  function estimateTokens(value) {
    const text = normalizeText(value);
    if (!text) {
      return 0;
    }
    return Math.max(1, Math.ceil(text.length / 4));
  }

  function formatRate(value) {
    if (!Number.isFinite(value) || value <= 0) {
      return null;
    }
    return value >= 10 ? String(Math.round(value)) : String(Math.round(value * 10) / 10);
  }

  function matchesMessageSelector(element) {
    return element.matches(MESSAGE_SELECTOR) || MESSAGE_FALLBACK_SELECTORS.some((selector) => element.matches(selector));
  }

  function isAssistantMessageContainer(element) {
    if (!(element instanceof HTMLElement)) {
      return false;
    }
    if (!matchesMessageSelector(element)) {
      return false;
    }
    if (element.closest(`[data-local-llm-console-ignore-tps="true"]`)) {
      return false;
    }
    const content = getContentElement(element);
    if (!(content instanceof HTMLElement)) {
      return false;
    }
    return content.textContent?.trim().length > 0;
  }

  function findMessageContainer(node) {
    const element =
      node instanceof Element ? node : node?.parentElement instanceof Element ? node.parentElement : null;
    if (!(element instanceof Element)) {
      return null;
    }
    return (
      element.closest(MESSAGE_SELECTOR) ??
      MESSAGE_FALLBACK_SELECTORS.map((selector) => element.closest(selector)).find((candidate) => candidate instanceof HTMLElement) ??
      null
    );
  }

  function getContentElement(container) {
    for (const child of container.children) {
      if (!(child instanceof HTMLElement)) {
        continue;
      }
      if (child.matches(`.mt-3.flex.h-5`)) {
        continue;
      }
      return child;
    }
    return null;
  }

  function hasCompleted(container) {
    return container.querySelector(COMPLETE_SELECTOR) != null || container.querySelector(`.mt-3.flex.h-5`) != null;
  }

  function setLabel(container, label) {
    const content = getContentElement(container);
    if (!(content instanceof HTMLElement)) {
      return;
    }
    const existing = container.querySelector(`:scope > [${RATE_ATTR}]`);
    const footer = container.querySelector(`:scope > .mt-3.flex.h-5`);
    if (label == null) {
      content.removeAttribute(LABEL_ATTR);
      content.removeAttribute(`data-local-llm-console-tokens-complete`);
      existing?.remove();
      return;
    }
    content.setAttribute(LABEL_ATTR, label);
    content.setAttribute(`data-local-llm-console-tokens-complete`, `true`);
    content.title = `Estimated from streamed assistant text in this window.`;
    let rateNode = existing;
    if (!(rateNode instanceof HTMLElement)) {
      rateNode = document.createElement(`span`);
      rateNode.setAttribute(RATE_ATTR, `true`);
      rateNode.className = `local-llm-console-tokens-per-second-badge`;
      rateNode.setAttribute(`aria-hidden`, `true`);
      if (footer instanceof HTMLElement) {
        footer.insertAdjacentElement(`beforebegin`, rateNode);
      } else {
        content.insertAdjacentElement(`afterend`, rateNode);
      }
    } else if (footer instanceof HTMLElement && rateNode.nextElementSibling !== footer) {
      footer.insertAdjacentElement(`beforebegin`, rateNode);
    } else if (!(footer instanceof HTMLElement) && rateNode.previousElementSibling !== content) {
      content.insertAdjacentElement(`afterend`, rateNode);
    }
    rateNode.textContent = label;
  }

  function renderRecord(container, record, completed) {
    const elapsedSeconds = Math.max(((record.finishedAtMs ?? now()) - record.startedAtMs) / 1000, 0);
    if (elapsedSeconds < MIN_ELAPSED_SECONDS || record.tokenCount <= 0) {
      setLabel(container, null);
      return;
    }
    const rate = formatRate(record.tokenCount / Math.max(elapsedSeconds, MIN_ELAPSED_SECONDS));
    if (rate == null) {
      setLabel(container, null);
      return;
    }
    setLabel(container, `~${rate} tok/s`);
    const content = getContentElement(container);
    content?.setAttribute(`data-local-llm-console-tokens-complete`, completed ? `true` : `false`);
  }

  function finalizeAfterIdle(container, record, snapshot) {
    window.clearTimeout(record.idleTimer);
    record.idleTimer = window.setTimeout(() => {
      const current = records.get(container);
      if (current !== record || current.finishedAtMs != null) {
        return;
      }
      const content = getContentElement(container);
      const currentText = normalizeText(content?.innerText || content?.textContent || ``);
      if (currentText !== snapshot) {
        return;
      }
      current.finishedAtMs = current.lastUpdateMs ?? now();
      renderRecord(container, current, true);
    }, IDLE_FINALIZE_MS);
  }

  function updateContainer(container) {
    if (!isAssistantMessageContainer(container)) {
      return;
    }

    const content = getContentElement(container);
    const text = normalizeText(content?.innerText || content?.textContent || ``);
    const tokenCount = estimateTokens(text);
    const completed = hasCompleted(container);
    let record = records.get(container);

    if (!record) {
      if (tokenCount === 0) {
        return;
      }
      record = {
        startedAtMs: now(),
        finishedAtMs: null,
        tokenCount,
        lastText: text,
        lastUpdateMs: now(),
        idleTimer: 0,
      };
      records.set(container, record);
      finalizeAfterIdle(container, record, text);
      if (completed) {
        return;
      }
      return;
    }

    if (tokenCount === 0) {
      window.clearTimeout(record.idleTimer);
      records.delete(container);
      setLabel(container, null);
      return;
    }

    if (text !== record.lastText) {
      record.lastText = text;
      record.tokenCount = tokenCount;
      record.lastUpdateMs = now();
      record.finishedAtMs = null;
      finalizeAfterIdle(container, record, text);
    }

    if (completed && record.finishedAtMs == null) {
      window.clearTimeout(record.idleTimer);
      record.finishedAtMs = record.lastUpdateMs ?? now();
    }

    renderRecord(container, record, completed || record.finishedAtMs != null);
  }

  function scan(root = document) {
    const containers = new Set();
    if (root instanceof Element) {
      if (isAssistantMessageContainer(root)) {
        containers.add(root);
      }
      const nearest = findMessageContainer(root);
      if (nearest instanceof HTMLElement) {
        containers.add(nearest);
      }
      const selectors = [MESSAGE_SELECTOR, ...MESSAGE_FALLBACK_SELECTORS];
      selectors.forEach((selector) => {
        root.querySelectorAll?.(selector).forEach((element) => {
          if (element instanceof HTMLElement) {
            containers.add(element);
          }
        });
      });
    } else {
      const selectors = [MESSAGE_SELECTOR, ...MESSAGE_FALLBACK_SELECTORS];
      selectors.forEach((selector) => {
        document.querySelectorAll(selector).forEach((element) => {
          if (element instanceof HTMLElement) {
            containers.add(element);
          }
        });
      });
    }
    containers.forEach(updateContainer);
  }

  function scheduleScan(root) {
    if (pendingScan) {
      return;
    }
    pendingScan = true;
    window.requestAnimationFrame(() => {
      pendingScan = false;
      scan(document);
    });
  }

  function start() {
    installStyle();
    const observer = new MutationObserver((mutations) => {
      let root = null;
      for (const mutation of mutations) {
        if (mutation.target instanceof Element) {
          root = findMessageContainer(mutation.target) ?? root;
        }
        for (const addedNode of mutation.addedNodes) {
          if (addedNode instanceof Element) {
            root = findMessageContainer(addedNode) ?? addedNode;
          }
        }
      }
      scheduleScan(root ?? document);
    });

    scan(document);
    observer.observe(document.documentElement, {
      childList: true,
      characterData: true,
      subtree: true,
    });
  }

  if (document.readyState === `loading`) {
    document.addEventListener(`DOMContentLoaded`, start, { once: true });
  } else {
    start();
  }
})();
