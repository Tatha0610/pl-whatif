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
