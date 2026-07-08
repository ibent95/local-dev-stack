// =============================================================================
// LDS Tasks — TypeScript interfaces matching the Tasks API schema
// =============================================================================

export interface Workspace {
  id: number;
  name: string;
  slug: string;
  createdAt: string;
  projectCount?: number;
}

export interface Project {
  id: number;
  workspaceId: number;
  name: string;
  description: string | null;
  createdAt: string;
  taskCount?: number;
  statusColumns?: StatusColumn[];
  labels?: Label[];
}

export interface StatusColumn {
  id: number;
  projectId: number;
  name: string;
  position: number;
  color: string | null;
}

export interface Label {
  id: number;
  projectId: number;
  name: string;
  color: string | null;
}

export interface Task {
  id: number;
  projectId: number;
  statusColumnId: number | null;
  title: string;
  description: string | null;
  assignee: string | null;
  priority: string | null;
  position: number;
  dueDate: string | null;
  createdAt: string;
  updatedAt: string;
  labels?: Label[];
  comments?: TaskComment[];
}

export interface TaskComment {
  id: number;
  taskId: number;
  author: string | null;
  content: string;
  createdAt: string;
}

export interface WikiSpace {
  id: number;
  workspaceId: number;
  name: string;
  slug: string;
  description: string | null;
  createdAt: string;
}

export interface WikiPage {
  id: number;
  spaceId: number;
  title: string;
  slug: string;
  content: any;
  contentHtml: string | null;
  version: number;
  createdAt: string;
  updatedAt: string;
}
