import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Skip public assets and API
  if (pathname.startsWith("/_next") || pathname.startsWith("/static") || pathname.includes(".")) {
    return NextResponse.next();
  }

  // Protect dashboard routes server-side by checking for a Supabase cookie token
  if (pathname.startsWith("/dashboard")) {
    const token = req.cookies.get("sb-access-token")?.value || req.cookies.get("supabase-auth-token")?.value || req.cookies.get("sb:token")?.value;
    if (!token) {
      const signInUrl = req.nextUrl.clone();
      signInUrl.pathname = "/auth/sign-in";
      return NextResponse.redirect(signInUrl);
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
    if (!supabaseUrl) {
      // If no Supabase URL is configured, treat as unauthenticated
      const signInUrl = req.nextUrl.clone();
      signInUrl.pathname = "/auth/sign-in";
      return NextResponse.redirect(signInUrl);
    }

    try {
      const resp = await fetch(`${supabaseUrl.replace(/\/$/, '')}/auth/v1/user`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (resp.status !== 200) {
        const signInUrl = req.nextUrl.clone();
        signInUrl.pathname = "/auth/sign-in";
        return NextResponse.redirect(signInUrl);
      }
    } catch (err) {
      const signInUrl = req.nextUrl.clone();
      signInUrl.pathname = "/auth/sign-in";
      return NextResponse.redirect(signInUrl);
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
