import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'PL What-If', description: 'Predict fixtures and see the table.' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="max-w-5xl mx-auto p-4 flex gap-4">
          <a href="/" className="font-bold">PL What-If</a>
          <a href="/predict/1">Predict</a>
          <a href="/standings?gw=1">Standings</a>
        </header>
        {children}
      </body>
    </html>
  );
}
