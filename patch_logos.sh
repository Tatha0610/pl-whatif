#!/usr/bin/env bash
set -euo pipefail

mkdir -p src/lib

# 1) Create the team logo map
cat > src/lib/teamLogos.ts <<'TS'
export const teamLogos: Record<string, string> = {
  "Arsenal": "https://upload.wikimedia.org/wikipedia/en/5/53/Arsenal_FC.svg",
  "Manchester City": "https://upload.wikimedia.org/wikipedia/en/e/eb/Manchester_City_FC_badge.svg",
  "Liverpool": "https://upload.wikimedia.org/wikipedia/en/0/0c/Liverpool_FC.svg",
  "Tottenham Hotspur": "https://upload.wikimedia.org/wikipedia/en/b/b4/Tottenham_Hotspur.svg",
  "Chelsea": "https://upload.wikimedia.org/wikipedia/en/c/cc/Chelsea_FC.svg",
  "Manchester United": "https://upload.wikimedia.org/wikipedia/en/7/7a/Manchester_United_FC_crest.svg",
  "Newcastle United": "https://upload.wikimedia.org/wikipedia/en/5/56/Newcastle_United_Logo.svg",
  "Brighton & Hove Albion": "https://upload.wikimedia.org/wikipedia/en/6/6d/Brighton_%26_Hove_Albion_logo.svg",
  "Aston Villa": "https://upload.wikimedia.org/wikipedia/en/f/f9/Aston_Villa_logo.svg",
  "West Ham United": "https://upload.wikimedia.org/wikipedia/en/c/c2/West_Ham_United_FC_logo.svg",
};
TS

# 2) Replace standings page with a version that includes logos
cat > src/app/standings/page.tsx <<'TSX'
'use client';

import { Suspense, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { simulate, type TableRow } from '@/lib/simulate';
import { teamLogos } from '@/lib/teamLogos';

type Pick = { outcome:'H'|'D'|'A'; homeGoals?:number|null; awayGoals?:number|null };

function StandingsInner() {
  const params = useSearchParams();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const gw = Number(params.get('gw') || 11);

  const [baseTable, setBaseTable] = useState<TableRow[] | null>(null);
  useEffect(() => {
    if (!mounted) return;
    fetch('/api/fd-standings')
      .then(r => r.json())
      .then(j => setBaseTable(j.table || null))
      .catch(() => setBaseTable(null));
  }, [mounted]);

  const picks: Record<number, Pick> = useMemo(() => {
    if (!mounted) return {};
    const raw = localStorage.getItem(`picks_gw_${gw}`);
    return raw ? JSON.parse(raw) : {};
  }, [mounted, gw]);

  const [fixtures, setFixtures] = useState<{id:number;homeTeam:string;awayTeam:string}[]>([]);
  useEffect(() => {
    if (!mounted) return;
    fetch(`/api/fd-fixtures?gw=${gw}`)
      .then(r => r.json())
      .then(j => setFixtures(j.fixtures || []))
      .catch(() => setFixtures([]));
  }, [mounted, gw]);

  const simulated = useMemo(() => {
    if (!mounted || !baseTable) return baseTable ?? [];
    const fx = fixtures
      .filter(f => picks[f.id]?.outcome)
      .map(f => ({
        id: f.id,
        homeTeam: f.homeTeam,
        awayTeam: f.awayTeam,
        pickOutcome: picks[f.id].outcome,
        pickHomeGoals: picks[f.id].homeGoals ?? null,
        pickAwayGoals: picks[f.id].awayGoals ?? null,
      }));
    return simulate(baseTable, fx, { gdWinDelta: 1, gdLossDelta: -1 });
  }, [mounted, baseTable, picks, fixtures]);

  if (!mounted || !baseTable) {
    return <main className="max-w-3xl mx-auto p-6">Loading standings…</main>;
  }

  const top8 = simulated.slice(0, 8);

  return (
    <main className="max-w-3xl mx-auto p-6">
      <h1 className="text-2xl font-bold">What-If Standings (GW {gw})</h1>
      <p className="text-sm text-slate-600 mt-1">Live baseline (Football-Data.org); ±1 GD when scoreline is not provided.</p>

      <div className="mt-6 overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead>
            <tr className="text-left text-slate-600">
              <th className="py-2 pr-4">Pos</th>
              <th className="py-2 pr-4">Team</th>
              <th className="py-2 pr-4">Pld</th>
              <th className="py-2 pr-4">W</th>
              <th className="py-2 pr-4">D</th>
              <th className="py-2 pr-4">L</th>
              <th className="py-2 pr-4">GD</th>
              <th className="py-2 pr-4">Pts</th>
            </tr>
          </thead>
          <tbody>
            {top8.map((r: TableRow, i: number) => (
              <tr key={r.team} className="border-t">
                <td className="py-2 pr-4">{i + 1}</td>
                <td className="py-2 pr-4">
                  <div className="flex items-center gap-2">
                    <img
                      src={teamLogos[r.team] || "/vercel.svg"}
                      alt={r.team}
                      className="h-5 w-5 rounded-sm"
                    />
                    <span className="font-medium">{r.team}</span>
                  </div>
                </td>
                <td className="py-2 pr-4">{r.gamesPlayed}</td>
                <td className="py-2 pr-4">{r.wins}</td>
                <td className="py-2 pr-4">{r.draws}</td>
                <td className="py-2 pr-4">{r.losses}</td>
                <td className="py-2 pr-4">{r.goalDifference}</td>
                <td className="py-2 pr-4">{r.points}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="mt-6">
        <a href={`/predict/${gw}`} className="inline-block px-4 py-2 rounded-xl bg-slate-900 text-white">
          ← Edit Predictions
        </a>
      </div>
    </main>
  );
}

export default function Page() {
  return (
    <Suspense fallback={<main className="max-w-3xl mx-auto p-6">Loading…</main>}>
      <StandingsInner />
    </Suspense>
  );
}
TSX

git add -A
git commit -m "feat(ui): show team logos in standings"
git push
echo "✅ Logos patch pushed. Vercel will redeploy."
