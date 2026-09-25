// ============================================================
// A tényleges feltöltési logika.
// Feladata: a WATCH_DIR mappában lévő .txt fájlokat (csekkolási
// időpontok) feltölteni egy FTPS szerverre, majd sikeres feltöltés
// után átmozgatni őket egy "uploaded" almappába, hogy legközelebb
// már ne dolgozza fel újra ugyanazokat.
// Ezt a modult a run-upload API route hívja meg - akár a Windows
// Task Scheduler órás triggere (lásd scripts/server/_trigger-upload.bat),
// akár a webes felület "Futtatás most" gombja hívja meg a végpontot.
// ============================================================

import fs from "fs/promises";
import { open as fsOpen } from "fs/promises";
import path from "path";
import { Client } from "basic-ftp";
import nodemailer from "nodemailer";

// segéd: kötelező env - ha hiányzik, azonnal hibát dobunk (fail-fast),
// nehogy pl. üres FTP_HOST-tal próbáljunk csatlakozni.
function required(name, val) {
  if (!val) throw new Error(`Missing env: ${name}`);
  return val;
}

// --- Globális log queue a párhuzamos írások sorosítására ---
// Mivel egyszerre több fájl logolása is történhet (for ciklusban),
// ez a Promise lánc biztosítja, hogy a log sorok mindig egyesével,
// a helyes sorrendben íródjanak a fájlba, ne keveredjenek össze.
let logQueue = Promise.resolve();

async function safeAppendFile(file, data) {
  // Windows-on előfordulhat, hogy a log fájlt épp más folyamat
  // (pl. víruskereső, vagy egy másik indítási kísérlet) zárolja -
  // ezért 10 próbálkozás, egyre növekvő várakozással (100ms, 200ms, ...).
  for (let i = 1; i <= 10; i++) {
    try {
      const handle = await fsOpen(file, "a"); // explicit handle -> kevesebb sharing gond
      await handle.write(data);
      await handle.close();
      return;
    } catch (err) {
      if (
        err.code === "EPERM" ||
        err.code === "EBUSY" ||
        err.code === "EACCES"
      ) {
        await new Promise((r) => setTimeout(r, 100 * i)); // 100ms,200ms,...1s
      } else {
        console.error("[log] write failed:", err.message);
        return;
      }
    }
  }
  console.error("[log] giving up (locked):", file);
}

// A log mappa útvonala: LOG_DIR env változó, vagy alapértelmezetten
// a figyelt mappa (WATCH_DIR) alatti "LOG" almappa.
function resolveLogDir(baseDir) {
  return process.env.LOG_DIR && process.env.LOG_DIR.trim()
    ? process.env.LOG_DIR.trim()
    : path.join(baseDir, "LOG");
}

// A régi napi log fájlokat töröljük LOG_RETENTION_DAYS napnál
// régebben (alapértelmezetten 90 nap), hogy a log mappa ne nőjön a
// végtelenségig. 0 vagy negatív érték esetén a törlés ki van kapcsolva.
// FONTOS: ez KIZÁRÓLAG a log fájlokra vonatkozik - a feltöltött
// .txt fájlokat (az "uploaded" almappában) sosem töröljük automatikusan.
async function cleanupOldLogs(baseDir) {
  const retentionDays = Number(process.env.LOG_RETENTION_DAYS ?? 90);
  if (!retentionDays || retentionDays <= 0) return;

  const LOG_DIR = resolveLogDir(baseDir);
  const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;

  let entries;
  try {
    entries = await fs.readdir(LOG_DIR, { withFileTypes: true });
  } catch {
    return; // a LOG mappa még nem létezik - nincs mit törölni
  }

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith(".log")) continue;
    const filePath = path.join(LOG_DIR, entry.name);
    try {
      const stat = await fs.stat(filePath);
      if (stat.mtimeMs < cutoff) {
        await fs.unlink(filePath);
        console.log(`[uploader] Old log deleted: ${filePath}`);
      }
    } catch (err) {
      console.error(`[uploader] Failed to clean up log ${filePath}:`, err.message);
    }
  }
}

// Naponta egy logfájlba ír (YYYY-MM-DD.log), alapértelmezetten a
// WATCH_DIR/LOG mappába, vagy a LOG_DIR env változóban megadott helyre.
export async function writeLog(baseDir, message) {
  try {
    const LOG_DIR = resolveLogDir(baseDir);

    await fs.mkdir(LOG_DIR, { recursive: true });

    const today = new Date().toISOString().slice(0, 10);
    const logFile = path.join(LOG_DIR, `${today}.log`);
    const line = `[${new Date()
      .toISOString()
      .replace("T", " ")
      .replace("Z", "")}] ${message}\n`;

    // Sorosítás — minden íróművelet vár az előzőre
    logQueue = logQueue.then(() => safeAppendFile(logFile, line));
    return logQueue;
  } catch (err) {
    console.error("Failed to write log (outer):", err);
  }
}

