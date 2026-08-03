import type { NextConfig } from "next";

// Static export: the site is one page with no server, built into `out/` and
// served as plain files by GitHub Pages.
// `/docs` is a separate Next app (../docs, also a static export but with
// basePath=/docs). .github/workflows/deploy-pages.yml merges the docs export
// into this one's `out/docs`, so the two static trees share one origin.
export default {
  output: "export",
  // Emits `about/index.html` instead of `about.html`, so every page is a
  // directory. GitHub Pages has no rewrite rules — it can only serve a file or
  // canonicalise a directory — and without this the export ships BOTH
  // `configuration.html` and a `configuration/` directory (Next puts the RSC
  // payload twins there) fighting over one URL. Must stay in step with
  // docs/next.config.mjs: one URL shape across both apps.
  trailingSlash: true,
  reactCompiler: true,
} satisfies NextConfig;
