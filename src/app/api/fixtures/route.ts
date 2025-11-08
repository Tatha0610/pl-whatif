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
