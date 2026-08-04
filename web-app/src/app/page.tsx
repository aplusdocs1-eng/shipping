export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-950 to-black text-slate-100">
      <header className="border-b border-slate-800">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-lg bg-gradient-to-br from-sky-400 to-indigo-500 shadow-md" />
            <span className="font-semibold">Applizone</span>
            <span className="text-sm text-slate-500">Courier Cloud</span>
          </div>
          <nav className="flex items-center gap-4">
            <a href="/auth/sign-in" className="text-sm text-slate-300 hover:text-white">Sign in</a>
            <a href="/auth/sign-up" className="rounded-full bg-sky-400 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-sky-300">Get started</a>
          </nav>
        </div>
      </header>

      <section className="mx-auto max-w-6xl px-6 py-20">
        <div className="grid grid-cols-1 gap-12 lg:grid-cols-2 lg:items-center">
          <div>
            <p className="text-sm uppercase tracking-[0.3em] text-sky-300">Applizone Courier Cloud</p>
            <h1 className="mt-6 text-4xl font-extrabold leading-tight tracking-tight text-white sm:text-5xl">
              Manage deliveries, drivers, and warehouses — all from one place
            </h1>
            <p className="mt-6 max-w-xl text-lg text-slate-300">
              Multi-tenant logistics platform with tenant-aware data isolation, real-time updates, and simple onboarding for courier and freight operations.
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <a href="/auth/sign-up" className="inline-flex items-center gap-3 rounded-full bg-sky-400 px-5 py-3 text-sm font-semibold text-slate-900 hover:bg-sky-300">
                Create free account
              </a>
              <a href="/auth/sign-in" className="inline-flex items-center gap-3 rounded-full border border-slate-700 px-5 py-3 text-sm text-slate-200 hover:border-slate-600">
                Sign in
              </a>
            </div>

            <div className="mt-12 grid grid-cols-2 gap-4 sm:grid-cols-3">
              <div className="rounded-xl bg-white/3 p-4">
                <p className="text-sm font-medium text-white">Tenant Isolation</p>
                <p className="mt-2 text-xs text-slate-300">Per-tenant data separation with RBAC and policies.</p>
              </div>
              <div className="rounded-xl bg-white/3 p-4">
                <p className="text-sm font-medium text-white">Realtime Status</p>
                <p className="mt-2 text-xs text-slate-300">Live tracking of deliveries and drivers.</p>
              </div>
              <div className="rounded-xl bg-white/3 p-4">
                <p className="text-sm font-medium text-white">Integrations</p>
                <p className="mt-2 text-xs text-slate-300">Supabase, SMS, Email, and popular courier APIs.</p>
              </div>
            </div>
          </div>

          <div className="order-first -mt-6 lg:order-last lg:mt-0">
            <div className="relative">
              <div className="pointer-events-none absolute -inset-0.5 rounded-2xl bg-gradient-to-tr from-indigo-600 via-sky-500 to-emerald-400 blur opacity-30" />
              <div className="relative overflow-hidden rounded-2xl bg-gradient-to-b from-slate-900 to-slate-800 p-6 shadow-2xl">
                <div className="h-72 w-full rounded-xl bg-gradient-to-br from-slate-700 to-slate-900 p-6">
                  <div className="h-full w-full rounded-lg border border-white/5 bg-[url('/next.svg')] bg-center bg-no-repeat bg-contain" />
                </div>
                <div className="mt-4 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium">Live Delivery Feed</p>
                    <p className="text-xs text-slate-400">Updates in seconds</p>
                  </div>
                  <div className="text-xs text-slate-400">Demo</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <footer className="border-t border-slate-800">
        <div className="mx-auto max-w-6xl px-6 py-8 text-sm text-slate-500">
          <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
            <div>© {new Date().getFullYear()} Applizone. All rights reserved.</div>
            <div className="flex items-center gap-4">
              <a href="#" className="hover:text-white">Privacy</a>
              <a href="#" className="hover:text-white">Terms</a>
              <a href="#" className="hover:text-white">Contact</a>
            </div>
          </div>
        </div>
      </footer>
    </main>
  );
}
