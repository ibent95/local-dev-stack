import { Component, signal, OnInit } from '@angular/core';
import { Router, ActivatedRoute, RouterLink } from '@angular/router';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { Workspace, Project } from '../../models/task.models';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [DatePipe, FormsModule, RouterLink],
  template: `
    <div class="dashboard">
      <header class="page-header">
        <h1>Dashboard</h1>
        <p class="subtitle">Manage your workspaces and projects</p>
      </header>

      @if (loading()) {
        <div class="loading">Loading...</div>
      } @else if (workspace()) {
        <div class="workspace-detail">
          <div class="workspace-header">
            <h2>{{ workspace()!.name }}</h2>
            <button class="btn btn-primary" (click)="showNewProject.set(true)">+ New Project</button>
          </div>

          @if (showNewProject()) {
            <div class="new-project-form card">
              <input type="text" placeholder="Project name" [(ngModel)]="newProjectName" (keydown.enter)="createProject()" />
              <input type="text" placeholder="Description (optional)" [(ngModel)]="newProjectDesc" (keydown.enter)="createProject()" />
              <div class="form-actions">
                <button class="btn btn-ghost btn-sm" (click)="showNewProject.set(false)">Cancel</button>
                <button class="btn btn-primary btn-sm" (click)="createProject()">Create</button>
              </div>
            </div>
          }

          @if (workspace()!.projects && workspace()!.projects.length > 0) {
            <div class="projects-grid">
              @for (project of workspace()!.projects; track project.id) {
                <a class="card project-card" [routerLink]="['/project', project.id]">
                  <h3>{{ project.name }}</h3>
                  @if (project.description) {
                    <p class="desc">{{ project.description }}</p>
                  }
                  <div class="meta">
                    <span class="badge">{{ project.taskCount || 0 }} tasks</span>
                    <span class="date">{{ project.createdAt | date:'mediumDate' }}</span>
                  </div>
                </a>
              }
            </div>
          } @else {
            <div class="empty-state">
              <h3>No projects yet</h3>
              <p>Create your first project to get started</p>
            </div>
          }
        </div>
      } @else {
        <div class="workspace-grid">
          <h2>Workspaces</h2>

          @if (showNewWorkspace()) {
            <div class="new-project-form card">
              <input type="text" placeholder="Workspace name" [(ngModel)]="newWorkspaceName" (keydown.enter)="createWorkspace()" />
              <div class="form-actions">
                <button class="btn btn-ghost btn-sm" (click)="showNewWorkspace.set(false)">Cancel</button>
                <button class="btn btn-primary btn-sm" (click)="createWorkspace()">Create</button>
              </div>
            </div>
          }

          @if (workspaces.length > 0) {
            <div class="projects-grid">
              @for (ws of workspaces; track ws.id) {
                <a class="card project-card" [routerLink]="['/workspace', ws.slug]">
                  <h3>{{ ws.name }}</h3>
                  <div class="meta">
                    <span class="badge">{{ ws.projectCount || 0 }} projects</span>
                    <span class="date">{{ ws.createdAt | date:'mediumDate' }}</span>
                  </div>
                </a>
              }
              <button class="card project-card new-card" (click)="showNewWorkspace.set(true)">
                <span class="plus-icon">+</span>
                <span>New Workspace</span>
              </button>
            </div>
          } @else {
            <div class="empty-state">
              <h3>No workspaces yet</h3>
              <p>Create a workspace to organize your projects</p>
              <button class="btn btn-primary" (click)="showNewWorkspace.set(true)">+ New Workspace</button>
            </div>
          }
        </div>
      }
    </div>
  `,
  styleUrl: './dashboard.component.scss',
})
export class DashboardComponent implements OnInit {
  workspaces: Workspace[] = [];
  workspace = signal<(Workspace & { projects: Project[] }) | null>(null);
  loading = signal(true);
  showNewWorkspace = signal(false);
  showNewProject = signal(false);
  newWorkspaceName = '';
  newProjectName = '';
  newProjectDesc = '';
  private wsSlug: string | null = null;

  constructor(private api: ApiService, private route: ActivatedRoute, private router: Router) {}

  ngOnInit() {
    this.route.params.subscribe((params) => {
      this.wsSlug = params['slug'] || null;
      if (this.wsSlug) {
        this.loadWorkspace(this.wsSlug);
      } else {
        this.loadWorkspaces();
      }
    });
  }

  loadWorkspaces() {
    this.loading.set(true);
    this.workspace.set(null);
    this.api.getWorkspaces().subscribe({
      next: (ws) => { this.workspaces = ws; this.loading.set(false); },
      error: () => this.loading.set(false),
    });
  }

  loadWorkspace(slug: string) {
    this.loading.set(true);
    this.api.getWorkspace(slug).subscribe({
      next: (ws) => { this.workspace.set(ws); this.loading.set(false); },
      error: () => this.loading.set(false),
    });
  }

  createWorkspace() {
    if (!this.newWorkspaceName.trim()) return;
    this.api.createWorkspace({ name: this.newWorkspaceName.trim() }).subscribe({
      next: (ws) => {
        this.workspaces.push(ws);
        this.newWorkspaceName = '';
        this.showNewWorkspace.set(false);
      },
    });
  }

  createProject() {
    if (!this.wsSlug || !this.newProjectName.trim()) return;
    this.api.createProject(this.wsSlug, {
      name: this.newProjectName.trim(),
      description: this.newProjectDesc.trim() || undefined,
    }).subscribe({
      next: () => {
        this.newProjectName = '';
        this.newProjectDesc = '';
        this.showNewProject.set(false);
        this.loadWorkspace(this.wsSlug!);
      },
    });
  }
}
