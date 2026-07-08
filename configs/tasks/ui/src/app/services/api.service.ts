import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import {
  Workspace, Project, Task, TaskComment, StatusColumn, Label, WikiSpace, WikiPage,
} from '../models/task.models';

@Injectable({ providedIn: 'root' })
export class ApiService {
  private baseUrl = '/api';

  constructor(private http: HttpClient) {}

  // ─── Workspaces ──────────────────────────────────────────────────
  getWorkspaces(): Observable<Workspace[]> {
    return this.http.get<Workspace[]>(`${this.baseUrl}/workspaces`);
  }

  getWorkspace(slug: string): Observable<Workspace & { projects: Project[] }> {
    return this.http.get<Workspace & { projects: Project[] }>(`${this.baseUrl}/workspaces/${slug}`);
  }

  createWorkspace(data: { name: string; slug?: string }): Observable<Workspace> {
    return this.http.post<Workspace>(`${this.baseUrl}/workspaces`, data);
  }

  // ─── Projects ────────────────────────────────────────────────────
  getProject(id: number): Observable<Project & { statusColumns: StatusColumn[]; labels: Label[] }> {
    return this.http.get<Project & { statusColumns: StatusColumn[]; labels: Label[] }>(
      `${this.baseUrl}/projects/${id}`
    );
  }

  createProject(workspaceSlug: string, data: { name: string; description?: string }): Observable<Project> {
    return this.http.post<Project>(`${this.baseUrl}/workspaces/${workspaceSlug}/projects`, data);
  }

  // ─── Tasks ───────────────────────────────────────────────────────
  getTasks(projectId: number): Observable<Task[]> {
    return this.http.get<Task[]>(`${this.baseUrl}/projects/${projectId}/tasks`);
  }

  getTask(id: number): Observable<Task & { labels: Label[]; comments: TaskComment[] }> {
    return this.http.get<Task & { labels: Label[]; comments: TaskComment[] }>(
      `${this.baseUrl}/tasks/${id}`
    );
  }

  createTask(projectId: number, data: {
    title: string;
    description?: string;
    statusColumnId?: number;
    assignee?: string;
    priority?: string;
    labelIds?: number[];
  }): Observable<Task> {
    return this.http.post<Task>(`${this.baseUrl}/projects/${projectId}/tasks`, data);
  }

  updateTask(id: number, data: Partial<Task & { labelIds: number[] }>): Observable<Task> {
    return this.http.patch<Task>(`${this.baseUrl}/tasks/${id}`, data);
  }

  deleteTask(id: number): Observable<{ ok: true }> {
    return this.http.delete<{ ok: true }>(`${this.baseUrl}/tasks/${id}`);
  }

  // ─── Task Comments ───────────────────────────────────────────────
  addComment(taskId: number, data: { author?: string; content: string }): Observable<TaskComment> {
    return this.http.post<TaskComment>(`${this.baseUrl}/tasks/${taskId}/comments`, data);
  }

  deleteComment(taskId: number, commentId: number): Observable<{ ok: true }> {
    return this.http.delete<{ ok: true }>(`${this.baseUrl}/tasks/${taskId}/comments/${commentId}`);
  }

  // ─── Status Columns ──────────────────────────────────────────────
  createStatusColumn(projectId: number, data: { name: string; color?: string }): Observable<StatusColumn> {
    return this.http.post<StatusColumn>(`${this.baseUrl}/projects/${projectId}/status-columns`, data);
  }

  deleteStatusColumn(projectId: number, colId: number): Observable<{ ok: true }> {
    return this.http.delete<{ ok: true }>(`${this.baseUrl}/projects/${projectId}/status-columns/${colId}`);
  }

  // ─── Labels ──────────────────────────────────────────────────────
  createLabel(projectId: number, data: { name: string; color?: string }): Observable<Label> {
    return this.http.post<Label>(`${this.baseUrl}/projects/${projectId}/labels`, data);
  }

  deleteLabel(projectId: number, labelId: number): Observable<{ ok: true }> {
    return this.http.delete<{ ok: true }>(`${this.baseUrl}/projects/${projectId}/labels/${labelId}`);
  }
}
