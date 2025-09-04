import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";
import runtimeErrorOverlay from "@replit/vite-plugin-runtime-error-modal";

// We export an async function here instead of an object literal so that
// conditional imports (like the optional Replit cartographer plugin)
// are only evaluated when needed. Using top-level `await` inside an
// object literal causes Vite to skip loading this configuration
// entirely on some platforms. Defining the config inside an async
// function avoids that problem and allows Vite to await any dynamic
// imports.
export default defineConfig(async () => {
  // Base plugins that are always included
  const plugins = [
    react(),
    runtimeErrorOverlay(),
  ];

  // Conditionally include the Replit cartographer plugin only when
  // running in development on Replit. Using dynamic import here
  // ensures the dependency is not required in production builds.
  if (process.env.NODE_ENV !== "production" && process.env.REPL_ID !== undefined) {
    const { cartographer } = await import("@replit/vite-plugin-cartographer");
    plugins.push(cartographer());
  }

  return {
    plugins,
    resolve: {
      alias: {
        "@": path.resolve(import.meta.dirname, "client", "src"),
        "@shared": path.resolve(import.meta.dirname, "shared"),
        "@assets": path.resolve(import.meta.dirname, "attached_assets"),
      },
    },
    root: path.resolve(import.meta.dirname, "client"),
    build: {
      outDir: path.resolve(import.meta.dirname, "dist/public"),
      emptyOutDir: true,
    },
    server: {
      fs: {
        strict: true,
        deny: ["**/.*"],
      },
    },
  };
});
