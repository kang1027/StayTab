/**
 * Refreshes src/releases.json — the release snapshot the page renders before
 * (and instead of, when GitHub's anonymous rate limit is exhausted) the
 * client-side fetch lands. Committed so local builds work offline; CI runs
 * this before `bun run build` with a token, see deploy-web.yml.
 *
 *   bun run scripts/fetch-releases.ts
 */
import { writeFileSync } from "node:fs";
import { join } from "node:path";

interface Asset {
  name: string;
  browser_download_url: string;
  download_count: number;
}
interface Release {
  tag_name: string;
  prerelease: boolean;
  assets: Asset[];
}

const token = process.env.GITHUB_TOKEN;
const res = await fetch(
  "https://api.github.com/repos/rokartur/BetterCmdTab/releases?per_page=100",
  {
    headers: {
      Accept: "application/vnd.github+json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  },
);
if (!res.ok) throw new Error(`fetch-releases: GitHub API ${res.status} ${await res.text()}`);

const releases = (await res.json()) as Release[];
if (releases.length === 0) throw new Error("fetch-releases: no releases returned");

// Keep only the fields the page reads — the snapshot ships inside the JS bundle.
const trimmed = releases.map((r) => ({
  tag_name: r.tag_name,
  prerelease: r.prerelease,
  assets: r.assets.map((a) => ({
    name: a.name,
    browser_download_url: a.browser_download_url,
    download_count: a.download_count,
  })),
}));

const out = join(import.meta.dir, "..", "src", "releases.json");
writeFileSync(out, `${JSON.stringify(trimmed, null, 2)}\n`);
console.log(`fetch-releases: wrote ${trimmed.length} releases (latest ${trimmed[0].tag_name})`);
