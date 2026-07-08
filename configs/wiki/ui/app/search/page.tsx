"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { Search, FileText, ChevronRight } from "lucide-react";
import { fetchJson, type SearchResult } from "@/lib/api";

function SearchResults() {
  const searchParams = useSearchParams();
  const query = searchParams.get("q") || "";
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!query.trim()) return;
    setLoading(true);
    fetchJson<SearchResult[]>(`/search?q=${encodeURIComponent(query)}`)
      .then(setResults)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [query]);

  return (
    <div className="mx-auto max-w-4xl px-6 py-8">
      <div className="mb-8">
        <h1 className="flex items-center gap-2 text-2xl font-bold">
          <Search className="h-6 w-6 text-indigo-500" />
          Search Results
        </h1>
        {query && (
          <p className="mt-1 text-sm text-zinc-400">
            {loading
              ? "Searching…"
              : `${results.length} result${results.length !== 1 ? "s" : ""} for "${query}"`}
          </p>
        )}
      </div>

      {results.length > 0 && (
        <div className="space-y-3">
          {results.map((result) => (
            <Link
              key={result.id}
              href={`/spaces/${result.spaceSlug}/${result.slug}`}
              className="block rounded-xl border border-zinc-800 bg-zinc-900 p-5 transition-all hover:-translate-y-0.5 hover:border-indigo-500/50"
            >
              <div className="mb-2 flex items-center gap-2">
                <FileText className="h-4 w-4 text-indigo-400" />
                <h3 className="font-semibold text-zinc-100">{result.title}</h3>
              </div>
              <div className="mb-2 flex items-center gap-2 text-xs text-zinc-500">
                <span>{result.spaceName}</span>
                {result.categoryName && (
                  <>
                    <ChevronRight className="h-3 w-3" />
                    <span>{result.categoryName}</span>
                  </>
                )}
              </div>
              {result.contentHtml && (
                <p
                  className="line-clamp-2 text-sm text-zinc-400"
                  dangerouslySetInnerHTML={{
                    __html: result.contentHtml.replace(/<[^>]+>/g, " "),
                  }}
                />
              )}
            </Link>
          ))}
        </div>
      )}

      {!loading && query && results.length === 0 && (
        <div className="rounded-xl border border-dashed border-zinc-700 py-16 text-center">
          <Search className="mx-auto mb-4 h-12 w-12 text-zinc-600" />
          <p className="text-zinc-500">No results found for &ldquo;{query}&rdquo;</p>
        </div>
      )}

      {!query && (
        <div className="rounded-xl border border-dashed border-zinc-700 py-16 text-center">
          <p className="text-zinc-500">Enter a search query to find pages.</p>
        </div>
      )}
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-zinc-500">Loading…</div>}>
      <SearchResults />
    </Suspense>
  );
}
