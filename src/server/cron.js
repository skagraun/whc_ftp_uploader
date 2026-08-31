// ============================================================
// Óránkénti ütemező.
// Ez a modul tölti be a .env fájlt, majd elindítja a node-cron
// ütemezőt, ami a beállított időzítés szerint (alapból óránként,
// CRON_EXPRESSION env-vel állítható) meghívja az uploader.js
// feltöltő logikáját.
// A root-beli server.js importálja és hívja meg (initCron()),
// MIELŐTT elindítja a Next.js webszervert.
// ============================================================

// --- dotenv betöltése a projekt gyökeréből ---
import { fileURLToPath } from "url"; // 💡 EZ KELL
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

// --- a többi import ---
import cron from "node-cron";
import { processAndUploadAll } from "./uploader.js";

// --- cron logika ---
// A "started" flag védi ki, hogy véletlenül kétszer regisztráljuk
// az ütemezést (pl. ha initCron() valahonnan mégis kétszer hívódna).
let started = false;

export async function initCron() {
  if (started) return;
  started = true;

  const expr = process.env.CRON_EXPRESSION || "0 * * * *";
  console.log(`[cron] Scheduling job with expression: ${expr}`);

  // Induláskor azonnal lefuttatjuk egyszer (ne kelljen egy órát várni
  // az első feltöltésre, ha épp most indult a szolgáltatás/szerver).
  try {
    await processAndUploadAll();
  } catch (e) {
    console.error("[cron] initial run failed:", e);
  }

  // Ezután a megadott ütemezés szerint (alapból óránként a 0. percben)
  // ismétlődően lefuttatja. Az uploader.js saját belső zárolása védi
  // ki, ha egy tick még nem fejeződött volna be a következő indulásáig.
  cron.schedule(expr, async () => {
    console.log(`[cron] Tick @ ${new Date().toISOString()}`);
    try {
      await processAndUploadAll();
      console.log("[cron] Done.");
    } catch (err) {
      console.error("[cron] Error:", err);
    }
  });
}

// --- belépési pont ---
// Modulbetöltéskor azonnal el is indítjuk - a server.js emiatt csak
// az initCron() Promise-ra vár (a "started" flag miatt ez a hívás
// gyakorlatilag no-op lesz, a tényleges munkát ez az azonnali hívás
// végzi el).
initCron();
