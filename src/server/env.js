// ============================================================
// A .env fájl betöltése a projekt gyökeréből.
// Az ütemezést mostantól NEM a Node folyamat végzi (korábban itt
// volt egy node-cron alapú belső időzítő) - a valós órás triggert
// a Windows Task Scheduler adja, ami kívülről hívja meg a
// /api/run-upload végpontot (lásd scripts/server/_trigger-upload.bat
// és install-service.bat). Ez a modul csak annyit csinál, hogy a
// .env-ben megadott értékeket beteszi a process.env-be, amit a
// server.js indításkor importál.
// ============================================================

import { fileURLToPath } from "url";
import path from "path";
import dotenv from "dotenv";

// ESM környezetben saját __dirname definiálás:
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// A .env fájl útvonala (két szinttel feljebb a src/server-ből, azaz
// a projekt gyökerében). FONTOS: production csomagban (deploy-package)
// is ugyanide, a server.js mellé kell tenni a .env fájlt.
const envPath = path.resolve(__dirname, "../../.env");
dotenv.config({ path: envPath });

console.log("[dotenv] WATCH_DIR =", process.env.WATCH_DIR);
