import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
export default defineConfig({
  root: fileURLToPath(new URL(".", import.meta.url)),
  base: "./",
  define: { "process.env.NODE_ENV": '"production"' },
  plugins: [react()],
  build: {
    outDir: "../Sources/SprigApp/Resources/Markdown",
    emptyOutDir: true,
    chunkSizeWarningLimit: 800,
    lib: {
      entry: fileURLToPath(new URL("preview.jsx", import.meta.url)),
      name: "SprigMarkdown",
      formats: ["iife"],
      fileName: "preview",
      cssFileName: "preview",
    },
  },
});
