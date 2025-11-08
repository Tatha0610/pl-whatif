'use client';

import { Suspense, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { simulate, type TableRow } from '@/lib/simulate';

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
                <td className="py-2 pr-4 font-medium">{r.team}</td>
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
