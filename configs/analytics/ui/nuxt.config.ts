export default defineNuxtConfig({
  compatibilityDate: "2026-07-01",
  devtools: { enabled: true },

  modules: ["@nuxtjs/tailwindcss"],

  // API_URL is set in Dockerfile + docker-compose (internal container address).
  // NUXT_PUBLIC_API_BASE is the alternative env var for local dev (.env).
  runtimeConfig: {
    public: {
      apiBase: process.env.API_URL || process.env.NUXT_PUBLIC_API_BASE || "http://localhost:3001",
    },
  },

  routeRules: {
    "/api/**": {
      proxy: `${process.env.API_URL || process.env.NUXT_PUBLIC_API_BASE || "http://localhost:3001"}/api/**`,
    },
  },

  app: {
    head: {
      title: "LDS Analytics",
      meta: [
        { name: "description", content: "Privacy-first web analytics dashboard" },
      ],
    },
  },

  css: ["~/assets/css/main.scss"],
});
