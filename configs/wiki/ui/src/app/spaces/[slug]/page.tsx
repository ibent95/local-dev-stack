"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { Plus, FileText, ChevronRight, Search } from "lucide-react";
import { fetchJson, type Space, type Page } from "@/lib/api";

export default function SpacePage() {
  const params = useParams();
  const slug = params.slug as string;
  const [space, setSpace] = useState<Space | null>(null);
  const [pages, setPages] = useState<Page[]>([]);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    fetchJson<Space>(`/spaces/${slug}`).then(setSpace);
    fetchJson<Page[]>(`/pages?space=${slug}`).then(setPages);
  }, [slug]);

  const filteredPages = pages.filter((p) =>
    p.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (!space) {
    return <div className="p-8 text-center text-zinc-500">Loading…</div>;
  }

  return (
    <div className="mx-auto max-w-6xl px-6 py-8">
      {/* Breadcrumb */}
      <div className="mb-6 flex items-center gap-2 text-sm text-zinc-500">
        <Link href="/" className="hover:text-white">Wiki</Link>
        <ChevronRight className="h-3 w-3" />
        <span className="text-white">{space.name}</span>
      </div>

      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-3xl">{space.icon || "📚"}</span>
          <div>
            <h1 className="text-2xl font-bold">{space.name}</h1>
            {space.description && <p className="text-sm text-zinc-400">{space.description}</p>}
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
              className="rounded-lg border border-zinc-700 bg-zinc-800 py-2 pl-10 pr-4 text-sm outline-none focus:border-indigo-500"
            />
          </div>
          <Link
            href={`/spaces/${slug}/new`}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium hover:bg-indigo-500"
          >
            <Plus className="mr-1 inline h-4 w-4" /> New Page
          </Link>
        </div>
      </div>

      {/* Categories */}
      {space.categories && space.categories.length > 0 && (
        <div className="mb-8">
          {space.categories.map((cat) => (
            <div key={cat.id} className="mb-6">
              <h2 className="mb-3 text-sm font-medium text-zinc-400">{cat.name}</h2>
              <div className="grid grid-cols-1 gap-2 md:grid-cols-2 lg:grid-cols-3">
                {filteredPages
                  .filter((p) => p.categoryId === cat.id)
                  .map((page) => (
                    <PageCard key={page.id} page={page} spaceSlug={slug} />
                  ))}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Uncategorized Pages */}
      <div className="grid grid-cols-1 gap-2 md:grid-cols-2 lg:grid-cols-3">
        {filteredPages.map((page) => (
          <PageCard key={page.id} page={page} spaceSlug={slug} />
        ))}
      </div>

      {filteredPages.length === 0 && (
        <div className="rounded-xl border border-dashed border-zinc-700 py-16 text-center">
          <FileText className="mx-auto mb-4 h-12 w-12 text-zinc-600" />
          <p className="text-zinc-500">
            {searchQuery ? "No pages match your search." : "No pages yet. Create your first page."}
          </p>
        </div>
      )}
    </div>
  );
}

function PageCard({ page, spaceSlug }: { page: Page; spaceSlug: string }) {
  return (
    <Link
      href={`/spaces/${spaceSlug}/${page.slug}`}
      className="group flex items-start gap-3 rounded-xl border border-zinc-800 bg-zinc-900 p-4 transition-all hover:-translate-y-0.5 hover:border-indigo-500/50"
    >
      <FileText className="mt-0.5 h-5 w-5 shrink-0 text-zinc-500 group-hover:text-indigo-400" />
      <div>
        <h3 className="font-medium group-hover:text-indigo-400">{page.title}</h3>
        <div className="mt-1 flex items-center gap-3 text-xs text-zinc-500">
          <span>v{page.version}</span>
          <span>{page.viewCount} views</span>
          <span>{new Date(page.updated_at).toLocaleDateString()}</span>
        </div>
      </div>
    </Link>
  );
}
