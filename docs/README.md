# docs

The BetterCmdTab documentation site — [Next.js](https://nextjs.org) +
[Fumadocs](https://fumadocs.dev), served at `bettercmdtab.app/docs`.

```bash
bun install
bun run dev            # http://localhost:3000/docs  (the /docs prefix is real)
bun run lint
bun run types:check
bun run build          # static export into out/
bun run preview        # serve the built out/ — there is no `next start`
```

Contributing to these docs — page structure, the generated config reference, the
`basePath` rules, and the accuracy bar for anything describing the app — is
covered in [CONTRIBUTING.md](CONTRIBUTING.md). Read that before editing.

## How it ships

`output: 'export'` with `basePath: '/docs'`, so the build is a directory of static
files whose URLs already carry the `/docs` prefix. The **root** `Dockerfile`
builds this together with `../web`, copies this export into `web/out/docs`, and
serves both from one nginx image — no docs server, no reverse proxy.
