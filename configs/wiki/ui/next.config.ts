import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Next.js 16 uses Turbopack by default; explicit config here for clarity
  turbopack: {},

  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${process.env.API_URL || "http://localhost:3003"}/api/:path*`,
      },
    ];
  },
  output: "standalone",
};

export default nextConfig;
