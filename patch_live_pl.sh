#!/usr/bin/env bash
set -euo pipefail

echo "▶ Adding API routes and live fetchers…"

mkdir -p src/app/api/standings src/app/api/fixtures src/lib

# ---- src/lib/fetchers.ts ----
cat > src/lib/fetchers.ts <<'TS'
export type TableRow = {
  team: string; gamesPlayed: number; wins: number; draws: number; losses: number;
  goalsFor: number; goalsAgainst: number; goalDifference: number; points: number;
};

const BASE = process.env.APIFOOTBALL_BASE || 'https://v3.football.api-sports.io';
const KEY  = process.env.APIFOOTBALL_KEY  || '';

function headers() {
  return {
    'x-apisports-key': KEY,
    'accept': 'application/json'
  };
}

export async function fetchStandings(league: string, season: string): Promise<TableRow[]> {
  const url = `${BASE}/standings?league=${league}&season=${season}`;
  const r = await fetch(url, { headers: headers(), cache: 'no-store' });
  if (!r.ok) throw new Error(`standings ${r.status}`);
  const j = await r.json();

  const arr = j?.response?.[0]?.league?.standings?.[0] ?? [];
  return arr.map((row: any) => ({
    team: row.team?.name ?? 'Unknown',
    gamesPlayed: row.all?.played ?? 0,
    wins: row.all?.win ?? 0,
    draws: row.all?.draw ?? 0,
    losses: row.all?.lose ?? 0,
    goalsFor: row.all?.goals?.for ?? 0,
    goalsAgainst: row.all?.goals?.against ?? 0,
    goalDifference: row.goalsDiff ?? ((row.all?.goals?.for ?? 0) - (row.all?.goals?.against ?? 0)),
    points: row.points ?? 0,
  }));
}

export type FxLite = { id:number; homeTeam:string; awayTeam:string };

export async function fetchFixturesByRound(league: string, season: string, gw: number): Promise<FxLite[]> {
  const round = `Regular Season - ${gw}`;
  const url = `${BASE}/fixtures?league=${league}&season=${season}&round=${encodeURIComponent(round)}`;
  const r = await fetch(url, { headers: headers(), cache: 'no-store' });
  if (!r.ok) throw new Error(`fixtures ${r.status}`);
  const j = await r.json();
  return (j?.response ?? []).map((x: any) => ({
    id: x.fixture?.id,
    homeTeam: x.teams?.home?.name,
    awayTeam: x.teams?.away?.name,
  })).filter((f: FxLite) => f.id && f.homeTeam && f.awayTeam);
}
TS

# ---- API: /api/standings ----
cat > src/app/api/standings/route.ts <<'TS'
import { NextResponse } from 'next/server';
import { fetchStandings } from '@/lib/fetchers';
import { demoTable } from '@/data/demo';

export async function GET() {
  const league = process.env.APIFOOTBALL_LEAGUE_ID || '39';   // EPL
  const season = process.env.APIFOOTBALL_SEASON || '2024';    // current PL season in API-Football
  try {
    const table = await fetchStandings(league, season);
    return NextResponse.json({ table, source: 'live' }, { status: 200 });
  } catch (e) {
    return NextResponse.json({ table: demoTable, source: 'demo', error: String(e) }, { status: 200 });
  }
}
TS

# ---- API: /api/fixtures?gw=11 ----
cat > src/app/api/fixtures/route.ts <<'TS'
import { NextResponse } from 'next/server';
import { fetchFixturesByRound } from '@/lib/fetchers';
import { demoFixtures } from '@/data/demo';

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const gw = Number(searchParams.get('gw') || '11');
  const league = process.env.APIFOOTBALL_LEAGUE_ID || '39';
  const season = process.env.APIFOOTBALL_SEASON || '2024';
  try {
    const fixtures = await fetchFixturesByRound(league, season, gw);
    return NextResponse.json({ fixtures, source: 'live' }, { status: 200 });
  } catch (e) {
    return NextResponse.json({ fixtures: demoFixtures, source: 'demo', error: String(e) }, { status: 200 });
  }
}
TS

# ---- Update Predict page to use live fixtures ----
cat > src/app/predict/[gw]/page.tsx <<'TSX'
'use client';

import { useEffect, useMemo, useState } from 'react';
import { useParams } from 'next/navigation';

type Pick = { outcome:'H'|'D'|'A'; homeGoals?:number|null; awayGoals?:number|null };
type FxLite = { id:number; homeTeam:string; awayTeam:string };

export default function PredictPage() {
  const params = useParams<{ gw?: string }>();
  const gw = Number(params?.gw ?? 11);

  const [fixtures, setFixtures] = useState<FxLite[]>([]);
  const [picks, setPicks] = useState<Record<number, Pick>>({});

  useEffect(() => {
    fetch(`/api/fixtures?gw=${gw}`)
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

# ---- Update Standings page to fetch live baseline ----
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
    fetch('/api/standings')
      .then(r => r.json())
      .then(j => setBaseTable(j.table || null))
      .catch(() => setBaseTable(null));
  }, [mounted]);

  const picks: Record<number, Pick> = useMemo(() => {
    if (!mounted) return {};
    const raw = localStorage.getItem(`picks_gw_${gw}`);
    return raw ? JSON.parse(raw) : {};
  }, [mounted, gw]);

  // Note: simulation still uses fixtures the user chose on the Predict page.
  // Points and GD are applied per your simulator (±1 GD when score omitted).
  const [fixtures, setFixtures] = useState<{id:number;homeTeam:string;awayTeam:string}[]>([]);
  useEffect(() => {
    if (!mounted) return;
    fetch(`/api/fixtures?gw=${gw}`)
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
      <p className="text-sm text-slate-600 mt-1">Live baseline; ±1 GD when scoreline is not provided.</p>

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

echo "▶ Committing & pushing…"
git add -A
git commit -m "feat: live EPL data (league 39, GW 11) via API-Football; pages fetch standings & fixtures"
git push
echo "✅ Done. Vercel will auto-redeploy."
