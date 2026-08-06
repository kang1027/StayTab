import { createMDX } from 'fumadocs-mdx/next';
import createNextIntlPlugin from 'next-intl/plugin';

const withMDX = createMDX();
const withNextIntl = createNextIntlPlugin();

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  // Served from bettercmdtab.app/docs, merged into the marketing site's export
  // at deploy time. basePath prefixes every generated URL — pages, assets and
  // /_next/* — so the two static trees share one origin without colliding.
  basePath: '/docs',
  output: 'export',
  // Must match web/next.config.ts: one URL shape across both apps. See there
  // for why (GitHub Pages cannot rewrite, and the flat form ships a file and a
  // directory competing for the same URL).
  trailingSlash: true,
  // No server at runtime, so no image optimizer: assets must ship pre-sized.
  images: { unoptimized: true },
};

export default withNextIntl(withMDX(config));
