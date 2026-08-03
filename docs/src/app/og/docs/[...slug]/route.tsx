import { getPageImageUrl, source } from '@/lib/source';
import { notFound } from 'next/navigation';
import { ImageResponse } from 'next/og';
import { generate as DefaultImage } from 'fumadocs-ui/og';
import { appName } from '@/lib/shared';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export const revalidate = false;
// Static export already prerenders only generateStaticParams(); pinning this
// keeps it true if the app ever runs on a server, so the build-time-only
// assumption behind the module-scope read below cannot quietly break.
export const dynamicParams = false;

// Satori has no network or public/ access, so the mark is inlined. Read once at
// module load, which only ever happens during the build.
const iconDataUri = `data:image/png;base64,${readFileSync(
  join(process.cwd(), 'public/icon.png'),
).toString('base64')}`;

export async function GET(_req: Request, { params }: RouteContext<'/og/docs/[...slug]'>) {
  const { slug } = await params;
  const page = source.getPage(slug.slice(0, -1));
  if (!page) notFound();

  return new ImageResponse(
    <DefaultImage
      title={page.data.title}
      description={page.data.description}
      site={appName}
      // Brand accent, matching --color-accent in web/app/globals.css (#3b82f6).
      // Left at fumadocs' default the card comes out magenta.
      primaryColor="rgba(59,130,246,0.3)"
      primaryTextColor="rgb(59,130,246)"
      // eslint-disable-next-line next/no-img-element -- satori renders raw JSX; next/image does not work inside ImageResponse
      icon={<img src={iconDataUri} alt="" width={56} height={56} />}
    />,
    {
      width: 1200,
      height: 630,
    },
  );
}

export function generateStaticParams() {
  return source.getPages().map((page) => ({
    lang: page.locale,
    slug: getPageImageUrl(page).segments,
  }));
}
