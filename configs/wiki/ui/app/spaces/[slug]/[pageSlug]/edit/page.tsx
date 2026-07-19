"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { ChevronRight, Save, ArrowLeft, Trash2 } from "lucide-react";
import {
  fetchJson,
  putJson,
  deleteJson,
  type Page,
  type Space,
  type Category,
} from "@/lib/api";
import MarkdownEditor from "@/app/components/MarkdownEditor";
import { marked } from "marked";

export default function EditPage() {
  const params = useParams();
  const router = useRouter();
  const slug = params.slug as string;
  const pageSlug = params.pageSlug as string;

  const [page, setPage] = useState<Page | null>(null);
  const [space, setSpace] = useState<(Space & { categories: Category[] }) | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [title, setTitle] = useState("");
  const [markdown, setMarkdown] = useState("");
  const [categoryId, setCategoryId] = useState<number | null>(null);
  const [isPublished, setIsPublished] = useState(true);
  const [revisionMessage, setRevisionMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    fetchJson<Page>(`/pages/${pageSlug}`)
      .then((p) => {
        setPage(p);
        setTitle(p.title);
        // The page stores contentHtml; for editing we use that as markdown source
        setMarkdown(p.contentHtml || "");
        setCategoryId(p.categoryId ?? null);
        setIsPublished(p.isPublished);
        return fetchJson<Space & { categories: Category[] }>(`/spaces/${p.spaceSlug || slug}`);
      })
      .then(setSpace)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [pageSlug, slug]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      setError("Title is required");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const html = markdown ? (await marked.parse(markdown)) as string : null;
      await putJson(`/pages/${pageSlug}`, {
        title: title.trim(),
        contentHtml: html,
        categoryId: categoryId,
        isPublished,
        message: revisionMessage.trim() || null,
      });
      router.push(`/spaces/${slug}/${pageSlug}`);
    } catch (err) {
      console.error(err);
      setError("Failed to save changes");
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm("Are you sure you want to delete this page? This cannot be undone.")) return;
    setDeleting(true);
    try {
      await deleteJson(`/pages/${pageSlug}`);
      router.push(`/spaces/${slug}`);
    } catch (err) {
      console.error(err);
      setError("Failed to delete page");
      setDeleting(false);
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
          {space?.name || slug}
        </Link>
        <ChevronRight className="h-3 w-3" />
        <Link
          href={`/spaces/${slug}/${pageSlug}`}
          className="hover:text-white transition-colors"
        >
          {page.title}
        </Link>
        <ChevronRight className="h-3 w-3" />
        <span className="text-white">Edit</span>
      </div>

      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Edit Page</h1>
        <Link
          href={`/spaces/${slug}/${pageSlug}`}
          className="flex items-center gap-1 text-sm text-zinc-400 hover:text-white transition-colors"
        >
          <ArrowLeft className="h-4 w-4" /> Back to {page.title}
        </Link>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit}>
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-6">
          {error && (
            <div className="mb-4 rounded-lg border border-red-800 bg-red-900/30 px-4 py-3 text-sm text-red-400">
              {error}
            </div>
          )}

          <div className="mb-5">
            <label htmlFor="title" className="mb-1.5 block text-sm font-medium text-zinc-300">
              Title
            </label>
            <input
              id="title"
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Page title"
              className="w-full rounded-lg border border-zinc-700 bg-zinc-800 px-4 py-2.5 text-sm outline-none focus:border-indigo-500 transition-colors"
              autoFocus
            />
          </div>

          {space?.categories && space.categories.length > 0 && (
            <div className="mb-5">
              <label htmlFor="category" className="mb-1.5 block text-sm font-medium text-zinc-300">
                Category
              </label>
              <select
                id="category"
                value={categoryId ?? ""}
                onChange={(e) => setCategoryId(e.target.value ? Number(e.target.value) : null)}
                className="w-full rounded-lg border border-zinc-700 bg-zinc-800 px-4 py-2.5 text-sm outline-none focus:border-indigo-500 transition-colors"
              >
                <option value="">Uncategorized</option>
                {space.categories.map((cat) => (
                  <option key={cat.id} value={cat.id}>
                    {cat.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="mb-5">
            <label className="mb-1.5 flex items-center gap-2 text-sm font-medium text-zinc-300">
              <input
                type="checkbox"
                checked={isPublished}
                onChange={(e) => setIsPublished(e.target.checked)}
                className="h-4 w-4 rounded border-zinc-600 bg-zinc-800 text-indigo-500 focus:ring-indigo-500"
              />
              Published
            </label>
          </div>

          <div className="mb-5">
            <label className="mb-1.5 block text-sm font-medium text-zinc-300">
              Content
            </label>
            <MarkdownEditor
              value={markdown}
              onChange={setMarkdown}
              height={400}
            />
          </div>

          <div className="mb-6">
            <label htmlFor="message" className="mb-1.5 block text-sm font-medium text-zinc-300">
              Revision Message <span className="text-zinc-500">(optional)</span>
            </label>
            <input
              id="message"
              type="text"
              value={revisionMessage}
              onChange={(e) => setRevisionMessage(e.target.value)}
              placeholder="What changed in this revision?"
              className="w-full rounded-lg border border-zinc-700 bg-zinc-800 px-4 py-2.5 text-sm outline-none focus:border-indigo-500 transition-colors"
            />
          </div>

          <div className="flex items-center gap-3">
            <button
              type="submit"
              disabled={saving}
              className="flex items-center gap-1.5 rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-medium hover:bg-indigo-500 disabled:opacity-50 transition-colors"
            >
              <Save className="h-4 w-4" />
              {saving ? "Saving…" : "Save Changes"}
            </button>
            <Link
              href={`/spaces/${slug}/${pageSlug}`}
              className="rounded-lg border border-zinc-700 px-5 py-2.5 text-sm hover:bg-zinc-800 transition-colors"
            >
              Cancel
            </Link>
            <div className="flex-1" />
            <button
              type="button"
              onClick={handleDelete}
              disabled={deleting}
              className="flex items-center gap-1.5 rounded-lg border border-red-800 px-4 py-2.5 text-sm text-red-400 hover:bg-red-900/30 disabled:opacity-50 transition-colors"
            >
              <Trash2 className="h-4 w-4" />
              {deleting ? "Deleting…" : "Delete"}
            </button>
          </div>
        </div>
      </form>
    </div>
  );
}
