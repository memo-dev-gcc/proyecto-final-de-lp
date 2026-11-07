import { defineConfig } from '@playwright/test';
export default defineConfig({testDir: './test/browser', timeout: 45000, workers: 1, use: {baseURL: 'http://127.0.0.1:4000', headless: true, viewport: {width: 1440, height: 1000}}, reporter: 'list'});
