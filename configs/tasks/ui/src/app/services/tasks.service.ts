import { Injectable } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { Observable } from "rxjs";

const BASE = "/api";

export interface Workspace {
  id: number;
  name: string;
  slug: string;
  created_at: string;
  projectCount: number;
}

export interface Project {
  id: number;
  name: string;
  description: string | null;
  workspaceId: number;
  created_at: string;
  taskCount: number;
}

export interface StatusColumn {
  id: number;
  projectId: number;
  name: string;
  position: number;
  color: string;
}

export interface Task {
  id: number;
  projectId: number;
  statusColumnId: number | null;
  title: string;
  description: string | null;
  assignee: string | null;
  priority: string;
  position: number;
  dueDate: string | null;
  created_at: string;
  updated_at: string;
  labels?: Label[];
  comments?: TaskComment[];
}

export interface Label {
  id: number;
  projectId: number;
  name: string;
  color: string;
}

export interface TaskComment {
  id: number;
  taskId: number;
  author: string;
  content: string;
  created_at: string;
}

@Injectable({ providedIn: "root" })
export class TasksService {
  constructor(private http: HttpClient) {}

  // Workspaces
  getWorkspaces(): Observable<Workspace[]> {
    return this.http.get<Workspace[]>(`${BASE}/workspaces`);
  }

  getWorkspace(slug: string): Observable<Workspace & { projects: Project[] }> {
    return this.http.get<Workspace & { projects: Project[] }>(`${BASE}/workspaces/${slug}`);
  }

  createWorkspace(data: { name: string }): Observable<Workspace> {
    return this.http.post<Workspace>(`${BASE}/workspaces`, data);
  }

  // Projects
  getProject(id: number): Observable<Project & { statusColumns: StatusColumn[]; labels: Label[] }> {
    return this.http.get<Project & { statusColumns: StatusColumn[]; labels: Label[] }>(`${BASE}/projects/${id}`);
  }

  createProject(workspaceSlug: string, data: { name: string; description?: string }): Observable<Project> {
    return this.http.post<Project>(`${BASE}/workspaces/${workspaceSlug}/projects`, data);
  }

  // Tasks
  getTasks(projectId: number): Observable<Task[]> {
    return this.http.get<Task[]>(`${BASE}/projects/${projectId}/tasks`);
  }

  createTask(projectId: number, data: { title: string; statusColumnId?: number; priority?: string }): Observable<Task> {
    return this.http.post<Task>(`${BASE}/projects/${projectId}/tasks`, data);
  }

  updateTask(id: number, data: Partial<Task>): Observable<Task> {
    return this.http.patch<Task>(`${BASE}/tasks/${id}`, data);
  }

  deleteTask(id: number): Observable<{ ok: boolean }> {
    return this.http.delete<{ ok: boolean }>(`${BASE}/tasks/${id}`);
  }

  // Comments
  addComment(taskId: number, data: { content: string; author?: string }): Observable<TaskComment> {
    return this.http.post<TaskComment>(`${BASE}/tasks/${taskId}/comments`, data);
  }
}
