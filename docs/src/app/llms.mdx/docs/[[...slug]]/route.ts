import { getLLMText, getPageMarkdownUrl, source } from '@/lib/source';
import { notFound } from 'next/navigation';
import { resolveLocalePath } from '@/lib/i18n';

export const revalidate = false;

type Context = { params: Promise<{ slug?: string[] }> };

export async function GET(_req: Request, { params }: Context) {
  const { slug } = await params;
  const { locale, slugs } = resolveLocalePath(slug?.slice(0, -1));
  const page = source.getPage(slugs, locale);
  if (!page) notFound();

  return new Response(await getLLMText(page), {
    headers: {
      'Content-Type': 'text/markdown',
    },
  });
}

export function generateStaticParams() {
  return source.getPages().map((page) => ({
    slug: getPageMarkdownUrl(page).segments,
  }));
}
