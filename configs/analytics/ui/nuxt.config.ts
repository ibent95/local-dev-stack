export default defineNuxtConfig({
  compatibilityDate: "2026-07-01",
  devtools: { enabled: true },

  modules: ["@nuxtjs/tailwindcss"],

  // Nuxt auto-maps NUXT_PUBLIC_* env vars to runtimeConfig.public.*
  // So NUXT_PUBLIC_API_BASE from .env → runtimeConfig.public.apiBase
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || "http://localhost:3001",
    },
  },

  routeRules: {
    "/api/**": {
      proxy: `${process.env.NUXT_PUBLIC_API_BASE || "http://localhost:3001"}/api/**`,
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
