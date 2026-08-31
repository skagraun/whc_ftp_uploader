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
