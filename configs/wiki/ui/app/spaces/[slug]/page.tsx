"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { Plus, FileText, ChevronRight, Search } from "lucide-react";
import { fetchJson, type Space, type Page, type Category } from "@/lib/api";

export default function SpacePage() {
  const params = useParams();
  const slug = params.slug as string;
  const [space, setSpace] = useState<(Space & { categories: Category[] }) | null>(null);
  const [pages, setPages] = useState<Page[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetchJson<Space & { categories: Category[] }>(`/spaces/${slug}`),
      fetchJson<Page[]>(`/pages?space=${slug}`),
    ])
      .then(([s, p]) => {
        setSpace(s);
        setPages(p);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [slug]);

  const filteredPages = pages.filter((p) =>
    p.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Pages grouped by category
  const categorized = new Map<number | null, Page[]>();
  if (space?.categories) {
    for (const cat of space.categories) {
      categorized.set(cat.id, []);
    }
  }
  categorized.set(null, []); // Uncategorized
  for (const page of filteredPages) {
    const key = page.categoryId ?? null;
    const arr = categorized.get(key);
    if (arr) arr.push(page);
    else categorized.set(key, [page]);
  }

  if (loading) {
    return <div className="p-8 text-center text-zinc-500">Loading…</div>;
  }

  if (!space) {
    return (
      <div className="p-8 text-center text-zinc-500">
        Space not found.{" "}
        <Link href="/" className="text-indigo-400 hover:underline">
          Go home
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl px-6 py-8">
      {/* Breadcrumb */}
      <div className="mb-6 flex items-center gap-2 text-sm text-zinc-500">
        <Link href="/" className="hover:text-white transition-colors">
          Wiki
        </Link>
        <ChevronRight className="h-3 w-3" />
        <span className="text-white">{space.name}</span>
      </div>

      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-3xl">{space.icon || "📚"}</span>
          <div>
            <h1 className="text-2xl font-bold">{space.name}</h1>
            {space.description && (
              <p className="text-sm text-zinc-400">{space.description}</p>
            )}
          </div>
        </div>
        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-500" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Filter pages…"
              className="rounded-lg border border-zinc-700 bg-zinc-800 py-2 pl-10 pr-4 text-sm outline-none focus:border-indigo-500 transition-colors"
            />
          </div>
          <Link
            href={`/spaces/${slug}/new`}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium hover:bg-indigo-500 transition-colors"
          >
            <Plus className="mr-1 inline h-4 w-4" /> New Page
          </Link>
        </div>
      </div>

      {/* Categories + Pages */}
      {space.categories && space.categories.length > 0 && (
        <div className="mb-8">
          {space.categories.map((cat) => {
            const catPages = categorized.get(cat.id) || [];
            return (
              <div key={cat.id} className="mb-6">
                <h2 className="mb-3 text-sm font-medium text-zinc-400">
                  {cat.name}
                </h2>
                {catPages.length > 0 ? (
                  <div className="grid grid-cols-1 gap-2 md:grid-cols-2 lg:grid-cols-3">
                    {catPages.map((page) => (
                      <PageCard key={page.id} page={page} spaceSlug={slug} />
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-zinc-600">No pages yet</p>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Uncategorized Pages */}
      {(() => {
        const uncategorized = categorized.get(null) || [];
        if (uncategorized.length === 0 && filteredPages.length === 0) {
          return (
            <div className="rounded-xl border border-dashed border-zinc-700 py-16 text-center">
              <FileText className="mx-auto mb-4 h-12 w-12 text-zinc-600" />
              <p className="text-zinc-500">
                {searchQuery
                  ? "No pages match your search."
                  : "No pages yet. Create your first page."}
              </p>
            </div>
          );
        }
        if (uncategorized.length === 0) return null;
        return (
          <div>
            {space.categories && space.categories.length > 0 && (
              <h2 className="mb-3 text-sm font-medium text-zinc-400">
                Uncategorized
              </h2>
            )}
            <div className="grid grid-cols-1 gap-2 md:grid-cols-2 lg:grid-cols-3">
              {uncategorized.map((page) => (
                <PageCard key={page.id} page={page} spaceSlug={slug} />
              ))}
            </div>
          </div>
        );
      })()}
    </div>
  );
}

function PageCard({ page, spaceSlug }: { page: Page; spaceSlug: string }) {
  return (
    <Link
      href={`/spaces/${spaceSlug}/${page.slug}`}
      className="group flex items-start gap-3 rounded-xl border border-zinc-800 bg-zinc-900 p-4 transition-all hover:-translate-y-0.5 hover:border-indigo-500/50"
    >
      <FileText className="mt-0.5 h-5 w-5 shrink-0 text-zinc-500 group-hover:text-indigo-400 transition-colors" />
      <div>
        <h3 className="font-medium group-hover:text-indigo-400 transition-colors">
          {page.title}
        </h3>
        <div className="mt-1 flex items-center gap-3 text-xs text-zinc-500">
          <span>v{page.version}</span>
          <span>{page.viewCount} views</span>
          <span>{new Date(page.updatedAt).toLocaleDateString()}</span>
        </div>
      </div>
    </Link>
  );
}
