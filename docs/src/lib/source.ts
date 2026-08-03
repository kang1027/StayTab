import { loader } from 'fumadocs-core/source';
import { lucideIconsPlugin } from 'fumadocs-core/source/lucide-icons';
import { docsBasePath, docsContentRoute, docsImageRoute, docsRoute, siteUrl } from './shared';
import { defineDocs } from 'fumadocs-mdx/macro';
import { metaSchema, pageSchema } from 'fumadocs-core/source/schema';

const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    schema: pageSchema,
    postprocess: {
      includeProcessedMarkdown: true,
    },
  },
  meta: {
    schema: metaSchema,
  },
});

// See https://fumadocs.dev/docs/headless/source-api for more info
export const source = loader({
  baseUrl: docsRoute,
  source: docs.toFumadocsSource(),
  plugins: [lucideIconsPlugin()],
});

/**
 * These URLs are assembled by hand rather than produced by `next/link`, so
 * Next never applies `basePath` to them — it has to be prepended here or the
 * request lands on the marketing site at the origin root and 404s.
 *
 * `segments` stays unprefixed: it feeds `generateStaticParams`, which wants
 * route params, not public URLs.
 */
function publicUrl(route: string, locale: string | undefined, segments: string[]) {
  return (
    docsBasePath + '/' + [locale, ...route.split('/'), ...segments].filter(Boolean).join('/')
  );
}

/**
 * Canonical public URL of a page, absolute.
 *
 * `source` is mounted at `docsRoute` ('/'), so `page.url` carries no `/docs`
 * prefix, and Next does not apply `basePath` to metadata URLs either — so a
 * relative canonical would resolve against the origin root and point at the
 * marketing site. Fully absolute leaves nothing to infer.
 *
 * Slash-terminated to match `trailingSlash: true`, which is the form that has
 * an index.html on disk; GitHub Pages answers the bare form with its own 301.
 * Next would normalise the canonical anyway, but a canonical URL is not
 * something to leave to an implicit rewrite.
 */
export function getPageUrl(page: (typeof source)['$inferPage']) {
  return siteUrl + docsBasePath + (page.url.endsWith('/') ? page.url : `${page.url}/`);
}

export function getPageImageUrl(page: (typeof source)['$inferPage']) {
  const segments = [...page.slugs, 'image.png'];

  return { segments, url: publicUrl(docsImageRoute, page.locale, segments) };
}

export function getPageMarkdownUrl(page: (typeof source)['$inferPage']) {
  const segments = [...page.slugs, 'content.md'];

  return { segments, url: publicUrl(docsContentRoute, page.locale, segments) };
}

export async function getLLMText(page: (typeof source)['$inferPage']) {
  const processed = await page.data.getText('processed');

  return `# ${page.data.title} (${page.url})

${processed}`;
}
