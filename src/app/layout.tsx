import type { Metadata, Viewport } from 'next';
import '../components/ember.css';

export const metadata: Metadata = {
  title: 'Ember — Study timer',
  description: 'A gentle study timer and focus journal.',
  appleWebApp: { capable: true, statusBarStyle: 'black-translucent', title: 'Ember' },
};
export const viewport: Viewport = { width: 'device-width', initialScale: 1, viewportFit: 'cover', themeColor: '#131519' };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
