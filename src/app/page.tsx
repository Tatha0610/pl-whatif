export default function Home() {
  return (
    <main className="max-w-3xl mx-auto p-10">
      <h1 className="text-3xl font-bold">PL What-If</h1>
      <p className="text-slate-600 mt-2">
        Predict fixtures and see how the table would look if your picks come true.
      </p>
      <div className="mt-6 flex gap-3">
        <a href="/predict/1" className="px-4 py-2 rounded-xl bg-emerald-600 text-white">Make Predictions</a>
        <a href="/standings?gw=1" className="px-4 py-2 rounded-xl bg-slate-900 text-white">See Standings</a>
      </div>
    </main>
  );
}
