import { s as e } from "./chunk-Bj-mKKzh.js";
import { t as n } from "./react-BE0_fAZJ.js";
import { t as r } from "./jsx-runtime-ebkFq_df.js";
import { t as i } from "./clsx-DQfH8mAl.js";
import { r as hostBus } from "./logger-BJWlfVIC.js";
import { t as s } from "./settings-content-layout-DQIQ2vPn.js";
import { n as c } from "./settings-row-BG-yYlW7.js";
import { n as l } from "./chevron-Oo-xHR0X.js";
import { i as q, n as H, t as R } from "./check-md-YtZX6wSV.js";
import { u as u, y as d } from "./config-queries-jUrDLWnn.js";
import { t as G } from "./settings-shared-DkvLL00j.js";
import { o as Y } from "./use-model-settings-ldiRRtPt.js";
import { t as X } from "./send-app-server-request-BTldVjKF.js";

var p = e(n(), 1),
  m = r(),
  g = [
    { value: `ollama`, label: `Ollama` },
    { value: `lmstudio`, label: `LM Studio` },
    { value: `codex`, label: `Codex Cloud` },
  ],
  j = [
    { value: `off`, label: `Off` },
    { value: `on`, label: `On` },
  ],
  A = [
    { value: `low`, label: `Low` },
    { value: `medium`, label: `Medium` },
    { value: `high`, label: `High` },
    { value: `xhigh`, label: `XHigh` },
  ],
  J = [
    { value: `local`, label: `Work locally` },
    { value: `remote`, label: `Connect to remote host` },
  ],
  P = [`gpt-oss:120b`, `qwen3.5:9.7b`, `qwen3.5:122b`],
  O = [`gpt-5.4`],
  $ = `codex-managed`,
  ee = `tailscale-websocket`;

function v(e, t = ``, n = ``) {
  return typeof e == `string` && e.trim().length > 0 ? e.trim() : t || n;
}

function b(e) {
  return e === `remote` ? `remote` : `local`;
}

function N(e) {
  return e === ee || e === `tailscale` ? ee : ee;
}

function x(e) {
  return e === !0 || e === `true` || e === `on` ? `on` : `off`;
}

function z(e) {
  return e === `lmstudio`
    ? `lmstudio`
    : e === `codex` || e === `openai`
      ? `codex`
      : `ollama`;
}

function B(e) {
  return z(e) === `codex` ? O : P;
}

function Q(e) {
  return z(e) === `codex` ? `gpt-5.4` : `gpt-oss:120b`;
}

function iee(e) {
  return z(e) !== `codex`;
}

function deriveLocalCatalogPath(e, t = ``) {
  let n = v(t, ``);
  if (n.length > 0) return n;
  let r = v(e, ``).replace(/\\/g, `/`);
  if (!r.endsWith(`/config.toml`)) return ``;
  let i = r.slice(0, -`/config.toml`.length),
    a = i.lastIndexOf(`/`);
  if (a <= 0) return ``;
  let o = i.slice(0, a),
    s = i.slice(a + 1);
  return s.length === 0 ? `` : `${o}/${s}-models.json`;
}

function K(e, t) {
  let n = v(t, ``),
    r = B(e),
    i = z(e) === `codex` ? P : O;
  return n.length === 0
    ? Q(e)
    : r.includes(n)
      ? n
      : i.includes(n)
        ? Q(e)
        : n;
}

function S(e, t = `443`) {
  if (typeof e == `number` && Number.isInteger(e) && e > 0) return String(e);
  if (typeof e == `string`) {
    let n = e.trim();
    if (/^[0-9]+$/.test(n) && Number.parseInt(n, 10) > 0) return n;
  }
  return t;
}

