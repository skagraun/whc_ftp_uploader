// ============================================================
// Egyedi (custom) Next.js szerver.
// Azért van rá szükség (a szokásos "next start" helyett), mert
// ebben az egy Node folyamatban KÉT dolgot indítunk el együtt:
//   1) a Next.js webes felületet (health check + kézi indítás gomb),
//   2) a háttérben futó óránkénti FTP feltöltő ütemezőt (cron.js).
// Így elég egyetlen Windows-os feladatot/szolgáltatást beállítani
// a szerveren - nem kell külön folyamat a webnek és külön a cronnak.
// ============================================================

import next from "next";
import http from "http";
import { initCron } from "./src/server/cron.js";

const port = process.env.PORT || 3000;
const dev = process.env.NODE_ENV !== "production";
const app = next({ dev });
const handle = app.getRequestHandler();

await app.prepare();

// FONTOS: a cron.js modul betöltésekor (a fenti import miatt) az
// ütemező már elindult a háttérben, MIELŐTT ez a sor lefutna - az
// alábbi await gyakorlatilag azonnal visszatér (nem várja meg az
// első feltöltési kört), csak biztosítja, hogy a modul be legyen
// töltve. Lásd a cron.js tetején lévő megjegyzést.
await initCron();

http
  .createServer((req, res) => handle(req, res))
  .listen(port, () => {
    console.log(`> Ready on http://localhost:${port}`);
  });
