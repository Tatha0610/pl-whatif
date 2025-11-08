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
