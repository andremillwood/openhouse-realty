import type { Metadata, Viewport } from "next";
import {WebApp} from '@/components/pwa/web-app';
import "./globals.css";

export const metadata: Metadata = {
  title: "OpenHouse Realty",
  description: "Personalized property discovery and property management for Jamaica.",
  applicationName: 'Open House Realty',
  appleWebApp: {capable: true, title: 'Open House', statusBarStyle: 'default'},
  icons: {icon: '/brand/app-icon.png', apple: '/brand/app-icon.png'},
};

export const viewport: Viewport = {width: 'device-width', initialScale: 1, viewportFit: 'cover', themeColor: '#003a8c'};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body><WebApp/>{children}</body>
    </html>
  );
}
