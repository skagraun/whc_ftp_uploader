// ============================================================
// Egyedi (custom) Next.js szerver.
// Azért van rá szükség (a szokásos "next start" helyett), hogy a
// .env betöltése (env.js) még a Next.js indítása előtt megtörténjen,
// és hogy egy tetszőleges porton, saját http szerverrel fusson.
//
// FONTOS ARCHITEKTÚRA-VÁLTÁS: ez a folyamat MÁR NEM ütemez semmit
// belsőleg (korábban egy node-cron alapú órás időzítő is itt futott).
// A tényleges órás feltöltést a Windows Task Scheduler indítja
// KÍVÜLRŐL, a /api/run-upload végpont hívásával
// (lásd scripts/server/_trigger-upload.bat). Ennek a folyamatnak
// csak a webes felületet (health check + kézi "Futtatás most" gomb
// + maga a run-upload API) kell folyamatosan kiszolgálnia, ezért
// ezt Task Scheduler "onstart" triggerrel indítjuk (lásd
// scripts/server/install-service.bat), az órás triggert pedig
// egy külön, "hourly" scheduled task adja.
// ============================================================

import "./src/server/env.js";
import { notifyFailure, writeLog } from "./src/server/uploader.js";
import next from "next";
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// A Next.js "output: standalone" build szándékosan NEM másolja be a
// webpack csomagot a node_modules/next alá (build-time only, futáshoz
// nem kell) - Next SAJÁT generált standalone server.js-e ezt úgy
// kezeli, hogy indításkor beállítja a __NEXT_PRIVATE_STANDALONE_CONFIG
// env változót, aminek hatására a Next belső config-betöltője elnyeli
// az emiatt keletkező "Cannot find module" hibát ahelyett, hogy
// elszállna vele (lásd next/dist/server/config.js, loadWebpackHook()
// hívás körül). A mi egyedi server.js-ünknek ugyanezt kell tennie,
// a Next által build-kor előre kiszámolt configgal (.next/required-
// server-files.json) - enélkül a szerver időzítéstől/gépi
// környezettől függően (!) induláskor elszállhat pontosan ezzel a
// hibával: "Cannot find module 'next/dist/compiled/webpack/webpack'".
const requiredServerFiles = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, ".next", "required-server-files.json"),
    "utf8"
  )
);
process.env.__NEXT_PRIVATE_STANDALONE_CONFIG = JSON.stringify(
  requiredServerFiles.config
);

// ------------------------------------------------------------
// Végzetes (el nem kapott) hibák kezelése.
// Korábban ha a folyamat egy el nem kapott hiba miatt elszállt
// (gyanú: a lezárt FTP port miatti ECONNRESET), a szerver csendben
// leállt, és napokig nem futott egyetlen feltöltés sem - se napi log,
// se e-mail nem jelezte. Most elszállás előtt:
//   1. a teljes hibát (stack trace-szel) kiírjuk a konzolra
//      (-> LOG\server-console.log) ÉS a napi logba,
//   2. e-mailt küldünk róla,
//   3. kilépünk - a _run.bat ciklusa 30 mp múlva újraindítja.
// Szándékosan NEM futunk tovább a hiba után: egy el nem kapott hiba
// után a folyamat állapota bizonytalan, a tiszta újraindítás a
// biztonságos megoldás.
// ------------------------------------------------------------
let crashing = false;
async function onFatal(kind, err) {
  if (crashing) return; // ha a kezelés közben újabb hiba jönne
  crashing = true;
  const detail = err instanceof Error ? err.stack || err.message : String(err);
  console.error(`[server] FATAL ${kind}:`, detail);

  // Biztosíték: ha a naplózás/e-mail küldés valamiért beragadna,
  // legkésőbb 60 mp múlva akkor is kilépünk (és újraindulunk).
  setTimeout(() => process.exit(1), 60_000).unref();
  try {
    const watchDir = process.env.WATCH_DIR;
    if (watchDir) {
      await writeLog(watchDir, `FATAL: server process crashed (${kind}): ${detail}`);
    }
    await notifyFailure(watchDir || "(ismeretlen WATCH_DIR)", [
      `A webszerver folyamat elszállt (${kind}), a _run.bat 30 mp múlva újraindítja.`,
      detail,
    ]);
  } finally {
    process.exit(1);
  }
}
process.on("uncaughtException", (err) => onFatal("uncaughtException", err));
process.on("unhandledRejection", (err) => onFatal("unhandledRejection", err));

const port = process.env.PORT || 3000;
const dev = process.env.NODE_ENV !== "production";
const app = next({ dev });
const handle = app.getRequestHandler();

await app.prepare();

http
  .createServer((req, res) => handle(req, res))
  .listen(port, () => {
    console.log(`> Ready on http://localhost:${port}`);
  });
