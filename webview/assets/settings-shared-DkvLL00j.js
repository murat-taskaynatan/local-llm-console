import { t as e } from "./jsx-runtime-ebkFq_df.js";
import { a as t, r as n } from "./lib-CrmccYwj.js";
import { t as r } from "./clsx-DQfH8mAl.js";
import { n as i, t as a } from "./chevron-Oo-xHR0X.js";
import { _ as o, p as s } from "./settings-content-layout-DQIQ2vPn.js";

var c = n({
  account: {
    id: `settings.nav.account`,
    defaultMessage: `Account`,
    description: `Title for account settings section`,
  },
  appearance: {
    id: `settings.nav.appearance`,
    defaultMessage: `Appearance`,
    description: `Title for appearance settings section`,
  },
  "general-settings": {
    id: `settings.nav.general-settings`,
    defaultMessage: `General`,
    description: `Title for general settings section`,
  },
  agent: {
    id: `settings.nav.agent`,
    defaultMessage: `Configuration`,
    description: `Title for configuration settings section`,
  },
  "data-controls": {
    id: `settings.nav.data-controls`,
    defaultMessage: `Archived chats`,
    description: `Title for archived threads settings section`,
  },
  usage: {
    id: `settings.nav.usage`,
    defaultMessage: `Usage`,
    description: `Title for usage settings section`,
  },
  "computer-use": {
    id: `settings.nav.computer-use`,
    defaultMessage: `Computer use`,
    description: `Title for computer use settings section`,
  },
  "mcp-settings": {
    id: `settings.nav.mcp-settings`,
    defaultMessage: `MCP servers`,
    description: `Title for MCP servers settings section`,
  },
  connections: {
    id: `settings.nav.connections`,
    defaultMessage: `Connections`,
    description: `Title for connections settings section`,
  },
});

function l(e) {
  return c[e];
}

var u = e();

function d(e) {
  let {
      children: t,
      className: n,
      contentClassName: o,
      chevronClassName: s,
      color: c = `secondary`,
      ...l
    } = e,
    d = r(`w-[240px] justify-between`, n),
    f = r(`flex min-w-0 flex-1 items-center gap-1.5`, o),
    p = r(`icon-2xs shrink-0 text-token-input-placeholder-foreground`, s);
  return (0, u.jsxs)(i, {
    color: c,
    size: `toolbar`,
    className: d,
    ...l,
    children: [
      (0, u.jsx)(`span`, { className: f, children: t }),
      (0, u.jsx)(a, { className: p }),
    ],
  });
}

function f(e) {
  return (0, u.jsx)(t, { ...l(e.slug) });
}

function p(e) {
  switch (e.slug) {
    case `account`:
      return (0, u.jsx)(t, {
        id: `settings.section.account`,
        defaultMessage: `Account`,
        description: `Title for account settings section`,
      });
    case `appearance`:
      return (0, u.jsx)(t, {
        id: `settings.section.appearance`,
        defaultMessage: `Appearance`,
        description: `Title for appearance settings section`,
      });
    case `general-settings`:
      return (0, u.jsx)(t, {
        id: `settings.section.general-settings`,
        defaultMessage: `General`,
        description: `Title for general settings section`,
      });
    case `agent`:
      return (0, u.jsx)(t, {
        id: `settings.section.agent`,
        defaultMessage: `Configuration`,
        description: `Title for configuration settings section`,
      });
    case `data-controls`:
      return (0, u.jsx)(t, {
        id: `settings.section.data-controls`,
        defaultMessage: `Archived chats`,
        description: `Title for archived threads settings section`,
      });
    case `usage`:
      return (0, u.jsx)(t, {
        id: `settings.section.usage`,
        defaultMessage: `Usage`,
        description: `Title for usage settings section`,
      });
    case `computer-use`:
      return (0, u.jsx)(t, { ...o });
    case `mcp-settings`:
      return (0, u.jsx)(t, {
        id: `settings.section.mcp-settings`,
        defaultMessage: `MCP servers`,
        description: `Title for MCP servers settings section`,
      });
    case `connections`:
      return (0, u.jsx)(t, {
        id: `settings.section.connections`,
        defaultMessage: `Connections`,
        description: `Title for connections settings section`,
      });
    default:
      return null;
  }
}

function m(e) {
  if (e.slug !== `mcp-settings`) return null;
  return (0, u.jsxs)(`div`, {
    children: [
      (0, u.jsx)(t, {
        id: `settings.section.mcp-settings.subtitle`,
        defaultMessage: `Connect external tools and data sources. `,
        description: `Subtitle for MCP settings section`,
      }),
      (0, u.jsx)(`a`, {
        className: `inline-flex items-center gap-1 text-base text-token-text-link-foreground`,
        href: s,
        target: `_blank`,
        rel: `noreferrer`,
        children: (0, u.jsx)(t, {
          id: `settings.section.mcp-settings.learnMore`,
          defaultMessage: `Learn more.`,
          description: `Label for MCP docs link`,
        }),
      }),
    ],
  });
}

export { l as a, p as i, f as n, m as r, d as t };
//# sourceMappingURL=settings-shared-DkvLL00j.js.map
