// ============================================================
// Egyszerű admin felület: mutatja, hogy a feltöltés automatikusan
// (óránként) fut a háttérben, és lehetővé teszi a kézi indítást is
// (pl. hibaelhárításnál, vagy ha nem lehet megvárni a következő órát).
// ============================================================

"use client";

import { useEffect, useState } from "react";

// A böngészőben (localStorage) tároljuk a beírt tokent, hogy ne
// kelljen minden alkalommal újra begépelni. A token soha nem kerül
// bele az elküldött JS kódba (build időben) - csak futásidőben, a
// felhasználó gépeli be, és a kérés fejlécében (header) küldjük el.
const TOKEN_STORAGE_KEY = "whc-run-upload-token";

export default function Page() {
  const [running, setRunning] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [token, setToken] = useState("");

  // Oldal betöltésekor visszatöltjük az utoljára beírt tokent.
  useEffect(() => {
    setToken(localStorage.getItem(TOKEN_STORAGE_KEY) ?? "");
  }, []);

  function onTokenChange(value: string) {
    setToken(value);
    localStorage.setItem(TOKEN_STORAGE_KEY, value);
  }

  // A kézi "Futtatás most" gomb: meghívja a run-upload API route-ot,
  // ami ugyanazt a feltöltő logikát futtatja le, mint a háttérben
  // futó óránkénti cron job.
  async function runNow() {
    setRunning(true);
    setMsg(null);
    try {
      const res = await fetch("/api/run-upload", {
        method: "POST",
        headers: { "x-run-token": token },
      });
      const data: { ok: boolean; message: string } = await res.json();
      setMsg(data?.message ?? "Kész.");
    } catch (e: unknown) {
      let message = "Ismeretlen hiba";
      if (e instanceof Error) {
        message = e.message;
      }
      setMsg(message);
    } finally {
      setRunning(false);
    }
  }

  return (
    <main className="p-8">
      <h1 className="text-2xl font-semibold">FTP Uploader</h1>
      <p className="mt-2 text-sm text-gray-600">
        Óránként automatikusan fut a háttérben. Itt kézzel is indíthatod.
      </p>

      <div className="mt-6 flex items-center gap-3">
        {/* A szerveren beállított RUN_UPLOAD_TOKEN (.env) kell ide -
            enélkül a kézi indítás 401-et kap. */}
        <input
          type="password"
          value={token}
          onChange={(e) => onTokenChange(e.target.value)}
          placeholder="Token"
          className="px-3 py-2 rounded-lg border text-sm"
          title="RUN_UPLOAD_TOKEN"
        />
        <button
          onClick={runNow}
          disabled={running}
          className="px-4 py-2 rounded-lg border"
          title="Run upload job now"
        >
          {running ? "Futtatás…" : "Futtatás most"}
        </button>
        <a
          href="/api/health"
          className="text-blue-600 underline"
          title="Health check JSON"
        >
          Health check
        </a>
      </div>

      {msg && (
        <pre className="mt-4 p-3 rounded-lg border text-sm whitespace-pre-wrap">
          {msg}
        </pre>
      )}
    </main>
  );
}
