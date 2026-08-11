import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

const SITE = "https://bettercmdtab.app";
const TITLE = "BetterCmdTab — a better Cmd+Tab window switcher for macOS";
// The <meta name="description"> variant carries the OS floor; the social cards
// drop it to stay inside the ~200-char preview budget.
const DESCRIPTION =
  "A fast, native Cmd+Tab replacement for macOS: grid & list app switcher, fuzzy search & launch, and window cycling. Free, open-source, zero telemetry. macOS 13+.";
const SOCIAL_DESCRIPTION =
  "A fast, native Cmd+Tab replacement for macOS: grid & list app switcher, fuzzy search & launch, and window cycling. Free, open-source, zero telemetry.";
const IMAGE_ALT = "BetterCmdTab — a native window switcher and app launcher for macOS";

export const metadata: Metadata = {
  metadataBase: new URL(SITE),
  title: TITLE,
  description: DESCRIPTION,
  applicationName: "BetterCmdTab",
  authors: [{ name: "rokartur" }],
  keywords: [
    "macOS window switcher",
    "Cmd+Tab replacement",
    "app switcher macOS",
    "alt-tab for mac",
    "macOS app launcher",
    "AltTab alternative",
    "BetterCmdTab",
  ],
  alternates: {
    canonical: "/",
    languages: { en: "/", "x-default": "/" },
  },
  robots: {
    index: true,
    follow: true,
    "max-image-preview": "large",
    "max-snippet": -1,
    "max-video-preview": -1,
  },
  formatDetection: { telephone: false },
  icons: {
    icon: [
      { url: "/favicon-32.png", type: "image/png", sizes: "32x32" },
      { url: "/favicon-16.png", type: "image/png", sizes: "16x16" },
    ],
    apple: "/apple-touch-icon.png",
  },
  manifest: "/site.webmanifest",
  appleWebApp: {
    capable: true,
    title: "BetterCmdTab",
    statusBarStyle: "black-translucent",
  },
  // Next only emits the modern `mobile-web-app-capable`; keep the legacy
  // Apple spelling for older iOS Safari.
  other: { "apple-mobile-web-app-capable": "yes" },
  openGraph: {
    type: "website",
    siteName: "BetterCmdTab",
    title: TITLE,
    description: SOCIAL_DESCRIPTION,
    url: "/",
    locale: "en_US",
    images: [
      {
        url: "/og.jpeg",
        secureUrl: `${SITE}/og.jpeg`,
        type: "image/jpeg",
        width: 1200,
        height: 630,
        alt: IMAGE_ALT,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: TITLE,
    description: SOCIAL_DESCRIPTION,
    images: [{ url: "/og.jpeg", alt: IMAGE_ALT }],
  },
};

export const viewport: Viewport = {
  colorScheme: "dark",
  themeColor: "#0a0a0a",
};

// Kept in sync with the on-page FAQ in app/page.tsx. Google restricted FAQ
// rich results to authoritative government and health sites in 2023, so this
// no longer buys a search result — it stays because it is the machine-readable
// form of the page for LLM and non-Google consumers. Matching the visible text
// is the honest thing to do, not a byte-for-byte contract worth bleeding over.
const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE}/#app`,
      name: "BetterCmdTab",
      alternateName: "Better Cmd Tab",
      description:
        "A fast, native Cmd+Tab replacement for macOS: a window switcher and app launcher with grid & list layouts, fuzzy search, window cycling, and zero telemetry.",
      // Trailing slash, matching the canonical Next emits under
      // `trailingSlash: true` and the sitemap entry — one spelling of the
      // homepage across every surface.
      url: `${SITE}/`,
      applicationCategory: "UtilitiesApplication",
      applicationSubCategory: "Window Manager",
      operatingSystem: "macOS 13.0 or later (Apple Silicon & Intel)",
      softwareRequirements: "macOS 13.0+",
      keywords:
        "macOS window switcher, Cmd+Tab replacement, app switcher, alt-tab for mac, app launcher, window manager, AltTab alternative",
      downloadUrl: "https://github.com/rokartur/BetterCmdTab/releases/latest",
      installUrl: "https://github.com/rokartur/BetterCmdTab/releases/latest",
      softwareHelp: "https://github.com/rokartur/BetterCmdTab",
      license: "https://github.com/rokartur/BetterCmdTab/blob/main/LICENSE",
      image: `${SITE}/og.jpeg`,
      screenshot: [`${SITE}/screenshots/list.jpg`, `${SITE}/screenshots/grid.jpg`],
      featureList: [
        "List, grid-of-icons, and live window-preview layouts",
        "Window titles under each icon in grid and preview",
        "Letter-prefix jump to any app",
        "Fuzzy search and launch any installed app",
        "Cycle windows of the front app with Cmd+`",
        "Scoped shortcuts — all windows, this Space, current app, or minimized",
        "Tap to switch instantly or hold to open the switcher",
        "Scroll the mouse wheel to move through apps",
        "Per-app global hotkeys to focus or launch",
        "Tab drill-in for Safari, Chrome, Arc, Finder, and Terminal",
        "Surface native and browser tabs as their own rows",
        "Window tiling to halves and corners, maximize, and center",
        "Move the highlighted window to the next display",
        "Inline quit, close, minimize, maximize, hide, and force-quit",
        "Reopen recently closed apps",
        "Pin favorites, filter the rest, and per-app Cmd+Tab rules",
        "Sort by recents, alphabetically, or launch order",
        "Unread Dock badge counts in the switcher",
        "Audio-playing app indicator",
        "Instant Spaces switching and current-Space-only filtering",
        "Cmd+Tab survives Secure Event Input in password fields",
        "Hide the switcher from screen sharing and recordings",
        "Liquid Glass material on macOS 26, with theming and accent color",
        "Multi-monitor aware — opens under the cursor",
        "Three-finger trackpad gestures with haptics",
        "Export and import your whole setup as a .cmdtab file",
        "Menu-bar agent — no Dock icon, no Electron, zero telemetry",
      ],
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
      },
      author: { "@id": `${SITE}/#author` },
      publisher: { "@id": `${SITE}/#author` },
      isAccessibleForFree: true,
    },
    {
      "@type": "Person",
      "@id": `${SITE}/#author`,
      name: "rokartur",
      url: "https://github.com/rokartur",
    },
    {
      "@type": "WebSite",
      "@id": `${SITE}/#website`,
      name: "BetterCmdTab",
      url: `${SITE}/`,
      inLanguage: "en",
      description: "A fast, native Cmd+Tab window switcher and app launcher for macOS.",
      publisher: { "@id": `${SITE}/#author` },
    },
    {
      "@type": "FAQPage",
      "@id": `${SITE}/#faq`,
      isPartOf: { "@id": `${SITE}/#website` },
      mainEntity: [
        {
          "@type": "Question",
          name: "Is BetterCmdTab free?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Yes. BetterCmdTab is free forever and open-source under GPL v3, with zero telemetry and no subscription.",
          },
        },
        {
          "@type": "Question",
          name: "Which macOS versions and Macs does it support?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "macOS 13.0 or later, on both Apple Silicon and Intel. The Liquid Glass material lights up on macOS 26.",
          },
        },
        {
          "@type": "Question",
          name: "How is it different from AltTab or the built-in Cmd+Tab?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "All three switch what you have open; the real difference is what costs money. The built-in Cmd+Tab only cycles apps — no windows, search, or previews. AltTab is free at its core but now locks search, extra layouts, and multiple shortcuts behind a paid Pro tier. BetterCmdTab is a native AppKit menu-bar app that stays free forever and open-source with no paywall and no telemetry: list, grid, and live-preview layouts, fuzzy search that also launches any installed app, window cycling, browser-tab drill-in, and window tiling the stock switcher cannot do.",
          },
        },
        {
          "@type": "Question",
          name: "Does Cmd+Tab still work in password fields?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Yes. A Carbon survivor trigger keeps the switcher working even while a password field holds Secure Event Input.",
          },
        },
        {
          "@type": "Question",
          name: "Does it collect any data?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "No. There is no telemetry, analytics, or background network. The only network call is an opt-in check for updates on GitHub Releases.",
          },
        },
      ],
    },
  ],
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        {/* React hoists these into <head>. LCP is the featured first
            screenshot, so preload it and let the <img> mark itself
            fetchpriority=high; the rest warm up the runtime release lookup. */}
        <link rel="preload" as="image" href="/screenshots/preview.jpg" fetchPriority="high" />
        <link rel="preconnect" href="https://api.github.com" crossOrigin="" />
        <link rel="dns-prefetch" href="https://api.github.com" />
        <link rel="dns-prefetch" href="https://objects.githubusercontent.com" />

        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        {children}
      </body>
    </html>
  );
}
