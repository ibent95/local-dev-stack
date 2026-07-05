import type { Metadata } from "next";
import "./globals.scss";

export const metadata: Metadata = {
  title: "LDS Wiki",
  description: "Company-wide knowledge base and documentation",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body>{children}</body>
    </html>
  );
}
