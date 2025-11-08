#!/usr/bin/env bash
set -euo pipefail

echo "▶ Switching to Football-Data.org…"

mkdir -p src/lib src/app/api/fd-standings src/app/api/fd-fixtures

# ---- src/lib/fd.ts ----
cat > src/lib/fd.ts <<'TS'
export type TableRow = {
  team: string; gamesPlayed: number; wins: number; draws: number; losses: number;
  goalsFor: number; goalsAgainst: number; goalDifference: number; points: number;
};

const API = 'https://api.football-data.org/v4';

async function fdFetch(path: string) {
  const key = process.env.FOOTBALL_DATA_API_KEY || '';
  const r = await fetch(`${API}${path}`, {
    headers: { 'X-Auth-Token': key, 'accept': 'application/json' },
    cache: 'no-store',
    // Revalidate on the server in prod if needed:
    // next: { revalidate: 300 },
  });
  if (!r.ok) throw new Error(`${path} -> ${r.status}`);
  return r.json();
}

export async function getFDStandings(): Promise<TableRow[]> {
  const j = await fdFetch('/competitions/PL/standings');
  const table = j?.standings?.find((s: any) => s.type === 'TOTAL')?.table ?? [];
  return table.map((t: any) => ({
    team: t.team?.name ?? 'Unknown',
    gamesPlayed: t.playedGames ?? 0,
    wins: t.won ?? 0,
    draws: t.draw ?? 0,
    losses: t.lost ?? 0,
    goalsFor: t.goalsFor ?? 0,
    goalsAgainst: t.goalsAgainst ?? 0,
    goalDifference: t.goalDifference ?? ((t.goalsFor ?? 0) - (t.goalsAgainst ?? 0)),
    points: t.points ?? 0,
  }));
}

export type FxLite = { id:number; homeTeam:string; awayTeam:string };

export async function getFDFixturesByGW(gw: number): Promise<FxLite[]> {
  // FD doesn't filter by "round"; we filter by "matchday" on competition matches
  const j = await fdFetch('/competitions/PL/matches?status=SCHEDULED,FINISHED,IN_PLAY,PAUSED,POSTPONED');
  const matches = (j?.matches ?? []).filter((m: any) => m.matchday === gw);
  return matches.map((m: any) => ({
    id: m.id,
    homeTeam: m.homeTeam?.name,
    awayTeam: m.awayTeam?.name,
  })).filter((m: FxLite) => m.id && m.homeTeam && m.awayTeam);
}
TS

# ---- API routes using Football-Data.org ----
cat > src/app/api/fd-standings/route.ts <<'TS'
import { NextResponse } from 'next/server';
import { getFDStandings } from '@/lib/fd';
import { demoTable } from '@/data/demo';

export async function GET() {
  try {
    const table = await getFDStandings();
    return NextResponse.json({ table, source: 'fd' }, { status: 200 });
  } catch (e) {
    return NextResponse.json({ table: demoTable, source: 'demo', error: String(e) }, { status: 200 });
  }
}
TS

cat > src/app/api/fd-fixtures/route.ts <<'TS'
import { NextResponse } from 'next/server';
import { getFDFixturesByGW } from '@/lib/fd';
import { demoFixtures } from '@/data/demo';

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const gw = Number(searchParams.get('gw') || '11');
  try {
    const fixtures = await getFDFixturesByGW(gw);
    return NextResponse.json({ fixtures, source: 'fd' }, { status: 200 });
  } catch (e) {
    return NextResponse.json({ fixtures: demoFixtures, source: 'demo', error: String(e) }, { status: 200 });
  }
}
TS

# ---- Update Predict page to use fd endpoint ----
cat > src/app/predict/[gw]/page.tsx <<'TSX'
'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';

type Pick = { outcome:'H'|'D'|'A'; homeGoals?:number|null; awayGoals?:number|null };
type FxLite = { id:number; homeTeam:string; awayTeam:string };

export default function PredictPage() {
  const params = useParams<{ gw?: string }>();
  const gw = Number(params?.gw ?? 11);

  const [fixtures, setFixtures] = useState<FxLite[]>([]);
  const [picks, setPicks] = useState<Record<number, Pick>>({});

  useEffect(() => {
    fetch(`/api/fd-fixtures?gw=${gw}`)
      .then(r => r.json())
      .then(j => setFixtures(j.fixtures || []))
      .catch(() => setFixtures([]));
  }, [gw]);

  useEffect(()=> {
    const raw = localStorage.getItem(`picks_gw_${gw}`);
    if (raw) setPicks(JSON.parse(raw));
  }, [gw]);

  useEffect(()=> {
    localStorage.setItem(`picks_gw_${gw}`, JSON.stringify(picks));
  }, [gw, picks]);

  const setOutcome = (id:number, outcome:'H'|'D'|'A') =>
    setPicks(prev => ({ ...prev, [id]: { ...(prev[id]||{}), outcome } }));

  const setScore = (id:number, side:'H'|'A', val:string) =>
    setPicks(prev => {
      const num = val === '' ? null : Number(val);
      const p = prev[id] || { outcome:'H' as const };
      return { ...prev, [id]: { ...p, [side==='H'?'homeGoals':'awayGoals']: (Number.isFinite(num) ? num : null) } };
    });

  return (
    <main className="max-w-3xl mx-auto p-6">
      <h1 className="text-2xl font-bold">Gameweek {gw} — Predictions</h1>
      <p className="text-sm text-slate-600 mt-1">Pick W/D/L and optional exact scoreline.</p>

      <div className="mt-6 space-y-4">
        {fixtures.length === 0 && <div className="text-slate-500">Loading fixtures…</div>}
        {fixtures.map((fx) => {
          const p = picks[fx.id];
          return (
            <div key={fx.id} className="rounded-xl border p-4">
              <div className="font-medium">{fx.homeTeam} vs {fx.awayTeam}</div>
              <div className="mt-3 flex flex-wrap items-center gap-3">
                {(['H','D','A'] as const).map(o => (
                  <button
                    key={o}
                    onClick={()=>setOutcome(fx.id, o)}
                    className={`px-3 py-1 rounded-lg border ${p?.outcome===o ? 'bg-black text-white' : 'bg-white'}`}
                  >
                    {o==='H'?'Home':o==='A'?'Away':'Draw'}
                  </button>
                ))}
                <div className="ml-2 flex items-center gap-2">
                  <input
                    type="number" placeholder="H"
                    value={p?.homeGoals ?? ''}
                    onChange={e=>setScore(fx.id,'H',e.target.value)}
                    className="w-14 border rounded px-2 py-1"
                  />
                  <span>:</span>
                  <input
                    type="number" placeholder="A"
                    value={p?.awayGoals ?? ''}
                    onChange={e=>setScore(fx.id,'A',e.target.value)}
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

# ---- Update Standings page to use fd endpoint ----
cat > src/app/standings/page.tsx <<'TSX'
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
TSX

echo "▶ Commit & push…"
git add -A
git commit -m "feat: switch to Football-Data.org (standings + fixtures by GW); live baseline"
git push
echo "✅ Pushed. Add FOOTBALL_DATA_API_KEY on Vercel and redeploy."
