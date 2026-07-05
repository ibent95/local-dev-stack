export default defineNuxtConfig({
  compatibilityDate: "2026-07-01",
  devtools: { enabled: true },

  modules: ["@nuxtjs/tailwindcss"],

  runtimeConfig: {
    public: {
      apiBase: process.env.API_URL || "http://localhost:3001",
    },
  },

  routeRules: {
    "/api/**": {
      proxy: `${process.env.API_URL || "http://localhost:3001"}/api/**`,
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
