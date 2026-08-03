import { loader } from 'fumadocs-core/source';
import { lucideIconsPlugin } from 'fumadocs-core/source/lucide-icons';
import { docsBasePath, docsContentRoute, docsImageRoute, docsRoute } from './shared';
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
