"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Plus, BookOpen, Search } from "lucide-react";
import { fetchJson, postJson, type Space } from "@/lib/api";

export default function WikiHome() {
  const [spaces, setSpaces] = useState<Space[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [showNewForm, setShowNewForm] = useState(false);
  const [newName, setNewName] = useState("");
  const [newDesc, setNewDesc] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchJson<Space[]>("/spaces")
      .then(setSpaces)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const createSpace = async () => {
    if (!newName.trim()) return;
    try {
      const space = await postJson<Space>("/spaces", {
        name: newName,
        description: newDesc || undefined,
      });
      setSpaces([...spaces, space]);
      setNewName("");
      setNewDesc("");
      setShowNewForm(false);
    } catch (err) {
      console.error(err);
    }
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      window.location.href = `/search?q=${encodeURIComponent(searchQuery)}`;
    }
  };

  return (
    <div className="mx-auto max-w-6xl px-6 py-8">
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="flex items-center gap-3 text-2xl font-bold">
            <BookOpen className="h-7 w-7 text-indigo-500" />
            LDS Wiki
          </h1>
          <p className="mt-1 text-sm text-zinc-400">
            Company-wide knowledge base and documentation
          </p>
        </div>
        <div className="flex items-center gap-3">
          <form onSubmit={handleSearch} className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-500" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search pages…"
              className="rounded-lg border border-zinc-700 bg-zinc-800 py-2 pl-10 pr-4 text-sm outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            />
          </form>
          <button
            onClick={() => setShowNewForm(true)}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium hover:bg-indigo-500 transition-colors"
          >
            <Plus className="mr-1 inline h-4 w-4" /> New Space
          </button>
        </div>
      </div>

      {/* New Space Form */}
      {showNewForm && (
        <div className="mb-6 rounded-xl border border-zinc-800 bg-zinc-900 p-5">
          <input
            type="text"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            placeholder="Space name"
            className="mb-3 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-4 py-2 text-sm outline-none focus:border-indigo-500"
            autoFocus
          />
          <input
            type="text"
            value={newDesc}
            onChange={(e) => setNewDesc(e.target.value)}
            placeholder="Description (optional)"
            className="mb-3 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-4 py-2 text-sm outline-none focus:border-indigo-500"
          />
          <div className="flex gap-2">
            <button
              onClick={createSpace}
              className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium hover:bg-indigo-500 transition-colors"
            >
              Create
            </button>
            <button
              onClick={() => {
                setShowNewForm(false);
                setNewName("");
                setNewDesc("");
              }}
              className="rounded-lg border border-zinc-700 px-4 py-2 text-sm hover:bg-zinc-800 transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="py-16 text-center text-zinc-500">Loading spaces…</div>
      )}

      {/* Spaces Grid */}
      {!loading && spaces.length > 0 && (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {spaces.map((space) => (
            <Link
              key={space.id}
              href={`/spaces/${space.slug}`}
              className="group rounded-xl border border-zinc-800 bg-zinc-900 p-5 transition-all hover:-translate-y-0.5 hover:border-indigo-500/50 hover:shadow-lg hover:shadow-indigo-500/5"
            >
              <div className="mb-3 flex items-center gap-3">
                <span className="text-2xl">{space.icon || "📚"}</span>
                <div>
                  <h3 className="font-semibold group-hover:text-indigo-400 transition-colors">
                    {space.name}
                  </h3>
                  <p className="text-xs text-zinc-500">
                    {space.pageCount || 0} pages
                  </p>
                </div>
              </div>
              {space.description && (
                <p className="line-clamp-2 text-sm text-zinc-400">
                  {space.description}
                </p>
              )}
            </Link>
          ))}
        </div>
      )}

      {/* Empty State */}
      {!loading && spaces.length === 0 && !showNewForm && (
        <div className="rounded-xl border border-dashed border-zinc-700 py-16 text-center">
          <BookOpen className="mx-auto mb-4 h-12 w-12 text-zinc-600" />
          <p className="text-zinc-500">
            No spaces yet. Create your first documentation space.
          </p>
        </div>
      )}
    </div>
  );
}
