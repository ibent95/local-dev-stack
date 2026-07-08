import type { NextConfig } from "next";

const nextConfig: NextConfig = {
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
