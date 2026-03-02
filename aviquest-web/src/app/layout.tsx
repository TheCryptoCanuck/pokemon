import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AviQuest - Bird Identification & Collection",
  description:
    "Identify birds, build your aviary, and explore 60+ species across 4 rarity tiers. A web version of the AviQuest mobile game.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
