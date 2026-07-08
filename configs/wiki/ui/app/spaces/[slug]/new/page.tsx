"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { ChevronRight, Save, ArrowLeft } from "lucide-react";
import { fetchJson, postJson, type Space, type Category } from "@/lib/api";

export default function NewPage() {
  const params = useParams();
  const router = useRouter();
  const slug = params.slug as string;

  const [space, setSpace] = useState<(Space & { categories: Category[] }) | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const [title, setTitle] = useState("");
  const [contentHtml, setContentHtml] = useState("");
  const [categoryId, setCategoryId] = useState<number | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    fetchJson<Space & { categories: Category[] }>(`/spaces/${slug}`)
      .then(setSpace)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [slug]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      setError("Title is required");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const page = await postJson<{ id: number; slug: string }>(`/pages`, {
        spaceId: space!.id,
        title: title.trim(),
        contentHtml: contentHtml || null,
        categoryId: categoryId || undefined,
      });
      router.push(`/spaces/${slug}/${page.slug}`);
    } catch (err) {
      console.error(err);
      setError("Failed to create page");
      setSaving(false);
    }
  };

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
          {space.name}
        </Link>
        <ChevronRight className="h-3 w-3" />
        <span className="text-white">New Page</span>
      </div>

      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Create New Page</h1>
        <Link
          href={`/spaces/${slug}`}
          className="flex items-center gap-1 text-sm text-zinc-400 hover:text-white transition-colors"
        >
          <ArrowLeft className="h-4 w-4" /> Back to {space.name}
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

          {space.categories && space.categories.length > 0 && (
            <div className="mb-5">
              <label htmlFor="category" className="mb-1.5 block text-sm font-medium text-zinc-300">
                Category (optional)
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

          <div className="mb-6">
            <label htmlFor="content" className="mb-1.5 block text-sm font-medium text-zinc-300">
              Content (HTML)
            </label>
            <textarea
              id="content"
              value={contentHtml}
              onChange={(e) => setContentHtml(e.target.value)}
              placeholder="Write your page content here…"
              rows={16}
              className="w-full rounded-lg border border-zinc-700 bg-zinc-800 px-4 py-3 text-sm font-mono outline-none focus:border-indigo-500 resize-y transition-colors"
            />
          </div>

          <div className="flex items-center gap-3">
            <button
              type="submit"
              disabled={saving}
              className="flex items-center gap-1.5 rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-medium hover:bg-indigo-500 disabled:opacity-50 transition-colors"
            >
              <Save className="h-4 w-4" />
              {saving ? "Creating…" : "Create Page"}
            </button>
            <Link
              href={`/spaces/${slug}`}
              className="rounded-lg border border-zinc-700 px-5 py-2.5 text-sm hover:bg-zinc-800 transition-colors"
            >
              Cancel
            </Link>
          </div>
        </div>
      </form>
    </div>
  );
}
