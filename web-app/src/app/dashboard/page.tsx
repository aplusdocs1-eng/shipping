"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabase/supabaseClient";

export default function DashboardPage() {
  const router = useRouter();
  const [checking, setChecking] = useState(true);
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    const supabase = getSupabaseClient();
    supabase.auth.getSession().then(({ data }) => {
      const session = data.session;
      if (!session) {
        router.replace("/auth/sign-in");
        return;
      }
      setEmail(session.user.email ?? null);
      setChecking(false);
    });
  }, [router]);

  async function handleSignOut() {
    const supabase = getSupabaseClient();
    await supabase.auth.signOut();
    // clear server-side cookies too
    await fetch("/api/auth/clear-cookie", { method: "POST" });
    router.push("/auth/sign-in");
  }

  if (checking) {
    return (
      <main className="min-h-screen bg-slate-950 text-white">
        <section className="mx-auto flex min-h-screen max-w-6xl flex-col items-center justify-center px-6 py-24 text-center">
          <div>Checking session…</div>
        </section>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-slate-950 text-white">
      <section className="mx-auto flex min-h-screen max-w-6xl flex-col items-center justify-center px-6 py-24 text-center">
        <div className="rounded-3xl border border-white/10 bg-white/5 p-10 shadow-xl shadow-black/20 backdrop-blur-xl">
          <p className="text-sm uppercase tracking-[0.3em] text-sky-300">Applizone Courier Cloud</p>
          <h1 className="mt-6 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
            Dashboard
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-base leading-8 text-slate-300 sm:text-lg">
            Welcome {email ?? "user"}. This dashboard will become the tenant management and operations center for Applizone Courier Cloud.
          </p>
          <div className="mt-8">
            <button onClick={handleSignOut} className="rounded-full bg-red-500 px-6 py-3 text-sm font-semibold text-white">
              Sign out
            </button>
          </div>
        </div>
      </section>
    </main>
  );
}