// E-mail értesítés sikertelen feltöltésről (SMTP_HOST + ALERT_EMAIL_TO
// env változókkal állítható). Ha ezek nincsenek beállítva, nincs
// e-mail küldés, csak egy figyelmeztetés a konzolon - a feltöltési
// logika ettől függetlenül lefut, egy elakadt e-mail küldés sosem
// akaszthatja meg a feltöltést.
// Exportálva van, mert a server.js is ezt hívja, ha maga a szerver
// folyamat száll el egy el nem kapott hiba miatt.
export async function notifyFailure(watchDir, errorLines) {
  const SMTP_HOST = process.env.SMTP_HOST;
  const ALERT_EMAIL_TO = process.env.ALERT_EMAIL_TO;

  if (!SMTP_HOST || !ALERT_EMAIL_TO) {
    console.warn(
      "[uploader] SMTP_HOST vagy ALERT_EMAIL_TO nincs beállítva - nem küldök e-mail értesítést a sikertelen feltöltésről."
    );
    return;
  }

  try {
    const transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 25),
      secure: false,
      // Rövid időkorlátok: a nodemailer alapértelmezései percekben
      // mérhetők (pl. 10 perc socket timeout), és egy nem válaszoló
      // relay miatt addig lógna a futás (és vele az isRunning zár).
      connectionTimeout: 15_000,
      greetingTimeout: 15_000,
      socketTimeout: 30_000,
    });

    await transporter.sendMail({
      from: process.env.SMTP_FROM || "whc-ftp-uploader@opmobility.com",
      to: ALERT_EMAIL_TO,
      subject: `[WHC FTP Uploader] Sikertelen feltöltés - ${watchDir}`,
      text: [
        `A feltöltés nem sikerült (${new Date().toISOString()}).`,
        `Figyelt mappa: ${watchDir}`,
        "",
        "Hibák:",
        ...errorLines.map((line) => `- ${line}`),
      ].join("\n"),
    });
    console.log(`[uploader] Failure notification sent to ${ALERT_EMAIL_TO}`);
    await logIfPossible(`Failure notification e-mail sent to ${ALERT_EMAIL_TO}`);
  } catch (err) {
    // Az e-mail küldés hibája sosem dobjon tovább - a feltöltés
    // eredménye a log fájlban és a konzolon amúgy is megvan.
    // A napi logba IS beírjuk: korábban ez csak a konzolra ment, így
    // abból, hogy "nem jött e-mail", utólag nem derült ki, miért.
    console.error("[uploader] Failed to send failure notification:", err.message || err);
    await logIfPossible(`Failure notification e-mail FAILED: ${err.message || err}`);
  }
}

// A napi logba ír, de csak ha a WATCH_DIR be van állítva - a
// notifyFailure olyankor is lefuthat, amikor épp a konfiguráció
// hiányzik (ilyenkor csak a konzolra megy a bejegyzés).
async function logIfPossible(msg) {
  if (process.env.WATCH_DIR) await writeLog(process.env.WATCH_DIR, msg);
}

// Védelem az egyidejű futás ellen: ha a Task Scheduler órás triggere
// épp fut, és eközben valaki megnyomja a "Futtatás most" gombot (vagy
// egy lassú FTP miatt két hívás lógna egymásba), a második hívás
// egyszerűen kilép, nem indít párhuzamos feltöltést. E nélkül ugyanaz
// a fájl kétszer is felkerülhetne az FTP-re, mielőtt bármelyik oldal
// átmozgatná. (A Task Scheduler-nek magának is van "ha még fut, ne
// indíts újat" beállítása - ez itt egy plusz, alkalmazásszintű védelem.)
let isRunning = false;

export async function processAndUploadAll() {
  if (isRunning) {
    console.log("[uploader] Skipped: previous run still in progress.");
    return;
  }
  isRunning = true;
  try {
    await runUploadJob();
  } catch (err) {
    // Ide akkor futunk, ha MÉG A KONFIGURÁCIÓ/ELŐKÉSZÍTÉS is elhasalt
    // (pl. hiányzó/törölt .env, rossz WATCH_DIR útvonal, nem elérhető
    // mappa) - tehát azelőtt, hogy bármi a WATCH_DIR-be tudna írni
    // log fájlt. E nélkül az ilyen hiba szó szerint észrevétlen
    // maradna: se log, se e-mail nem menne ki róla.
    const msg = `Uploader job crashed before completing: ${err.message || err}`;
    console.error(`[uploader] ${msg}`);
    await notifyFailure(process.env.WATCH_DIR || "(ismeretlen WATCH_DIR)", [msg]);
  } finally {
    isRunning = false;
  }
}

