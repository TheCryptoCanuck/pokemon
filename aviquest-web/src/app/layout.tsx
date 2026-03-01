import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AviQuest - Bird Identification & Collection',
  description: 'Identify birds, build your aviary, and become a Master Birder. A gamified bird-watching web app.',
};

export const viewport: Viewport = {
  themeColor: '#0A1F0F',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
