export const appName = 'BetterCmdTab';

/** Origin the docs are served from — they live under /docs on the main site. */
export const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://bettercmdtab.app';

/** Marketing site, linked from the docs nav. Absolute so it escapes /docs. */
export const homeUrl = 'https://bettercmdtab.app';

/**
 * Public prefix the docs are mounted under, mirroring `basePath` in
 * next.config.mjs. Next prefixes anything it generates itself; raw `<img src>`
 * and `fetch` URLs are not generated, so those must prepend this by hand.
 */
export const docsBasePath = '/docs';

// Route paths are relative to the app root; `basePath` adds the public prefix,
// so these must NOT repeat it or every URL becomes /docs/docs/...
export const docsRoute = '/';
export const docsImageRoute = '/og/docs';
export const docsContentRoute = '/llms.mdx/docs';

export const gitConfig = {
  user: 'rokartur',
  repo: 'BetterCmdTab',
  branch: 'main',
};
