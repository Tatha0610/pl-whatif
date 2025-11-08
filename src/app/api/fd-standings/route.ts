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
