import { s as e } from "./chunk-Bj-mKKzh.js";
import { t as n } from "./react-BE0_fAZJ.js";
import { t as r } from "./jsx-runtime-ebkFq_df.js";
import { t as i } from "./clsx-DQfH8mAl.js";
import { n as a, r as o, t as s } from "./settings-content-layout-DQIQ2vPn.js";
import { n as c } from "./settings-row-BG-yYlW7.js";
import { n as l } from "./chevron-Oo-xHR0X.js";
import { i as q, n as H, t as R } from "./check-md-YtZX6wSV.js";
import { u as u, y as d } from "./config-queries-jUrDLWnn.js";
import { t as G } from "./settings-shared-DkvLL00j.js";
import { o as Y } from "./use-model-settings-ldiRRtPt.js";

var p = e(n(), 1),
  m = r(),
  h = [
    { value: `ollama`, label: `Ollama` },
    { value: `lmstudio`, label: `LM Studio` },
  ],
  g = [
    { value: `low`, label: `Low` },
    { value: `medium`, label: `Medium` },
    { value: `high`, label: `High` },
    { value: `xhigh`, label: `XHigh` },
  ],
  _ = [`gpt-oss:120b`, `qwen3.5:9.7b`, `qwen3.5:122b`];

function v(e, t = ``, n = ``) {
  return typeof e == `string` && e.trim().length > 0 ? e : t || n;
}

function y(e) {
  return {
    provider: v(e?.model_provider, v(e?.oss_provider, `ollama`)),
    model: v(e?.model, `gpt-oss:120b`),
    reasoning: v(e?.model_reasoning_effort, `medium`),
    catalogPath: v(e?.model_catalog_json, ``),
  };
}

function b(e) {
  return JSON.stringify(e);
}

function N(e) {
  let t = _.map((e) => ({ value: e, label: e }));
  return e != null && e.length > 0 && !_.includes(e)
    ? [{ value: e, label: `${e} (current)` }, ...t]
    : t;
}

