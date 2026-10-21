import { packager } from "@electron/packager";
const paths = await packager({
  dir: ".",
  out: "releases",
  name: "Sprig",
  platform: "darwin",
  arch: process.arch,
  overwrite: true,
  asar: true,
  appBundleId: "dev.tandemry.sprig",
  appVersion: "0.1.0",
  prune: true,
  ignore: [
    /^\/src(?:\/|$)/,
    /^\/tests(?:\/|$)/,
    /^\/test-results(?:\/|$)/,
    /^\/design-reference(?:\/|$)/,
    /^\/releases(?:\/|$)/,
    /^\/node_modules(?:\/|$)/,
    /^\/scripts(?:\/|$)/,
    /\.ts$/,
    /\.tsbuildinfo$/,
  ],
});
for (const path of paths) console.log(`Packaged Sprig: ${path}/Sprig.app`);
