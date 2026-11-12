import { defineConfig } from 'vite';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '.generated');
export default defineConfig({
  root,
  appType: 'mpa',
  publicDir: 'public',
  build: {
    outDir: resolve(import.meta.dirname, 'dist'),
    emptyOutDir: true,
    rolldownOptions: {
      input: Object.fromEntries(['index', 'privacy/index', 'terms/index', 'support/index', '404']
        .map((page) => [page, resolve(root, `${page}.html`)])),
    },
  },
});
