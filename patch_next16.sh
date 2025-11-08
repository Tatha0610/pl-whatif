#!/usr/bin/env bash
set -euo pipefail

echo "▶ Patching files for Next 16 (useParams + Suspense)..."

# sanity check
if [ ! -f package.json ]; then
  echo "❌ Run this from your project root (where package.json is)."
  exit 1
fi

mkdir -p src/app/predict/[gw] src/app/standings

# A) src/app/predict/[gw]/page.tsx  — useParams instead of params prop
cat > src/app/predict/[gw]/page.tsx <<'TSX'
'use client';

import { useMemo, useState, useEffect } from 'react';
import { useParams } from 'next/navigation';
import { demoFixtures } from '@/data/demo';

type Pick = { outcome: 'H' | 'D' | 'A'; homeGoals?: number | null; awayGoals?: number | null };

export default function PredictPage() {
  const params = useParams<{ gw?: string }>();
  const gw = Number(params?.gw ?? 1);
  const [picks, setPicks] = useState<Record<number, Pick>>({});

  useEffect(() => {
    const raw = localStorage.getItem(`picks_gw_${gw}`);
    if (raw) setPicks(JSON.parse(raw));
  }, [gw]);

  useEffect(() => {
    localStorage.setItem(`picks_gw_${gw}`, JSON.stringify(picks));
  }, [gw, picks]);

  const setOutcome = (id: number, outcome: 'H' | 'D' | 'A') =>
    setPicks(prev => ({ ...prev, [id]: { ...(prev[id] || {}), outcome } }));

  const setScore = (id: number, side: 'H' | 'A', val: string) =>
    setPicks(prev => {
      const num = val === '' ? null : Number(val);
      const p = prev[id] || { outcome: 'H' as const };
      return { ...prev, [id]: { ...p, [side === 'H' ? 'homeGoals' : 'awayGoals']: Number.isFinite(num) ? num : null } };
    });

  return (
    <main className="max-w-3xl mx-auto p-6">
      <h1 className="text-2xl font-bold">Gameweek {gw} — Predictions</h1>
      <p className="text-sm text-slate-600 mt-1">Pick W/D/L and optional exact scoreline.</p>

      <div className="mt-6 space-y-4">
        {demoFixtures.map(fx => {
          const p = picks[fx.id];
          return (
            <div key={fx.id} className="rounded-xl border p-4">
              <div className="font-medium">{fx.homeTeam} vs {fx.awayTeam}</div>
              <div className="mt-3 flex flex-wrap items-center gap-3">
                {(['H', 'D', 'A'] as const).map(o => (
                  <button
                    key={o}
                    onClick={() => setOutcome(fx.id, o)}
                    className={`px-3 py-1 rounded-lg border ${p?.outcome === o ? 'bg-black text-white' : 'bg-white'}`}
                  >
                    {o === 'H' ? 'Home' : o === 'A' ? 'Away' : 'Draw'}
                  </button>
                ))}
                <div className="ml-2 flex items-center gap-2">
                  <input
                    type="number" placeholder="H"
                    value={p?.homeGoals ?? ''}
                    onChange={e => setScore(fx.id, 'H', e.target.value)}
                    className="w-14 border rounded px-2 py-1"
                  />
                  <span>:</span>
                  <input
                    type="number" placeholder="A"
                    value={p?.awayGoals ?? ''}
                    onChange={e => setScore(fx.id, 'A', e.target.value)}
                    className="w-14 border rounded px-2 py-1"
                  />
                  <span className="text-xs text-slate-500">leave blank = use ±1 GD</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="mt-6">
        <a href={`/standings?gw=${gw}`} className="inline-block px-4 py-2 rounded-xl bg-emerald-600 text-white">
          See What-If Standings →
        </a>
      </div>
    </main>
  );
}
TSX

# B) src/app/standings/page.tsx — wrap useSearchParams in Suspense
cat > src/app/standings/page.tsx <<'TSX'
'use client';

import { Suspense, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { simulate, type TableRow } from '@/lib/simulate';
import { demoTable, demoFixtures } from '@/data/demo';

function StandingsInner() {
  const params = useSearchParams();

  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const gw = Number(params.get('gw') || 1);

  const [baseTable, setBaseTable] = useState<TableRow[] | null>(null);
  useEffect(() => {
    if (!mounted) return;
    setBaseTable(demoTable); // baseline for now
  }, [mounted]);

  type Pick = { outcome: 'H' | 'D' | 'A'; homeGoals?: number | null; awayGoals?: number | null };
  const picks: Record<number, Pick> = useMemo(() => {
    if (!mounted) return {};
    const raw = localStorage.getItem(`picks_gw_${gw}`);
    return raw ? JSON.parse(raw) : {};
  }, [mounted, gw]);

  const simulated = useMemo(() => {
    if (!mounted || !baseTable) return demoTable;
    const fx = demoFixtures
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
  }, [mounted, baseTable, picks]);

  const top8 = simulated.slice(0, 8);

  return (
    <main className="max-w-3xl mx-auto p-6">
      <h1 className="text-2xl font-bold">What-If Standings (GW {gw})</h1>
      <p className="text-sm text-slate-600 mt-1">Client-only render to avoid hydration issues.</p>

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
TSX

echo "✔ Files updated."

# Git commit & push
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "❌ Not a git repo. Run: git init && git add -A && git commit -m 'init'"
  exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)
echo "▶ Committing changes on branch: $branch"
git add -A
git commit -m "fix(next16): useParams on predict + Suspense around useSearchParams"

# push to origin (SSH)
if git remote -v | grep -q "git@github.com:"; then
  echo "▶ Pushing to origin/$branch via SSH…"
  git push -u origin "$branch"
else
  echo "⚠️  No SSH remote found. Add it, then push:"
  echo "    git remote set-url origin git@github.com:<USER>/pl-whatif.git"
  echo "    git push -u origin $branch"
fi

echo "✅ Done. Vercel will auto-redeploy."
