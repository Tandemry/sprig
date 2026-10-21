import { execFileSync } from "node:child_process";
import { copyFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
const root = fileURLToPath(new URL("../../", import.meta.url));
execFileSync(
  "node_modules/.bin/vite",
  ["build", "--config", "native/renderer/vite.config.ts"],
  { cwd: root, stdio: "inherit" },
);
copyFileSync(
  new URL("../renderer/template.html", import.meta.url),
  new URL("../Sources/SprigApp/Resources/Markdown/index.html", import.meta.url),
);

// Ship the dependency licence texts alongside the bundled renderer.
const { readFileSync, readdirSync, writeFileSync, existsSync } = await import('node:fs');
const { join } = await import('node:path');
const lock = JSON.parse(readFileSync(join(root, 'package-lock.json'), 'utf8'));
const notices = ['Sprig bundled editor — third-party notices\n'];
for (const [path, metadata] of Object.entries(lock.packages)) {
  if (!path || metadata.dev || !path.startsWith('node_modules/')) continue;
  const directory = join(root, path);
  if (!existsSync(directory)) continue;
  const licences = readdirSync(directory).filter(name => /^(licen[cs]e|copying|notice)(\.|$)/i.test(name));
  if (!licences.length) continue;
  notices.push(`\n${path.replace(/^node_modules\//, '')} ${metadata.version}\n`);
  for (const file of licences) notices.push(readFileSync(join(directory, file), 'utf8'));
}
writeFileSync(new URL('../Sources/SprigApp/Resources/Markdown/THIRD_PARTY_NOTICES.txt', import.meta.url), notices.join('\n'));
