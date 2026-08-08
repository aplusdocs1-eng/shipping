# Deploying

`.vercel/` is gitignored (it holds the built web app and local project
linkage), so the Build Output API config that Vercel actually serves from
lives nowhere durable by default. `vercel-output-config.json` in this
folder is the tracked source of truth for it — copy it into place on every
deploy:

```sh
flutter build web --release
rm -rf .vercel/output/static
cp -r build/web .vercel/output/static
cp deploy/vercel-output-config.json .vercel/output/config.json
vercel deploy --prebuilt --prod --scope shipping-90d17e8c
```

If you skip the `cp` of `config.json` (e.g. because `.vercel/output`
already existed from a previous session with a stale or default config),
the site itself still deploys fine, but **`/api/v1/*` silently stops
proxying to the vendor-api Edge Function** — requests 404 instead of
reaching Supabase. There's no build-time error for this; it only shows up
if someone actually calls the vendor API. That silent-failure mode is
exactly why this file exists instead of just remembering to hand-edit
`config.json` each time.

The `routes` array does two things:
1. Proxies `/api/v1/*` to the `vendor-api` Supabase Edge Function, so
   vendors hit a clean URL on our own domain instead of the raw
   `*.supabase.co` function URL.
2. Falls through to `index.html` for everything else, which is what makes
   Flutter's hash-based client routing (`/#/team`, `/#/customer-login`,
   etc.) work on a hard refresh or direct link.

If you ever add another Edge Function that needs a public HTTP route,
add its proxy rule to this file (before the catch-all) rather than only
editing the live `.vercel/output/config.json`.