// A tényleges munka: fájlok összegyűjtése, FTP kapcsolat, feltöltés,
// majd a sikeresen feltöltött fájlok áthelyezése.
async function runUploadJob() {
  const WATCH_DIR = required("WATCH_DIR", process.env.WATCH_DIR);
  const UPLOADED_SUBDIR = process.env.UPLOADED_SUBDIR || "uploaded";

  const FTP_HOST = required("FTP_HOST", process.env.FTP_HOST);
  const FTP_USER = required("FTP_USER", process.env.FTP_USER);
  const FTP_PASSWORD = required("FTP_PASSWORD", process.env.FTP_PASSWORD);
  const FTP_PORT = Number(process.env.FTP_PORT || 990);
  const FTP_REMOTE_DIR = process.env.FTP_REMOTE_DIR || "/";

  const uploadDir = path.join(WATCH_DIR, UPLOADED_SUBDIR);
  await fs.mkdir(uploadDir, { recursive: true });

  // Régi log fájlok törlése (lásd LOG_RETENTION_DAYS) - minden
  // futáskor lefut, hogy a log mappa ne nőjön a végtelenségig.
  await cleanupOldLogs(WATCH_DIR);

  // Csak a WATCH_DIR gyökerében lévő .txt fájlokat nézzük (nem
  // rekurzív), így az "uploaded" almappába már kikerült fájlokat
  // nem dolgozzuk fel újra.
  const entries = await fs.readdir(WATCH_DIR, { withFileTypes: true });
  const txtFiles = entries
    .filter((e) => e.isFile() && e.name.toLowerCase().endsWith(".txt"))
    .map((e) => e.name)
    .sort();

  if (txtFiles.length === 0) {
    console.log(`[uploader] No .txt files in ${WATCH_DIR}`);
    await writeLog(WATCH_DIR, "No .txt files found.");
    return;
  }

  // Ide gyűjtjük a futás közben történt hibákat, hogy a végén EGY
  // összefoglaló e-mailt küldjünk (ne fájlonként/hibánként külön-külön).
  const errors = [];

  const client = new Client(30_000);
  client.ftp.verbose = false;

  try {
    await client.access({
      host: FTP_HOST,
      user: FTP_USER,
      password: FTP_PASSWORD,
      port: FTP_PORT,
      secure: "implicit", // FTPS, implicit TLS (a whc.hu szerver ezt várja a 990-es porton)
      secureOptions: {
        // minVersion: "TLSv1.2",
        rejectUnauthorized: false, // csak akkor kell, ha a szerver self-signed (nem hiteles) tanúsítványt használ
      },
    });

    await client.ensureDir(FTP_REMOTE_DIR);

    // Fájlonként külön try/catch: ha egy fájl feltöltése elhasal,
    // a többi fájl feldolgozása attól még folytatódik.
    for (const name of txtFiles) {
      const full = path.join(WATCH_DIR, name);

      try {
        console.log(
          `[uploader] Uploading ${name} -> ${FTP_REMOTE_DIR}/${name}`
        );
        await client.uploadFrom(full, name);

        // Csak SIKERES feltöltés után mozgatjuk át - így ha a
        // feltöltés elhasal, a fájl a WATCH_DIR-ben marad, és a
        // következő futás (óránként) újra megpróbálja.
        const target = path.join(uploadDir, name);
        await fs.rename(full, target);

        const msg = `SUCCESS: ${name} uploaded to ${FTP_REMOTE_DIR} and moved to ${target}`;
        console.log(`[uploader] ${msg}`);
        await writeLog(WATCH_DIR, msg);
      } catch (fileErr) {
        const msg = `ERROR: ${name} failed: ${fileErr.message || fileErr}`;
        console.error(`[uploader] ${msg}`);
        await writeLog(WATCH_DIR, msg);
        errors.push(msg);
      }
    }
  } catch (err) {
    // Ide akkor futunk be, ha már maga a bejelentkezés (client.access)
    // vagy a távoli mappa létrehozása (ensureDir) sem sikerült -
    // ilyenkor egyetlen fájl sem lett feltöltve.
    const msg = `FTP connection error: ${err.message || err}`;
    console.error(`[uploader] ${msg}`);
    await writeLog(WATCH_DIR, msg);
    errors.push(msg);
  } finally {
    client.close();
  }

  // Ha bármi hiba történt (kapcsolódási hiba vagy egyes fájlok
  // sikertelen feltöltése), e-mail értesítés megy ki - fontos, hogy
  // időben kiderüljön, ha a fájlok nem jutottak fel az FTP szerverre.
  if (errors.length > 0) {
    await notifyFailure(WATCH_DIR, errors);
  }
}