function stripWebsocketUrlScheme(e, t = ``) {
  let n = v(e, t);
  return n.replace(/^wss?:\/\//i, ``);
}

function C(e) {
  let t = z(
    v(
      e?.local_llm_console_provider,
      e?.model_provider,
      v(e?.oss_provider, `ollama`),
    ),
  );
  return {
    launchMode: `local`,
    provider: t,
    model: K(t, e?.model),
    reasoning: v(e?.model_reasoning_effort, `medium`),
    catalogPath: v(e?.model_catalog_json, ``),
    remoteTransport: N(e?.local_llm_console_remote_transport),
    remoteUrl: stripWebsocketUrlScheme(e?.local_llm_console_remote_url, ``),
    remoteAuthTokenEnv: v(e?.local_llm_console_remote_auth_token_env, ``),
    hostMode: x(e?.local_llm_console_host_enabled),
    hostTransport: N(e?.local_llm_console_host_transport),
    hostListenUrl: stripWebsocketUrlScheme(
      e?.local_llm_console_host_listen_url,
      `127.0.0.1:8765`,
    ),
    hostHttpsPort: S(e?.local_llm_console_host_https_port),
  };
}

function L(e) {
  return JSON.stringify(e);
}

function T(e, t) {
  let n = B(e).map((e) => ({ value: e, label: e }));
  return t != null && t.length > 0 && !B(e).includes(t)
    ? [{ value: t, label: `${t} (current)` }, ...n]
    : n;
}

function readLocalLlmConsoleSessionState() {
  if (
    typeof window === `undefined` ||
    typeof window.__getLocalLLMConsoleState !== `function`
  )
    return null;
  return window.__getLocalLLMConsoleState();
}

async function refreshLocalLlmConsoleSessionState() {
  if (
    typeof window === `undefined` ||
    typeof window.__refreshLocalLLMConsoleState !== `function`
  )
    return null;
  return window.__refreshLocalLLMConsoleState();
}

async function switchLocalLlmConsoleSessionMode(e, t) {
  if (
    typeof window !== `undefined` &&
    typeof window.__localLLMConsoleSwitchCurrentSession === `function`
  )
    return window.__localLLMConsoleSwitchCurrentSession(e, t);
  if (
    typeof window === `undefined` ||
    typeof window.__switchLocalLLMConsoleMode !== `function`
  )
    throw new Error(`Local session controls are unavailable.`);
  return window.__switchLocalLLMConsoleMode(e);
}

async function applyLocalLlmConsoleHostService(e = `reload`) {
  let t;
  try {
    t = await fetch(`/__local-llm-console/host-service`, {
      method: `POST`,
      headers: { "Content-Type": `application/json` },
      body: JSON.stringify({ action: e }),
    });
  } catch (t) {
    if (typeof window !== `undefined` && window.location.protocol === `file:`)
      return { ok: !0, skipped: !0, action: e };
    throw t;
  }
  let n = null;
  try {
    n = await t.json();
  } catch {}
  if (!t.ok)
    throw new Error(
      typeof (n == null ? void 0 : n.error) == `string` && n.error.trim().length > 0
        ? n.error
        : `Unable to apply host settings immediately.`,
    );
  return n;
}

function formatLocalLlmConsoleSessionLabel(e) {
  return e === `remote` ? `Connected to remote host` : `Working locally`;
}

async function sendLocalLlmConsoleRequest(e, t) {
  return X(e, t === void 0 ? void 0 : { params: t });
}

async function restartLocalLlmConsoleAppServer(e = {}) {
  let t = isRemoteSessionHostId(v(e.hostId, ``)) ? v(e.hostId, ``) : `local`,
    n = Date.now() + (typeof e.timeoutMs == `number` && e.timeoutMs > 0 ? e.timeoutMs : 15000),
    r = null;
  hostBus.dispatchMessage(`codex-app-server-restart`, { hostId: t });
  await new Promise((e) => window.setTimeout(e, 400));
  for (; Date.now() < n; ) {
    try {
      let n = await sendLocalLlmConsoleRequest(`read-config`, {
          hostId: t,
          includeLayers: !1,
          cwd: null,
        }),
        r = C(n?.config ?? {});
      if (
        (e.provider == null || r.provider === z(e.provider)) &&
        (e.model == null || r.model === K(e.provider ?? r.provider, e.model)) &&
        (e.reasoning == null || r.reasoning === e.reasoning)
      )
        return r;
    } catch (e) {
      r = e;
    }
    await new Promise((e) => window.setTimeout(e, 500));
  }
  throw new Error(
    r instanceof Error && r.message.trim().length > 0
      ? `Timed out restarting the local session: ${r.message}`
      : `Timed out restarting the local session.`,
  );
}

function normalizeRemoteSessionUrl(e) {
  let t = v(e, ``);
  if (t.length === 0) return ``;
  /^[a-zA-Z][a-zA-Z\d+\-.]*:\/\//.test(t) || (t = `wss://${t}`);
  let n;
  try {
    n = new URL(t);
  } catch {
    throw new Error(`Tailscale server URL is invalid.`);
  }
  if (n.protocol !== `ws:` && n.protocol !== `wss:`)
    throw new Error(`Tailscale server URL is invalid.`);
  return n.toString();
}

function normalizeHostListenUrl(e) {
  let t = v(e, ``);
  if (t.length === 0) return ``;
  /^[a-zA-Z][a-zA-Z\d+\-.]*:\/\//.test(t) || (t = `ws://${t}`);
  let n;
  try {
    n = new URL(t);
  } catch {
    throw new Error(`Host listen URL is invalid.`);
  }
  if (n.protocol !== `ws:` && n.protocol !== `wss:`)
    throw new Error(`Host listen URL is invalid.`);
  return n.toString();
}

function hasValidRemoteHostUrl(e) {
  try {
    let n = new URL(normalizeRemoteSessionUrl(e)),
      t = n.hostname.trim().toLowerCase();
    return (
      t.length > 0 &&
      ![`yours.net`, `your-host.tailnet.ts.net`].includes(t) &&
      n.protocol === `wss:` &&
      t.endsWith(`.ts.net`)
    );
  } catch {
    return !1;
  }
}

function getRemoteSessionHostId(e) {
  let t = normalizeRemoteSessionUrl(e);
  return `local-llm-console-remote:${encodeURIComponent(t.toLowerCase())}`;
}

function getCurrentSessionHostId() {
  if (typeof window === `undefined`) return ``;
  try {
    return v(new URL(window.location.href).searchParams.get(`hostId`), ``);
  } catch {
    return ``;
  }
}

function getCurrentConfigHostId() {
  let e = getCurrentSessionHostId();
  return isRemoteSessionHostId(e) ? e : `local`;
}

function extractLocalLlmConsoleConfigFilePath(e) {
  if (typeof e != `object` || !e) return null;
  if (typeof e.file == `string` && e.file.trim().length > 0) return e.file.trim();
  if (
    e.type === `project` &&
    typeof e.dotCodexFolder == `string` &&
    e.dotCodexFolder.trim().length > 0
  )
    return `${e.dotCodexFolder.trim().replace(/\/+$/, ``)}/config.toml`;
  return null;
}

function getLocalLlmConsoleConfigWriteTarget(e) {
  let t = Array.isArray(e?.layers) ? e.layers : [],
    n = t.find((e) => e?.name?.type === `user`) ?? t[0] ?? null;
  return n == null
    ? { filePath: null, expectedVersion: null }
    : {
        filePath: extractLocalLlmConsoleConfigFilePath(n.name) ?? null,
        expectedVersion: n.version ?? null,
      };
}

function isLocalLlmConsoleConfigVersionConflict(e) {
  let t =
    e instanceof Error
      ? e.message
      : typeof e == `string`
        ? e
        : typeof e == `object` && e
          ? JSON.stringify(e)
          : ``;
  return (
    typeof t == `string` &&
    (t.includes(`configVersionConflict`) ||
      t.includes(`Configuration was modified since last read`))
  );
}

function isRemoteSessionHostId(e) {
  let t = v(e, ``).toLowerCase();
  return t.length > 0 && t !== `local`;
}

function isCurrentRemoteSessionConnected() {
  if (
    typeof window !== `undefined` &&
    typeof window.__isLocalLLMConsoleRemoteConnected === `function`
  )
    return window.__isLocalLLMConsoleRemoteConnected() === !0;
  return isRemoteSessionHostId(getCurrentSessionHostId());
}

function buildRemoteSessionRecord(e) {
  let t = normalizeRemoteSessionUrl(e),
    n = new URL(t),
    r = n.hostname.trim() || `remote-host`,
    i = n.port.trim();
  return {
    hostId: getRemoteSessionHostId(t),
    displayName: `Remote host`,
    source: $,
    autoConnect: !0,
    sshAlias: null,
    sshHost: r,
    sshPort: i.length > 0 ? Number.parseInt(i, 10) : null,
    identity: null,
    connectionType: ee,
    websocketUrl: t,
  };
}

async function loadManagedRemoteSessionConnections() {
  let e = await sendLocalLlmConsoleRequest(`refresh-remote-connections`);
  let t = e?.remoteConnections;
  return (Array.isArray(t) ? t : []).filter((e) => e?.source === $);
}

function mergeManagedRemoteSessionConnections(e, t) {
  let n = Array.isArray(e) ? e : [];
  return [...n.filter((e) => e.hostId !== t.hostId && e.connectionType !== ee), t];
}

function getCurrentSessionPath() {
  if (typeof window === `undefined`) return `/`;
  let e = window.location.pathname;
  return e.startsWith(`/settings`) ? e : `/`;
}

function reloadCurrentSessionForHost(e) {
  if (typeof window === `undefined`) return;
  let t = new URL(window.location.href);
  t.pathname = getCurrentSessionPath();
  e ? t.searchParams.set(`hostId`, e) : t.searchParams.delete(`hostId`);
  window.location.assign(t.toString());
}

async function switchLocalLlmConsoleCurrentSession(e, t = {}) {
  let n = b(e);
  if (n === `remote`) {
    let r = v(t.remoteUrl, readLocalLlmConsoleSessionState()?.remoteUrl, ``);
    if (!hasValidRemoteHostUrl(r))
      throw new Error(`Please enter a valid remote host.`);
    let e = buildRemoteSessionRecord(r),
      n = mergeManagedRemoteSessionConnections(
        await loadManagedRemoteSessionConnections(),
        e,
      ),
      a = await sendLocalLlmConsoleRequest(
        `save-codex-managed-remote-ssh-connections`,
        {
          remoteConnections: n,
        },
      );
    a?.remoteConnections;
    let i = await sendLocalLlmConsoleRequest(`set-remote-connection-auto-connect`, {
      hostId: e.hostId,
      autoConnect: !0,
    });
    if (typeof i?.errorMessage == `string` && i.errorMessage.trim().length > 0)
      throw new Error(i.errorMessage.trim());
    if (i?.state != null && i.state !== `connected`)
      throw new Error(`Unable to connect to the remote host.`);
    reloadCurrentSessionForHost(e.hostId);
    return e;
  }
  let r = v(t.hostId, getCurrentSessionHostId(), ``);
  if (r.length > 0) {
    let e = await sendLocalLlmConsoleRequest(`set-remote-connection-auto-connect`, {
      hostId: r,
      autoConnect: !1,
    });
    if (
      typeof e?.errorMessage == `string` &&
      e.errorMessage.trim().length > 0 &&
      e?.state !== `disconnected`
    )
      throw new Error(e.errorMessage.trim());
  }
  reloadCurrentSessionForHost(``);
  return null;
}

if (typeof window !== `undefined`) {
  window.__localLLMConsoleSwitchCurrentSession = switchLocalLlmConsoleCurrentSession;
}

function localSignature(e) {
  return L({
    provider: e.provider,
    model: e.model,
    reasoning: e.reasoning,
    catalogPath: e.catalogPath,
  });
}

function remoteSignature(e) {
  return L({
    launchMode: e.launchMode,
    remoteUrl: e.remoteUrl,
    remoteAuthTokenEnv: e.remoteAuthTokenEnv,
    hostMode: e.hostMode,
    hostListenUrl: e.hostListenUrl,
    hostHttpsPort: e.hostHttpsPort,
  });
}

function M(e) {
  let t =
    e.tone === `error`
      ? `border-token-error-foreground/20 bg-token-charts-red/10 text-token-error-foreground`
      : e.tone === `success`
        ? `border-token-charts-green/20 bg-token-charts-green/10 text-token-charts-green`
        : `border-token-border bg-token-foreground/5 text-token-text-secondary`;
  return (0, m.jsx)(`div`, {
    className: i(`rounded-lg border px-3 py-2 text-sm`, t),
    children: e.text,
  });
}

function k(e) {
  return (0, m.jsx)(`input`, {
    className: `w-full rounded-md border border-token-input-border bg-token-input-background px-2.5 py-1.5 text-sm text-token-input-foreground outline-none`,
    ...e,
  });
}

function F(e) {
  let {
      value: t,
      options: n,
      onChange: r,
      disabled: a = !1,
      ariaLabel: o,
      menuClassName: s = `w-[28rem] max-w-[calc(100vw-2rem)] space-y-1`,
      triggerClassName: l = `h-9 !w-[28rem] max-w-full`,
    } = e,
    c = n.find((e) => e.value === t) ?? n[0] ?? { value: t, label: t };
  return (0, m.jsx)(H, {
    align: `end`,
    disabled: a,
    triggerButton: (0, m.jsx)(G, {
      "aria-label": o,
      disabled: a,
      className: l,
      children: (0, m.jsx)(`span`, {
        className: `truncate text-sm`,
        children: c.label,
      }),
    }),
    children: (0, m.jsx)(`div`, {
      className: s,
      children: n.map((e) =>
        (0, m.jsx)(
          q.Item,
          {
            disabled: a,
            onSelect: () => {
              r(e.value);
            },
            RightIcon: e.value === t ? R : void 0,
            children: (0, m.jsx)(`span`, {
              className: `truncate text-sm`,
              children: e.label,
            }),
          },
          e.value,
        ),
      ),
    }),
  });
}

function tileStyle(e) {
  let t = {
    backgroundColor: `var(--color-background-panel, var(--color-token-bg-fog))`,
  };
  switch (e) {
    case `top`:
      return {
        ...t,
        borderTopLeftRadius: `0.5rem`,
        borderTopRightRadius: `0.5rem`,
        borderBottomLeftRadius: 0,
        borderBottomRightRadius: 0,
      };
    case `middle`:
      return { ...t, borderRadius: 0, borderTopWidth: 0 };
    case `bottom`:
      return {
        ...t,
        borderTopLeftRadius: 0,
        borderTopRightRadius: 0,
        borderBottomLeftRadius: `0.5rem`,
        borderBottomRightRadius: `0.5rem`,
        borderTopWidth: 0,
      };
    default:
      return { ...t, borderRadius: `0.5rem` };
  }
}

function TileGroup(e) {
  let { position: t = `single`, children: n } = e;
  return (0, m.jsx)(`div`, {
    className: `border-token-border flex flex-col divide-y-[0.5px] divide-token-border border`,
    style: tileStyle(t),
    children: n,
  });
}

function RuntimeSettingsContent(props = {}) {
  let { embedded: O = !1, section: ee = `local` } = props,
    te = ee === `remote` ? `remote` : `local`,
    ne = te === `remote`,
    { data: e, isLoading: n, refetch: r } = d(),
    i = u(),
    t = (0, p.useMemo)(() => C(e?.config), [
      e?.config?.local_llm_console_mode,
      e?.config?.model_provider,
      e?.config?.oss_provider,
      e?.config?.model,
      e?.config?.model_reasoning_effort,
      e?.config?.model_catalog_json,
      e?.config?.local_llm_console_remote_transport,
      e?.config?.local_llm_console_remote_url,
      e?.config?.local_llm_console_remote_auth_token_env,
      e?.config?.local_llm_console_host_enabled,
      e?.config?.local_llm_console_host_transport,
      e?.config?.local_llm_console_host_listen_url,
      e?.config?.local_llm_console_host_https_port,
    ]),
    [w, E] = (0, p.useState)(t),
    [D, U] = (0, p.useState)(null),
    [re, ie] = (0, p.useState)(() => {
      let e = readLocalLlmConsoleSessionState();
      return {
        currentMode: isCurrentRemoteSessionConnected() ? `remote` : `local`,
        hasRemoteSettings: Boolean(e?.hasRemoteSettings) || t.remoteUrl.trim().length > 0,
        remoteUrl: v(e?.remoteUrl, t.remoteUrl),
      };
    }),
    [connectionChoice, setConnectionChoice] = (0, p.useState)(() =>
      isCurrentRemoteSessionConnected() ? `remote` : `local`,
    ),
    [ae, oe] = (0, p.useState)(null),
    se = e?.configWriteTarget?.filePath ?? ``,
    ce = e?.configWriteTarget?.expectedVersion ?? null,
    ye = (0, p.useMemo)(
      () => ({ ...t, catalogPath: deriveLocalCatalogPath(se, t.catalogPath) }),
      [se, t.catalogPath, L(t)],
    ),
    le = (0, p.useMemo)(() => T(w.provider, w.model), [w.provider, w.model]),
    ue = localSignature(ye) !== localSignature(w),
    de = remoteSignature(ye) !== remoteSignature(w),
    fe = ne ? de : ue,
    pe =
      w.provider.trim().length === 0 ||
      w.model.trim().length === 0 ||
      w.reasoning.trim().length === 0 ||
      (iee(w.provider) && w.catalogPath.trim().length === 0),
    me = !hasValidRemoteHostUrl(w.remoteUrl),
    he =
      w.hostListenUrl.trim().length === 0 ||
      !/^[0-9]+$/.test(w.hostHttpsPort.trim()) ||
      Number.parseInt(w.hostHttpsPort.trim(), 10) <= 0,
    qe = isCurrentRemoteSessionConnected(),
    _e = qe ? `remote` : `local`,
    ve = hasValidRemoteHostUrl(w.remoteUrl),
    persistentHostStatus = w.hostMode === `on` && !he && D == null,
    be = ne
      ? (_e === `remote` && me) || (w.hostMode === `on` && he)
      : pe,
    xe = async (e, n = {}) => {
      let W = n.nextState ?? w,
        K = n.hostAction ?? `reload`,
        isRemoteScope = n.scope === `remote`,
        a = W.provider.trim(),
        providerValue = z(a) === `codex` ? `openai` : a,
        o = W.model.trim(),
        s = W.reasoning.trim(),
        c = W.catalogPath.trim(),
        includeCatalogPathEdit = z(a) !== `codex`,
        l = `tailscale`,
        q = W.remoteUrl.trim(),
        H = W.remoteAuthTokenEnv.trim(),
        R = W.hostMode === `on`,
        G = `tailscale`,
        Y = R ? normalizeHostListenUrl(W.hostListenUrl) : v(W.hostListenUrl, ``),
        V = W.hostHttpsPort.trim(),
        I = Number.parseInt(V, 10);
      if (
        !isRemoteScope &&
        (a.length === 0 ||
          o.length === 0 ||
          s.length === 0 ||
          (iee(a) && c.length === 0))
      ) {
        U({
          tone: `error`,
          text: iee(a)
            ? `Provider, model, reasoning effort, and catalog path are all required for local settings.`
            : `Provider, model, and reasoning effort are all required for Codex Cloud settings.`,
        });
        return !1;
      }
      if (isRemoteScope && e === `remote` && !hasValidRemoteHostUrl(q)) {
        U({
          tone: `error`,
          text: `Please enter a valid remote host.`,
        });
        return !1;
      }
      if (
        isRemoteScope &&
        R &&
        (Y.length === 0 ||
          !/^[0-9]+$/.test(V) ||
          !Number.isInteger(I) ||
          I <= 0)
      ) {
        U({
          tone: `error`,
          text: `Host mode requires a listen URL and a valid Tailscale HTTPS port.`,
        });
        return !1;
      }
      U({
        tone: `info`,
        text: n.savingText ?? `Saving runtime configuration...`,
      });
      try {
        let edits = [
          { keyPath: `local_llm_console_provider`, value: a },
          { keyPath: `model_provider`, value: providerValue },
          { keyPath: `oss_provider`, value: providerValue },
          { keyPath: `model`, value: o },
          { keyPath: `model_reasoning_effort`, value: s },
          { keyPath: `local_llm_console_mode`, value: `local` },
          {
            keyPath: `local_llm_console_remote_transport`,
            value: l,
          },
          { keyPath: `local_llm_console_remote_url`, value: q },
          {
            keyPath: `local_llm_console_remote_auth_token_env`,
            value: H,
          },
          {
            keyPath: `local_llm_console_host_enabled`,
            value: R,
          },
          {
            keyPath: `local_llm_console_host_transport`,
            value: G,
          },
          {
            keyPath: `local_llm_console_host_listen_url`,
            value: Y,
          },
          {
            keyPath: `local_llm_console_host_https_port`,
            value: I,
          },
        ];
        includeCatalogPathEdit &&
          edits.splice(5, 0, { keyPath: `model_catalog_json`, value: c });
        try {
          await i.mutateAsync({
            filePath: se || null,
            expectedVersion: ce,
            edits,
          });
        } catch (e) {
          if (!isLocalLlmConsoleConfigVersionConflict(e)) throw e;
          let t = await r(),
            n = t?.data?.configWriteTarget ?? null,
            a = n?.filePath ?? se ?? null,
            o = n?.expectedVersion ?? null;
          await i.mutateAsync({
            filePath: a,
            expectedVersion: o,
            edits,
          });
        }
        E((t) => ({ ...W, launchMode: `local` }));
        ie({
          currentMode: isRemoteScope ? _e : b(e),
          hasRemoteSettings: q.length > 0,
          remoteUrl: q,
        });
        if (!isRemoteScope) {
          U({
            tone: `success`,
            text: `Saved runtime configuration. Restarting session...`,
          });
          await restartLocalLlmConsoleAppServer({
            hostId: getCurrentSessionHostId(),
            provider: a,
            model: o,
            reasoning: s,
          });
          let e = await r(),
            t = e?.data?.config ?? {},
            n = C(t),
            i = e?.data?.configWriteTarget?.filePath ?? se;
          E({ ...n, catalogPath: deriveLocalCatalogPath(i, n.catalogPath) });
          U({
            tone: `success`,
            text: `Saved runtime configuration.`,
          });
          return !0;
        }
        await r();
        if (isRemoteScope)
          try {
            await applyLocalLlmConsoleHostService(K);
          } catch (e) {
            U({
              tone: `error`,
              text:
                e instanceof Error && e.message.trim().length > 0
                  ? `Saved remote settings, but ${e.message}`
                  : `Saved remote settings, but unable to apply host settings immediately.`,
            });
            return !0;
          }
        U({
          tone: `success`,
          text:
            n.successText ??
            (isRemoteScope ? `Saved remote settings.` : `Saved runtime configuration.`),
        });
        return !0;
      } catch {
        U({
          tone: `error`,
          text: n.errorText ?? `Unable to save runtime configuration.`,
        });
        return !1;
      }
    },
    Se = async (e) => {
      if (e === _e) return;
      oe(e);
      let t = await xe(e, {
        scope: `remote`,
        savingText:
          e === `remote`
            ? `Saving remote host settings...`
            : `Saving local runtime settings...`,
        successText:
          e === `remote`
            ? `Connecting to remote host...`
            : `Switching back to local mode...`,
      });
      if (!t) {
        oe(null);
        return;
      }
      try {
        await switchLocalLlmConsoleSessionMode(e, {
          remoteUrl: w.remoteUrl,
          hostId: getCurrentSessionHostId(),
        });
      } catch (t) {
        oe(null);
        U({
          tone: `error`,
          text:
            t instanceof Error && t.message.trim().length > 0
              ? t.message
              : `Unable to switch the current session.`,
        });
      }
    },
    Ne = async (e) => {
      if (e === w.hostMode) return;
      let t = w.hostMode,
        n = { ...w, hostMode: e };
      E(n);
      oe(null);
      if (e === `on` && he) {
        E((e) => ({ ...e, hostMode: t }));
        U({
          tone: `error`,
          text: `Host mode requires a listen URL and a valid Tailscale HTTPS port.`,
        });
        return;
      }
      let r = await xe(w.launchMode, {
        scope: `remote`,
        hostAction: e === `on` ? `start` : `stop`,
        nextState: n,
        savingText: e === `on` ? `Starting local server...` : `Stopping local server...`,
        successText: e === `on` ? `Local server started.` : `Local server stopped.`,
      });
      r || E((e) => ({ ...e, hostMode: t }));
    },
    Ce = () => {
      E((e) => ({
        ...e,
        provider: t.provider,
        model: t.model,
        reasoning: t.reasoning,
        catalogPath: ye.catalogPath,
      }));
      oe(null);
      U({
        tone: `info`,
        text: `Reverted unsaved local changes.`,
      });
    },
    Le = () => {
      E((e) => ({
        ...e,
        launchMode: ye.launchMode,
        remoteUrl: ye.remoteUrl,
        remoteAuthTokenEnv: ye.remoteAuthTokenEnv,
        hostMode: ye.hostMode,
        hostListenUrl: ye.hostListenUrl,
        hostHttpsPort: ye.hostHttpsPort,
      }));
      oe(null);
      U({
        tone: `info`,
        text: `Reverted unsaved remote changes.`,
      });
    },
    Te = () =>
      (0, m.jsx)(c, {
        label: `Active config file`,
        description:
          se.length > 0
            ? (0, m.jsx)(`span`, {
                className: `font-mono text-xs break-all`,
                children: se,
              })
            : `No writable config file was detected for this profile.`,
        control: (0, m.jsx)(`div`, {
          className: `flex flex-wrap gap-2`,
          children: (0, m.jsx)(l, {
            color: `ghost`,
            size: `toolbar`,
            className: `w-auto`,
            disabled: se.length === 0,
            onClick: async () => {
              if (se.length === 0) {
                U({
                  tone: `error`,
                  text: `No writable config file is available for this profile.`,
                });
                return;
              }
              try {
                await Y({
                  path: se,
                });
              } catch {
                U({
                  tone: `error`,
                  text: `Unable to open config.toml.`,
                });
              }
            },
            children: `Open config.toml ↗`,
          }),
        }),
      }),
    Oe = n
      ? (0, m.jsx)(`div`, {
          className: `text-sm text-token-text-secondary`,
          children: ne
            ? `Loading remote settings...`
            : `Loading local runtime settings...`,
        })
      : ne
        ? (0, m.jsxs)(`div`, {
            className: `flex flex-col`,
            children: [
              (0, m.jsxs)(TileGroup, {
                position: `top`,
                children: [
                  (0, m.jsx)(c, {
                    label: `Current connection`,
                    description: `Switch this session between local and remote.`,
                    control: (0, m.jsx)(`div`, {
                      className: `w-[28rem] max-w-full`,
                      children: (0, m.jsx)(F, {
                        ariaLabel: `Current connection`,
                        options: J,
                        value: connectionChoice,
                        onChange: (e) => {
                          setConnectionChoice(b(e));
                        },
                        disabled: i.isPending || ae !== null,
                      }),
                    }),
                  }),
                  (0, m.jsxs)(`div`, {
                    className: `flex flex-col gap-2 px-4 py-3`,
                    children: [
                      (0, m.jsx)(`div`, {
                        className: `text-sm text-token-text-primary`,
                        children: `Tailscale server URL`,
                      }),
                      (0, m.jsx)(`div`, {
                        className: `text-sm text-token-text-secondary`,
                        children: `Use the tailnet URL that proxies your remote app-server.`,
                      }),
                      (0, m.jsxs)(`div`, {
                        className: `flex w-full max-w-[56rem] items-center gap-2`,
                        children: [
                          (0, m.jsx)(`div`, {
                            className: `min-w-0 flex-1`,
                            children: (0, m.jsx)(k, {
                              value: w.remoteUrl,
                              disabled: i.isPending || ae !== null || connectionChoice === `local`,
                              onChange: (e) => {
                                let t = e.target.value;
                                E((e) => ({ ...e, remoteUrl: t }));
                              },
                              placeholder: `your-host.tailnet.ts.net`,
                            }),
                          }),
                          (0, m.jsx)(l, {
                            color: `secondary`,
                            size: `toolbar`,
                            className: `w-auto shrink-0`,
                            disabled:
                              i.isPending ||
                              ae !== null ||
                              (connectionChoice === `remote`
                                ? !ve || qe
                                : !qe),
                            onClick: async () => {
                              await Se(connectionChoice);
                            },
                            children:
                              ae !== null
                                ? connectionChoice === `local` && qe
                                  ? `Disconnecting...`
                                  : `Connecting...`
                                : connectionChoice === `local` && qe
                                  ? `Disconnect`
                                  : `Connect`,
                          }),
                        ],
                      }),
                      connectionChoice === `remote` &&
                      D?.tone === `error` &&
                      D?.text === `Please enter a valid remote host.` &&
                      w.remoteUrl.trim().length > 0 &&
                      !hasValidRemoteHostUrl(w.remoteUrl)
                        ? (0, m.jsx)(M, {
                            tone: `error`,
                            text: `Please enter a valid remote host.`,
                          })
                        : null,
                    ],
                  }),
                  (0, m.jsxs)(`div`, {
                    className: `flex flex-col gap-2 px-4 py-3`,
                    children: [
                      (0, m.jsx)(`div`, {
                        className: `text-sm text-token-text-primary`,
                        children: `Remote auth token env var`,
                      }),
                      (0, m.jsx)(`div`, {
                        className: `text-sm text-token-text-secondary`,
                        children: `Optional. If set, the launcher forwards --remote-auth-token-env when connecting to the remote host.`,
                      }),
                      (0, m.jsx)(`div`, {
                        className: `w-full max-w-[56rem]`,
                        children: (0, m.jsx)(k, {
                          value: w.remoteAuthTokenEnv,
                          disabled: i.isPending || ae !== null || connectionChoice === `local`,
                          onChange: (e) => {
                            let t = e.target.value;
                            E((e) => ({ ...e, remoteAuthTokenEnv: t }));
                          },
                          placeholder: `LOCAL_LLM_CONSOLE_REMOTE_TOKEN`,
                        }),
                      }),
                    ],
                  }),
                ],
              }),
              (0, m.jsxs)(TileGroup, {
                position: `middle`,
                children: [
                  (0, m.jsx)(c, {
                    label: `Host remote sessions`,
                    description: `Start a local server on this machine so another Local LLM Console can connect to it.`,
                    control: (0, m.jsx)(`div`, {
                      className: `w-[28rem] max-w-full`,
                      children: (0, m.jsx)(F, {
                        ariaLabel: `Host remote sessions`,
                        options: j,
                        value: w.hostMode,
                        disabled: i.isPending || ae !== null,
                        onChange: async (e) => {
                          await Ne(e);
                        },
                      }),
                    }),
                  }),
                  (0, m.jsxs)(`div`, {
                    className: `flex flex-col gap-2 px-4 py-3`,
                    children: [
                      (0, m.jsx)(`div`, {
                        className: `text-sm text-token-text-primary`,
                        children: `Host listen URL`,
                      }),
                      (0, m.jsx)(`div`, {
                        className: `text-sm text-token-text-secondary`,
                        children: `The local server endpoint to start when host mode is enabled.`,
                      }),
                      (0, m.jsx)(`div`, {
                        className: `w-full max-w-[56rem]`,
                        children: (0, m.jsx)(k, {
                          value: w.hostListenUrl,
                          disabled: i.isPending || ae !== null,
                          onChange: (e) => {
                            let t = e.target.value;
                            E((e) => ({ ...e, hostListenUrl: t }));
                          },
                          placeholder: `127.0.0.1:8765`,
                        }),
                      }),
                    ],
                  }),
                  (0, m.jsx)(c, {
                    label: `Tailscale HTTPS port`,
                    description: `Port used by tailscale serve when publishing the local app-server inside your tailnet.`,
                    control: (0, m.jsx)(`div`, {
                      className: `w-[12rem] max-w-full`,
                      children: (0, m.jsx)(k, {
                        value: w.hostHttpsPort,
                        disabled: i.isPending || ae !== null,
                        onChange: (e) => {
                          let t = e.target.value;
                          E((e) => ({ ...e, hostHttpsPort: t }));
                        },
                        placeholder: `443`,
                      }),
                    }),
                  }),
                ],
              }),
              (0, m.jsx)(TileGroup, {
                position:
                  (w.hostMode === `on` && he) || D != null || persistentHostStatus
                    ? `middle`
                    : `bottom`,
                children: (0, m.jsx)(Te, {}),
              }),
              (w.hostMode === `on` && he) || D != null || persistentHostStatus
                ? (0, m.jsx)(TileGroup, {
                    position: `bottom`,
                    children: (0, m.jsxs)(`div`, {
                      className: `flex flex-col gap-3 px-4 py-3`,
                      children: [
                        w.hostMode === `on` && he
                          ? (0, m.jsx)(M, {
                              tone: `error`,
                              text: `Host mode requires a listen URL and a valid Tailscale HTTPS port.`,
                            })
                          : null,
                        persistentHostStatus
                          ? (0, m.jsx)(M, {
                              tone: `info`,
                              text: `Local Tailscale server is running.`,
                            })
                          : null,
                        D != null ? (0, m.jsx)(M, { tone: D.tone, text: D.text }) : null,
                      ],
                    }),
                  })
                : null,
            ],
          })
        : (0, m.jsxs)(`div`, {
            className: `flex flex-col`,
            children: [
              (0, m.jsxs)(TileGroup, {
                position: `top`,
                children: [
                  (0, m.jsx)(c, {
                    label: `Provider`,
                    description: `Used when this profile runs locally or through Codex Cloud.`,
                    control: (0, m.jsx)(`div`, {
                      className: `w-[28rem] max-w-full`,
                      children: (0, m.jsx)(F, {
                        ariaLabel: `Provider`,
                        options: g,
                        value: w.provider,
                        onChange: (e) => {
                          E((t) => {
                            let n = z(e);
                            return {
                              ...t,
                              provider: n,
                              model: K(n, t.model),
                            };
                          });
                        },
                      }),
                    }),
                  }),
                  (0, m.jsx)(c, {
                    label: `Default model`,
                    description: `The model ID used for the selected provider.`,
                    control: (0, m.jsx)(`div`, {
                      className: `w-[28rem] max-w-full`,
                      children: (0, m.jsx)(F, {
                        ariaLabel: `Default model`,
                        options: le,
                        value: w.model,
                        onChange: (e) => {
                          E((t) => ({ ...t, model: e }));
                        },
                      }),
                    }),
                  }),
                  (0, m.jsx)(c, {
                    label: `Reasoning effort`,
                    description: `Default reasoning effort for local runs launched from this desktop profile.`,
                    control: (0, m.jsx)(`div`, {
                      className: `w-[28rem] max-w-full`,
                      children: (0, m.jsx)(F, {
                        ariaLabel: `Reasoning effort`,
                        options: A,
                        value: w.reasoning,
                        onChange: (e) => {
                          E((t) => ({ ...t, reasoning: e }));
                        },
                      }),
                    }),
                  }),
                ],
              }),
              (0, m.jsxs)(TileGroup, {
                position: `middle`,
                children: [
                  (0, m.jsx)(c, {
                    label: `Model catalog path`,
                    description: `Path to the JSON catalog used when this profile runs locally.`,
                    control: (0, m.jsx)(`div`, {
                      className: `ml-5 w-[32rem] max-w-full`,
                      children: (0, m.jsx)(k, {
                        value: w.catalogPath,
                        disabled: z(w.provider) === `codex`,
                        onChange: (e) => {
                          let t = e.target.value;
                          E((e) => ({ ...e, catalogPath: t }));
                        },
                        placeholder: `/home/you/.codex-local-desktop-models.json`,
                      }),
                    }),
                  }),
                  (0, m.jsx)(Te, {}),
                ],
              }),
              (0, m.jsx)(TileGroup, {
                position: `bottom`,
                children: (0, m.jsxs)(`div`, {
                  className: `flex flex-col gap-3 px-4 py-3`,
                  children: [
                    (0, m.jsxs)(`div`, {
                      className: `flex flex-wrap gap-2`,
                      children: [
                        (0, m.jsx)(l, {
                          color: `primary`,
                          size: `toolbar`,
                          className: `w-auto`,
                          disabled: !fe || be || i.isPending || ae !== null,
                          onClick: async () => {
                            await xe(w.launchMode, { scope: `local` });
                          },
                          children: i.isPending ? `Saving...` : `Save changes`,
                        }),
                        (0, m.jsx)(l, {
                          color: `secondary`,
                          size: `toolbar`,
                          className: `w-auto`,
                          disabled: !fe || i.isPending,
                          onClick: Ce,
                          children: `Reset`,
                        }),
                      ],
                    }),
                    qe
                      ? (0, m.jsx)(M, {
                          tone: `info`,
                          text: `This session is currently connected to a remote host. Local model changes will apply when you switch back to local work.`,
                        })
                      : null,
                    be
                      ? (0, m.jsx)(M, {
                          tone: `error`,
                          text: iee(w.provider)
                            ? `Provider, model, reasoning effort, and catalog path are all required before saving local settings.`
                            : `Provider, model, and reasoning effort are all required before saving Codex Cloud settings.`,
                        })
                      : null,
                    D != null ? (0, m.jsx)(M, { tone: D.tone, text: D.text }) : null,
                  ],
                }),
              }),
            ],
          });

  (0, p.useEffect)(() => {
    if ((D == null ? void 0 : D.tone) !== `success`) return;
    let e = window.setTimeout(() => {
      U((e) => (e != null && e.tone === `success` ? null : e));
    }, 3000);
    return () => {
      window.clearTimeout(e);
    };
  }, [D]);

  (0, p.useEffect)(() => {
    r().catch(() => {});
  }, []);

  (0, p.useEffect)(() => {
    let e = !1,
      t = (t) => {
        if (e || !(t && typeof t == `object`)) return;
        let n = isCurrentRemoteSessionConnected() ? `remote` : `local`;
        ie({
          currentMode: n,
          hasRemoteSettings: Boolean(t.hasRemoteSettings),
          remoteUrl: v(t.remoteUrl, ``),
        });
        setConnectionChoice(n);
      };
    t(readLocalLlmConsoleSessionState());
    refreshLocalLlmConsoleSessionState().then(t).catch(() => {});
    if (typeof window !== `undefined`) {
      let n = (e) => {
        t(e.detail);
      };
      return (
        window.addEventListener(`local-llm-console-state`, n),
        () => {
          e = !0;
          window.removeEventListener(`local-llm-console-state`, n);
        }
      );
    }
    return () => {
      e = !0;
    };
  }, []);

  (0, p.useEffect)(() => {
    ae === null && setConnectionChoice(_e);
  }, [_e, ae]);

  (0, p.useEffect)(() => {
    E(ye);
    U((e) => (e != null && e.tone === `success` ? e : null));
    oe(null);
  }, [L(ye)]);

  if (O) return Oe;
  return (0, m.jsx)(s, {
    title: ne ? `Remote settings` : `Runtime`,
    subtitle: ne
      ? `Configure how this desktop profile connects to and hosts remote sessions over Tailscale.`
      : `Configure how this desktop profile runs local models.`,
    children: Oe,
  });
}

function LocalModelsSettings(props = {}) {
  let { section: e, embedded: t = !1 } = props;
  e = e ?? (t ? `local` : `remote`);
  return (0, m.jsx)(RuntimeSettingsContent, { embedded: t, section: e });
}

function RemoteSettingsPage() {
  return (0, m.jsx)(RuntimeSettingsContent, { section: `remote` });
}

export { LocalModelsSettings, RemoteSettingsPage };
