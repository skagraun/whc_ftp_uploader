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
