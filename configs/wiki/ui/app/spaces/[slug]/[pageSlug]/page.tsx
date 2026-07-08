"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import {
  ChevronRight,
  Clock,
  Eye,
  MessageSquare,
  History,
  ArrowLeft,
} from "lucide-react";
import {
  fetchJson,
  postJson,
  type Page,
  type Comment,
  type PageRevision,
} from "@/lib/api";

export default function WikiPageView() {
  const params = useParams();
  const slug = params.slug as string;
  const pageSlug = params.pageSlug as string;
  const [page, setPage] = useState<Page | null>(null);
  const [revisions, setRevisions] = useState<PageRevision[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [commentAuthor, setCommentAuthor] = useState("");
  const [commentText, setCommentText] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchJson<Page>(`/pages/${pageSlug}`)
      .then((p) => {
        setPage(p);
        return fetchJson<PageRevision[]>(`/pages/${pageSlug}/revisions`);
      })
      .then(setRevisions)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [pageSlug]);

  const addComment = async () => {
    if (!commentText.trim()) return;
    try {
      const comment = await postJson<Comment>(`/pages/${pageSlug}/comments`, {
        author: commentAuthor || "Anonymous",
        content: commentText,
      });
      setPage((prev) =>
        prev
          ? { ...prev, comments: [...(prev.comments || []), comment] }
          : prev
      );
      setCommentText("");
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) {
    return <div className="p-8 text-center text-zinc-500">Loading…</div>;
  }

  if (!page) {
    return (
      <div className="p-8 text-center text-zinc-500">
        Page not found.{" "}
        <Link href="/" className="text-indigo-400 hover:underline">
          Go home
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-4xl px-6 py-8">
      {/* Breadcrumb */}
      <div className="mb-6 flex items-center gap-2 text-sm text-zinc-500">
        <Link href="/" className="hover:text-white transition-colors">
          Wiki
        </Link>
        <ChevronRight className="h-3 w-3" />
        <Link
          href={`/spaces/${slug}`}
          className="hover:text-white transition-colors"
        >
          {page.spaceName || slug}
        </Link>
        <ChevronRight className="h-3 w-3" />
        <span className="text-white">{page.title}</span>
      </div>

      {/* Header */}
      <div className="mb-8 flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-bold">{page.title}</h1>
          <div className="mt-2 flex items-center gap-4 text-sm text-zinc-500">
            <span className="flex items-center gap-1">
              <Clock className="h-3 w-3" />
              Updated {new Date(page.updatedAt).toLocaleDateString()}
            </span>
            <span className="flex items-center gap-1">
              <Eye className="h-3 w-3" /> {page.viewCount} views
            </span>
            <span className="flex items-center gap-1">
              <History className="h-3 w-3" /> v{page.version}
            </span>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setShowHistory(!showHistory)}
            className="rounded-lg border border-zinc-700 px-3 py-1.5 text-sm hover:bg-zinc-800 transition-colors"
          >
            <History className="mr-1 inline h-3 w-3" /> History
          </button>
          <Link
            href={`/spaces/${slug}/${pageSlug}/edit`}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm hover:bg-indigo-500 transition-colors"
          >
            Edit
          </Link>
        </div>
      </div>

      {/* Revision History */}
      {showHistory && (
        <div className="mb-8 rounded-xl border border-zinc-800 bg-zinc-900 p-5">
          <h3 className="mb-3 text-sm font-medium text-zinc-400">
            Version History
          </h3>
          <div className="space-y-2">
            {revisions.map((rev) => (
              <div
                key={rev.id}
                className="flex items-center justify-between text-sm"
              >
                <span className="text-zinc-300">
                  v{rev.version}
                  {rev.message ? ` — ${rev.message}` : ""}
                </span>
                <span className="text-zinc-500">
                  {new Date(rev.createdAt).toLocaleString()}
                </span>
              </div>
            ))}
            {revisions.length === 0 && (
              <p className="text-xs text-zinc-600">No revision history</p>
            )}
          </div>
        </div>
      )}

      {/* Page Content */}
      <div className="prose prose-invert max-w-none">
        {page.contentHtml ? (
          <div dangerouslySetInnerHTML={{ __html: page.contentHtml }} />
        ) : (
          <p className="text-zinc-500 italic">No content yet.</p>
        )}
      </div>

      {/* Tags */}
      {page.tags && page.tags.length > 0 && (
        <div className="mt-8 flex flex-wrap gap-2">
          {page.tags.map((tag) => (
            <span
              key={tag.id}
              className="rounded-full px-3 py-1 text-xs font-medium"
              style={{
                backgroundColor: `${tag.color}20`,
                color: tag.color,
              }}
            >
              {tag.name}
            </span>
          ))}
        </div>
      )}

      {/* Comments */}
      <div className="mt-12 border-t border-zinc-800 pt-8">
        <h3 className="mb-4 flex items-center gap-2 text-sm font-medium text-zinc-400">
          <MessageSquare className="h-4 w-4" /> Comments (
          {page.comments?.length || 0})
        </h3>

        {page.comments && page.comments.length > 0 && (
          <div className="mb-6 space-y-4">
            {page.comments.map((c) => (
              <div
                key={c.id}
                className="rounded-lg border border-zinc-800 bg-zinc-900 p-4"
              >
                <div className="mb-2 flex items-center justify-between text-xs text-zinc-500">
                  <span className="font-medium text-zinc-300">
                    {c.author}
                  </span>
                  <span>{new Date(c.createdAt).toLocaleString()}</span>
                </div>
                <p className="text-sm text-zinc-300">{c.content}</p>
              </div>
            ))}
          </div>
        )}

        {/* Add Comment */}
        <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
          <input
            type="text"
            value={commentAuthor}
            onChange={(e) => setCommentAuthor(e.target.value)}
            placeholder="Your name (optional)"
            className="mb-3 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm outline-none focus:border-indigo-500 transition-colors"
          />
          <textarea
            value={commentText}
            onChange={(e) => setCommentText(e.target.value)}
            placeholder="Write a comment…"
            rows={3}
            className="mb-3 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm outline-none focus:border-indigo-500 resize-none transition-colors"
          />
          <button
            onClick={addComment}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium hover:bg-indigo-500 transition-colors"
          >
            Post Comment
          </button>
        </div>
      </div>
    </div>
  );
}
