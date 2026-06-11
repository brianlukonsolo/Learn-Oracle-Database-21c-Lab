import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// base: "./"  -> assets load correctly when served from nginx root.
export default defineConfig({
  base: "./",
  plugins: [react()],
  build: { outDir: "dist" },
});
