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
