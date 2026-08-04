# Applizone Courier Cloud — Web App

This repository contains the Next.js frontend for the Applizone Courier Cloud SaaS platform.

## Local development

1. Copy `.env.example` to `.env.local`
2. Fill in your Supabase settings:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `NEXTAUTH_SECRET`
3. Install dependencies:

```bash
npm install
```

4. Run the app:

```bash
npm run dev
```

Open [http://127.0.0.1:3000](http://127.0.0.1:3000).

## Supabase

The root `supabase/` folder contains database migrations, seed scripts, and local Supabase config.
The app uses `@supabase/supabase-js` for client-side access and server-side trusted actions should use the service role key.

## Project structure

- `src/app/` — application routes and layouts
- `src/components/` — shared UI components and primitives
- `src/lib/` — authentication, Supabase clients, and domain utilities
- `src/types/` — shared TypeScript types and business models
- `web-app/.env.example` — example environment variables

## Next steps

- Implement tenant resolution from hostname
- Add authentication with Supabase Auth and session-aware middleware
- Build tenant, customer, warehouse, driver, and platform route groups
- Add tests using Vitest and Playwright

## Build

```bash
npm run build
```

## Lint

```bash
npm run lint
```

## Middleware and server-side auth (notes)

- A simple middleware has been added at `src/middleware.ts` to protect `/dashboard` server-side.
- The middleware looks for common Supabase cookie names (for example `sb-access-token` or `supabase-auth-token`) and redirects unauthenticated requests to `/auth/sign-in`.
- By default the app uses the client-side Supabase auth flow (localStorage/session). To enable cookie-based SSR sessions, configure Supabase auth to set cookies on sign-in or adapt middleware to verify JWTs using a server-side key.

## Environment

- Copy `.env.local.example` to `.env.local` and populate the Supabase keys and `NEXTAUTH_SECRET` for local development.

