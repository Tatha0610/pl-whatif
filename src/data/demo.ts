import type { TableRow } from '@/lib/simulate';

export const demoTable: TableRow[] = [
  { team:'Arsenal', gamesPlayed:10, wins:8, draws:1, losses:1, goalsFor:18, goalsAgainst:3,  goalDifference:15, points:25 },
  { team:'Manchester City', gamesPlayed:10, wins:6, draws:1, losses:3, goalsFor:20, goalsAgainst:8,  goalDifference:12, points:19 },
  { team:'Liverpool', gamesPlayed:10, wins:6, draws:0, losses:4, goalsFor:18, goalsAgainst:14, goalDifference:4,  points:18 },
  { team:'Manchester United', gamesPlayed:10, wins:5, draws:2, losses:3, goalsFor:17, goalsAgainst:16, goalDifference:1,  points:17 },
  { team:'Sunderland', gamesPlayed:10, wins:5, draws:3, losses:2, goalsFor:12, goalsAgainst:8,  goalDifference:4,  points:18 },
  { team:'AFC Bournemouth', gamesPlayed:10, wins:5, draws:3, losses:2, goalsFor:17, goalsAgainst:14, goalDifference:3,  points:18 },
  { team:'Aston Villa', gamesPlayed:10, wins:5, draws:3, losses:2, goalsFor:9,  goalsAgainst:10, goalDifference:-1, points:18 },
  { team:'Tottenham Hotspur', gamesPlayed:10, wins:5, draws:2, losses:3, goalsFor:17, goalsAgainst:8,  goalDifference:9,  points:17 },
];

export type DemoFixture = { id:number; homeTeam:string; awayTeam:string };

export const demoFixtures: DemoFixture[] = [
  { id:1, homeTeam:'Tottenham Hotspur', awayTeam:'Manchester United' },
  { id:2, homeTeam:'Everton', awayTeam:'Fulham' },
  { id:3, homeTeam:'West Ham United', awayTeam:'Burnley' },
  { id:4, homeTeam:'Sunderland', awayTeam:'Arsenal' },
  { id:5, homeTeam:'Chelsea', awayTeam:'Wolves' },
  { id:6, homeTeam:'Liverpool', awayTeam:'Brighton' },
  { id:7, homeTeam:'Brentford', awayTeam:'Newcastle' },
  { id:8, homeTeam:'Manchester City', awayTeam:'Crystal Palace' },
  { id:9, homeTeam:'Aston Villa', awayTeam:'AFC Bournemouth' },
  { id:10, homeTeam:'Nottingham Forest', awayTeam:'Leicester City' },
];
