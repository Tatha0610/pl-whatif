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
