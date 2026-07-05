const BASE = "/api";

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`);
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function postJson<T>(path: string, data: any): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function putJson<T>(path: string, data: any): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export interface Space {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  icon: string | null;
  color: string | null;
  created_at: string;
  updated_at: string;
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
  content: any;
  contentHtml: string | null;
  toc: any;
  version: number;
  isPublished: boolean;
  isPinned: boolean;
  viewCount: number;
  created_at: string;
  updated_at: string;
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
  content?: any;
  contentHtml?: string | null;
  created_at: string;
}

export interface Comment {
  id: number;
  pageId: number;
  author: string;
  content: string;
  created_at: string;
}

export interface Tag {
  id: number;
  name: string;
  color: string;
}
