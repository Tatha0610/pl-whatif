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
