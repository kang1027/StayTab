import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { Download, Globe } from 'lucide-react';
import { appName, gitConfig, homeUrl, docsBasePath } from './shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: (
        <>
          {/* A pre-sized 64px copy (6.5 KB), not the 256px 56 KB master: a
              static export has no image optimizer, so whatever is referenced
              here is what every visitor downloads. next/image would only add
              markup, not resizing. */}
          {/* eslint-disable-next-line next/no-img-element */}
          <img
            src={`${docsBasePath}/icon-64.png`}
            alt=""
            width={22}
            height={22}
            className="rounded-[5px]"
          />
          <span className="font-medium">{appName}</span>
        </>
      ),
    },
    // Dark-only site, so next-themes is off in the provider — without this the
    // layout still renders a switch that cannot do anything.
    themeSwitch: { enabled: false },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
    // `type: 'icon'` items are secondary by default, which is what puts them in
    // the sidebar footer pill alongside the icon `githubUrl` generates.
    links: [
      {
        type: 'icon',
        label: 'Download the latest release',
        text: 'Download',
        icon: <Download />,
        url: `https://github.com/${gitConfig.user}/${gitConfig.repo}/releases/latest`,
        external: true,
      },
      {
        type: 'icon',
        label: `${appName} website`,
        text: 'Website',
        icon: <Globe />,
        // Absolute + external on purpose: the marketing site is a different app
        // on the same host, so client-side routing must not try to handle it.
        url: homeUrl,
        external: true,
      },
    ],
  };
}
