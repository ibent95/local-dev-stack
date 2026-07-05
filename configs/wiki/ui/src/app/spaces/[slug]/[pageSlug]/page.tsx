"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { ChevronRight, Clock, Eye, MessageSquare, History } from "lucide-react";
import { fetchJson, type Page, type Comment, type PageRevision } from "@/lib/api";

export default function WikiPageView() {
  const params = useParams();
  const slug = params.slug as string;
  const pageSlug = params.pageSlug as string;
  const [page, setPage] = useState<Page | null>(null);
  const [revisions, setRevisions] = useState<PageRevision[]>([]);
  const [showHistory, setShowHistory] = useState(false);

  useEffect(() => {
    fetchJson<Page>(`/pages/${pageSlug}`).then(setPage);
    fetchJson<PageRevision[]>(`/pages/${pageSlug}/revisions`).then(setRevisions);
  }, [pageSlug]);

  if (!page) {
    return <div className="p-8 text-center text-zinc-500">Loading…</div>;
  }

  return (
    <div className="mx-auto max-w-4xl px-6 py-8">
      {/* Breadcrumb */}
      <div className="mb-6 flex items-center gap-2 text-sm text-zinc-500">
        <Link href="/" className="hover:text-white">Wiki</Link>
        <ChevronRight className="h-3 w-3" />
        <Link href={`/spaces/${slug}`} className="hover:text-white">{page.spaceName || slug}</Link>
        <ChevronRight className="h-3 w-3" />
        <span className="text-white">{page.title}</span>
      </div>

      {/* Header */}
      <div className="mb-8 flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-bold">{page.title}</h1>
          <div className="mt-2 flex items-center gap-4 text-sm text-zinc-500">
            <span className="flex items-center gap-1"><Clock className="h-3 w-3" /> Updated {new Date(page.updated_at).toLocaleDateString()}</span>
            <span className="flex items-center gap-1"><Eye className="h-3 w-3" /> {page.viewCount} views</span>
            <span className="flex items-center gap-1"><History className="h-3 w-3" /> v{page.version}</span>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setShowHistory(!showHistory)}
            className="rounded-lg border border-zinc-700 px-3 py-1.5 text-sm hover:bg-zinc-800"
          >
            <History className="mr-1 inline h-3 w-3" /> History
          </button>
          <Link
            href={`/spaces/${slug}/${pageSlug}/edit`}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm hover:bg-indigo-500"
          >
            Edit
          </Link>
        </div>
      </div>

      {/* Revision History */}
      {showHistory && (
        <div className="mb-8 rounded-xl border border-zinc-800 bg-zinc-900 p-5">
          <h3 className="mb-3 text-sm font-medium text-zinc-400">Version History</h3>
          <div className="space-y-2">
            {revisions.map((rev) => (
              <div key={rev.id} className="flex items-center justify-between text-sm">
                <span className="text-zinc-300">v{rev.version} {rev.message ? `— ${rev.message}` : ""}</span>
                <span className="text-zinc-500">{new Date(rev.created_at).toLocaleString()}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Page Content */}
      <div className="prose prose-invert prose-zinc max-w-none">
        {page.contentHtml ? (
          <div dangerouslySetInnerHTML={{ __html: page.contentHtml }} />
        ) : (
          <p className="text-zinc-500 italic">No content yet.</p>
        )}
      </div>

      {/* Comments */}
      {page.comments && page.comments.length > 0 && (
        <div className="mt-12 border-t border-zinc-800 pt-8">
          <h3 className="mb-4 flex items-center gap-2 text-sm font-medium text-zinc-400">
            <MessageSquare className="h-4 w-4" /> Comments ({page.comments.length})
          </h3>
          <div className="space-y-4">
            {page.comments.map((c) => (
              <div key={c.id} className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
                <div className="mb-2 flex items-center justify-between text-xs text-zinc-500">
                  <span className="font-medium text-zinc-300">{c.author}</span>
                  <span>{new Date(c.created_at).toLocaleString()}</span>
                </div>
                <p className="text-sm text-zinc-300">{c.content}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
