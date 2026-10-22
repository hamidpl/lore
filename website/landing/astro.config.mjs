// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// Lore landing page — English only, deployed to lorekit.net.
// The multilingual surface is the docs subdomain (docs.lorekit.net).
// https://astro.build/config
export default defineConfig({
  site: 'https://lorekit.net',
  integrations: [sitemap()],
});
