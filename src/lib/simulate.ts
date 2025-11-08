export type TableRow = {
  team: string; gamesPlayed: number; wins: number; draws: number; losses: number;
  goalsFor: number; goalsAgainst: number; goalDifference: number; points: number;
};

const sortRows = (rows: TableRow[]) =>
  [...rows].sort(
    (a, b) =>
      b.points - a.points ||
      b.goalDifference - a.goalDifference ||
      b.goalsFor - a.goalsFor
  );

export type Outcome = 'H' | 'D' | 'A';

export function simulate(
  base: TableRow[],
  fixtures: { id:number; homeTeam: string; awayTeam: string; pickOutcome: Outcome; pickHomeGoals?: number | null; pickAwayGoals?: number | null }[],
  opts: { gdWinDelta?: number; gdLossDelta?: number } = {}
) {
  const { gdWinDelta = 1, gdLossDelta = -1 } = opts;
  const table: TableRow[] = JSON.parse(JSON.stringify(base));
  const idx = new Map(table.map((r, i) => [r.team, i]));
  const plus = (team: string, field: keyof TableRow, v: number) => {
    const i = idx.get(team); if (i == null) return;
    (table[i] as any)[field] = (table[i] as any)[field] + v;
  };
  const setGP = (team: string) => {
    const i = idx.get(team); if (i == null) return;
    const r = table[i]; r.gamesPlayed = r.wins + r.draws + r.losses;
  };

  for (const f of fixtures) {
    if (f.pickOutcome === 'D') {
      plus(f.homeTeam, 'draws', 1); plus(f.awayTeam, 'draws', 1);
      plus(f.homeTeam, 'points', 1); plus(f.awayTeam, 'points', 1);
    } else {
      const win = f.pickOutcome === 'H' ? f.homeTeam : f.awayTeam;
      const lose = f.pickOutcome === 'H' ? f.awayTeam : f.homeTeam;
      plus(win,'wins',1); plus(win,'points',3); plus(win,'goalDifference',gdWinDelta);
      plus(lose,'losses',1); plus(lose,'goalDifference',gdLossDelta);
    }
    setGP(f.homeTeam); setGP(f.awayTeam);
  }
  return sortRows(table);
}
