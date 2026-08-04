import { NextResponse } from "next/server";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { access_token, refresh_token, expires_at } = body;

    if (!access_token) {
      return NextResponse.json({ error: "missing access_token" }, { status: 400 });
    }

    const res = NextResponse.json({ ok: true });

    const now = Math.floor(Date.now() / 1000);
    const maxAge = expires_at && expires_at > now ? expires_at - now : 60 * 60; // fallback 1h

    res.cookies.set("sb-access-token", access_token, {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge,
    });

    if (refresh_token) {
      // refresh tokens typically live longer
      res.cookies.set("sb-refresh-token", refresh_token, {
        httpOnly: true,
        sameSite: "lax",
        secure: process.env.NODE_ENV === "production",
        path: "/",
        maxAge: 60 * 60 * 24 * 30,
      });
    }

    return res;
  } catch (err) {
    return NextResponse.json({ error: "invalid request" }, { status: 400 });
  }
}
