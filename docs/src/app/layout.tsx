import { RootProvider } from 'fumadocs-ui/provider/next';
import './global.css';
import type { Metadata } from 'next';
import { appName, docsBasePath, siteUrl } from '@/lib/shared';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: `${appName} documentation`,
    template: `%s — ${appName}`,
  },
  description:
    'Documentation for BetterCmdTab, a faster and configurable Command-Tab switcher for macOS.',
  applicationName: appName,
  icons: {
    // Literal hrefs, so Next does not prefix them with basePath — without
    // docsBasePath these resolve against the origin root, which is the
    // marketing site (404 in dev, and its favicon rather than ours in prod).
    // Small sizes are dedicated files rather than a downscale of the 256px
    // mark, which turns to mush at 16px.
    icon: [
      { url: `${docsBasePath}/favicon-16.png`, sizes: '16x16', type: 'image/png' },
      { url: `${docsBasePath}/favicon-32.png`, sizes: '32x32', type: 'image/png' },
      { url: `${docsBasePath}/icon.png`, sizes: '256x256', type: 'image/png' },
    ],
    apple: `${docsBasePath}/apple-touch-icon.png`,
  },
  openGraph: {
    type: 'website',
    siteName: `${appName} documentation`,
  },
};

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    // Dark-only, like the landing page — so no next-themes and no toggle.
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider
          theme={{ enabled: false }}
          // Matches the staticGET index in app/api/search — without this the
          // client would query a server route that a static export never has.
          // The URL is explicit because the static client derives its default
          // from `import.meta.env.BASE_URL` (a Vite convention Next never sets),
          // so it would otherwise fetch /api/search and hit the marketing site.
          search={{ options: { type: 'static', api: `${docsBasePath}/api/search` } }}
        >
          {children}
        </RootProvider>
      </body>
    </html>
  );
}
