import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // "standalone" build: a .next/standalone mappába bekerül egy
  // önálló, minimális node_modules is, így a szerverre telepítéskor
  // NEM kell "npm install"-t futtatni - csak node.exe kell hozzá.
  // Lásd: scripts/deploy-package.sh
  output: "standalone",
};

export default nextConfig;