function x(e) {
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

function S(e) {
  return (0, m.jsx)(`input`, {
    className: `w-full rounded-md border border-token-input-border bg-token-input-background px-2.5 py-1.5 text-sm text-token-input-foreground outline-none`,
    ...e,
  });
}

function C(e) {
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

function LocalModelsSettings(props = {}) {
  let { embedded: M = !1 } = props,
    { data: e, isLoading: n, refetch: r } = d(),
    i = u(),
    t = (0, p.useMemo)(() => y(e?.config), [
      e?.config?.model_provider,
      e?.config?.oss_provider,
      e?.config?.model,
      e?.config?.model_reasoning_effort,
      e?.config?.model_catalog_json,
    ]),
    [T, w] = (0, p.useState)(t),
    [E, D] = (0, p.useState)(null),
    O = e?.configWriteTarget?.filePath ?? ``,
    k = e?.configWriteTarget?.expectedVersion ?? null,
    j = (0, p.useMemo)(() => N(T.model), [T.model]),
    A = b(t) !== b(T),
    P =
      T.provider.trim().length === 0 ||
      T.model.trim().length === 0 ||
      T.reasoning.trim().length === 0 ||
      T.catalogPath.trim().length === 0,
    L = n
      ? (0, m.jsx)(`div`, {
          className: `text-sm text-token-text-secondary`,
          children: `Loading local model settings...`,
        })
      : (0, m.jsxs)(`div`, {
          className: `flex flex-col`,
          children: [
            (0, m.jsxs)(`div`, {
              className: `border-token-border flex flex-col divide-y-[0.5px] divide-token-border border`,
              style: {
                backgroundColor: `var(--color-background-panel, var(--color-token-bg-fog))`,
                borderTopLeftRadius: `0.5rem`,
                borderTopRightRadius: `0.5rem`,
                borderBottomLeftRadius: 0,
                borderBottomRightRadius: 0,
              },
              children: [
                (0, m.jsx)(c, {
                  label: `Local provider`,
                  description: `Used for both model resolution and OSS requests in this profile.`,
                  control: (0, m.jsx)(`div`, {
                    className: `w-[28rem] max-w-full`,
                    children: (0, m.jsx)(C, {
                      ariaLabel: `Local provider`,
                      options: h,
                      value: T.provider,
                      onChange: (e) => {
                        w((t) => ({ ...t, provider: e }));
                      },
                    }),
                  }),
                }),
                (0, m.jsx)(c, {
                  label: `Default model`,
                  description: `The model ID sent to your local provider when a conversation starts.`,
                  control: (0, m.jsx)(`div`, {
                    className: `w-[28rem] max-w-full`,
                    children: (0, m.jsx)(C, {
                      ariaLabel: `Default model`,
                      options: j,
                      value: T.model,
                      onChange: (e) => {
                        w((t) => ({ ...t, model: e }));
                      },
                    }),
                  }),
                }),
                (0, m.jsx)(c, {
                  label: `Reasoning effort`,
                  description: `Default reasoning effort for local runs launched from this desktop profile.`,
                  control: (0, m.jsx)(`div`, {
                    className: `w-[28rem] max-w-full`,
                    children: (0, m.jsx)(C, {
                      ariaLabel: `Reasoning effort`,
                      options: g,
                      value: T.reasoning,
                      onChange: (e) => {
                        w((t) => ({ ...t, reasoning: e }));
                      },
                    }),
                  }),
                }),
              ],
            }),
            (0, m.jsxs)(`div`, {
              className: `border-token-border flex flex-col divide-y-[0.5px] divide-token-border border`,
              style: {
                backgroundColor: `var(--color-background-panel, var(--color-token-bg-fog))`,
                borderRadius: 0,
                borderTopWidth: 0,
              },
              children: [
                (0, m.jsx)(c, {
                  label: `Model catalog path`,
                  description: `Path to the JSON catalog used by this profile for local model metadata.`,
                  control: (0, m.jsx)(`div`, {
                    className: `ml-5 w-[32rem] max-w-full`,
                    children: (0, m.jsx)(S, {
                      value: T.catalogPath,
                      onChange: (e) => {
                        let t = e.target.value;
                        w((e) => ({ ...e, catalogPath: t }));
                      },
                      placeholder: `/home/you/.codex-local-desktop-models.json`,
                    }),
                  }),
                }),
                (0, m.jsx)(c, {
                  label: `Active config file`,
                  description:
                    O.length > 0
                      ? (0, m.jsx)(`span`, {
                          className: `font-mono text-xs break-all`,
                          children: O,
                        })
                      : `No writable config file was detected for this profile.`,
                  control: (0, m.jsxs)(`div`, {
                    className: `flex flex-wrap gap-2`,
                    children: [
                      (0, m.jsx)(l, {
                        color: `ghost`,
                        size: `toolbar`,
                        className: `w-auto`,
                        disabled: O.length === 0,
                        onClick: async () => {
                          if (O.length === 0) {
                            D({
                              tone: `error`,
                              text: `No writable config file is available for this profile.`,
                            });
                            return;
                          }
                          try {
                            await Y({
                              path: O,
                            });
                          } catch {
                            D({
                              tone: `error`,
                              text: `Unable to open config.toml.`,
                            });
                          }
                        },
                        children: `Open config.toml ↗`,
                      }),
                    ],
                  }),
                }),
              ],
            }),
            (0, m.jsx)(`div`, {
              className: `border-token-border flex flex-col divide-y-[0.5px] divide-token-border border`,
              style: {
                backgroundColor: `var(--color-background-panel, var(--color-token-bg-fog))`,
                borderTopLeftRadius: 0,
                borderTopRightRadius: 0,
                borderBottomLeftRadius: `0.5rem`,
                borderBottomRightRadius: `0.5rem`,
                borderTopWidth: 0,
              },
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
                        disabled: !A || P || i.isPending,
                        onClick: async () => {
                          let e = T.provider.trim(),
                            n = T.model.trim(),
                            a = T.reasoning.trim(),
                            o = T.catalogPath.trim();
                          if (
                            e.length === 0 ||
                            n.length === 0 ||
                            a.length === 0 ||
                            o.length === 0
                          ) {
                            D({
                              tone: `error`,
                              text: `Provider, model, reasoning effort, and catalog path are all required.`,
                            });
                            return;
                          }
                          D({
                            tone: `info`,
                            text: `Saving local model settings...`,
                          });
                          try {
                            await i.mutateAsync({
                              filePath: O || null,
                              expectedVersion: k,
                              edits: [
                                { keyPath: `model_provider`, value: e },
                                { keyPath: `oss_provider`, value: e },
                                { keyPath: `model`, value: n },
                                { keyPath: `model_reasoning_effort`, value: a },
                                { keyPath: `model_catalog_json`, value: o },
                              ],
                            }),
                              await r(),
                              D({
                                tone: `success`,
                                text: `Saved local model settings.`,
                              });
                          } catch {
                            D({
                              tone: `error`,
                              text: `Unable to save local model settings.`,
                            });
                          }
                        },
                        children: i.isPending ? `Saving...` : `Save changes`,
                      }),
                      (0, m.jsx)(l, {
                        color: `secondary`,
                        size: `toolbar`,
                        className: `w-auto`,
                        disabled: !A || i.isPending,
                        onClick: () => {
                          w(t),
                            D({
                              tone: `info`,
                              text: `Reverted unsaved changes.`,
                            });
                        },
                        children: `Reset`,
                      }),
                    ],
                  }),
                  P
                    ? (0, m.jsx)(x, {
                        tone: `error`,
                        text: `Provider, model, reasoning effort, and catalog path are all required before saving.`,
                      })
                    : null,
                  E != null ? (0, m.jsx)(x, { tone: E.tone, text: E.text }) : null,
                ],
              }),
            }),
          ],
        });

  (0, p.useEffect)(() => {
    w(t), D(null);
  }, [b(t)]);

  return M
    ? L
    : (0, m.jsx)(s, {
        title: `Local Models`,
        subtitle: `Configure the local model provider, default model, and model catalog for this desktop profile.`,
        children: L,
      });
}

export { LocalModelsSettings };
