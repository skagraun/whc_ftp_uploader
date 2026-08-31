// Egyszerű health check végpont - csak azt jelzi, hogy a Next.js
// szerver fut és válaszol. Nem ellenőrzi az FTP kapcsolatot vagy a
// cron állapotát, csak azt, hogy a webszerver életben van.
export async function GET() {
  return Response.json({ ok: true, ts: new Date().toISOString() });
}
