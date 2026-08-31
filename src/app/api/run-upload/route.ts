// ============================================================
// API végpont a kézi indításhoz (a főoldal "Futtatás most" gombja
// ezt hívja meg POST kéréssel). Ugyanazt a feltöltő logikát futtatja
// le azonnal, amit a cron.js egyébként óránként automatikusan meghív.
// ============================================================

import { timingSafeEqual } from "crypto";
import { processAndUploadAll } from "../../../server/uploader.js";

// Egyszerű megosztott titkos kód (shared secret) alapú védelem.
// Enélkül bárki, aki eléri a szervert a hálózaton, elindíthatná a
// feltöltést. A tokent a RUN_UPLOAD_TOKEN env változó adja meg;
// ha nincs beállítva, a végpont véd nélkül fut (csak figyelmeztetünk).
function isAuthorized(req: Request): boolean {
  const expected = process.env.RUN_UPLOAD_TOKEN;
  if (!expected) {
    // Nincs beállítva token -> nincs védelem, csak figyelmeztetünk.
    console.warn(
      "[api/run-upload] RUN_UPLOAD_TOKEN nincs beállítva - a végpont védelem nélkül fut."
    );
    return true;
  }

  const provided = req.headers.get("x-run-token") || "";
  // timingSafeEqual-lel hasonlítunk, hogy ne lehessen az összehasonlítás
  // időzítéséből (timing attack) visszafejteni a token karaktereit.
  const expectedBuf = Buffer.from(expected);
  const providedBuf = Buffer.from(provided);
  if (expectedBuf.length !== providedBuf.length) return false;
  return timingSafeEqual(expectedBuf, providedBuf);
}

export async function POST(req: Request) {
  if (!isAuthorized(req)) {
    return new Response(
      JSON.stringify({ ok: false, message: "Érvénytelen token." }),
      { status: 401, headers: { "content-type": "application/json" } }
    );
  }

  try {
    // Ugyanaz a függvény, amit a cron is hív - a benne lévő zárolás
    // (isRunning) véd az ellen, hogy ez egy épp futó cron tickkel
    // egyszerre próbáljon feltölteni.
    await processAndUploadAll();
    return Response.json({ ok: true, message: "Futtatás kész." });
  } catch (e: unknown) {
    console.error("[api/run-upload] error:", e);

    let message = "Hiba történt.";
    if (e instanceof Error) {
      message = e.message;
    }

    return new Response(JSON.stringify({ ok: false, message }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
}
