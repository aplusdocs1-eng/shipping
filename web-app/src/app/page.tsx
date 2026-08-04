export default function Home() {
  return (
    <main className="min-h-screen bg-slate-950 text-white">
      <section className="mx-auto flex min-h-screen max-w-6xl flex-col items-center justify-center px-6 py-24 text-center">
        <div className="rounded-3xl border border-white/10 bg-white/5 p-10 shadow-xl shadow-black/20 backdrop-blur-xl">
          <p className="text-sm uppercase tracking-[0.3em] text-sky-300">Applizone Courier Cloud</p>
          <h1 className="mt-6 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
            Multi-tenant logistics SaaS for courier and freight operations.
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-base leading-8 text-slate-300 sm:text-lg">
            Bootstrap of the Applizone Courier Cloud platform. Tenant-aware routing, Supabase-backed data isolation, and operational workflows are now being implemented.
          </p>
          <div className="mt-10 flex flex-col gap-3 sm:flex-row sm:justify-center">
            <a
              href="/auth/sign-in"
              className="rounded-full bg-sky-400 px-6 py-3 text-sm font-semibold text-slate-950 transition hover:bg-sky-300"
            >
              Sign in
            </a>
            <a
              href="/auth/sign-up"
              className="rounded-full border border-slate-200/10 px-6 py-3 text-sm font-semibold text-white transition hover:border-slate-100/20 hover:bg-white/5"
            >
              Get started
            </a>
          </div>
        </div>
      </section>
    </main>
  );
}
