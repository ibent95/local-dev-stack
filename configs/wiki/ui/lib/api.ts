const BASE = "/api";

// ─── Fetch helpers ───────────────────────────────────────────────

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`);
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function postJson<T>(path: string, data: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function putJson<T>(path: string, data: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function patchJson<T>(path: string, data: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function deleteJson(path: string): Promise<void> {
  const res = await fetch(`${BASE}${path}`, { method: "DELETE" });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
}

// ─── Types ───────────────────────────────────────────────────────

export interface Space {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  icon: string | null;
  color: string | null;
  createdAt: string;
  updatedAt: string;
  pageCount?: number;
  categories?: Category[];
}

export interface Category {
  id: number;
  spaceId: number;
  name: string;
  slug: string;
  description: string | null;
  position: number;
  pageCount?: number;
}

export interface Page {
  id: number;
  spaceId: number;
  categoryId: number | null;
  title: string;
  slug: string;
  content: unknown;
  contentHtml: string | null;
  toc: unknown;
  version: number;
  isPublished: boolean;
  isPinned: boolean;
  viewCount: number;
  createdAt: string;
  updatedAt: string;
  spaceName?: string;
  spaceSlug?: string;
  categoryName?: string;
  tags?: Tag[];
  comments?: Comment[];
  space?: Space;
  category?: Category;
}

export interface PageRevision {
  id: number;
  version: number;
  title: string;
  message: string | null;
  contentHtml?: string | null;
  createdAt: string;
}

export interface Comment {
  id: number;
  pageId: number;
  author: string;
  content: string;
  createdAt: string;
}

export interface Tag {
  id: number;
  name: string;
  color: string;
}

export interface SearchResult {
  id: number;
  title: string;
  slug: string;
  contentHtml: string | null;
  viewCount: number;
  createdAt: string;
  updatedAt: string;
  spaceName: string;
  spaceSlug: string;
  categoryName: string | null;
  relevance: number;
}
