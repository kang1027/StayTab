import { createMDX } from 'fumadocs-mdx/next';

const withMDX = createMDX();

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  // Served from bettercmdtab.app/docs, baked into the same nginx image as the
  // marketing site. basePath prefixes every generated URL — pages, assets and
  // /_next/* — so the two static trees share one origin without colliding.
  basePath: '/docs',
  output: 'export',
  // No server at runtime, so no image optimizer: assets must ship pre-sized.
  images: { unoptimized: true },
};

export default withMDX(config);
