import { Component, OnInit } from "@angular/core";
import { CommonModule } from "@angular/common";
import { ActivatedRoute, RouterLink } from "@angular/router";
import { FormsModule } from "@angular/forms";
import { MatCardModule } from "@angular/material/card";
import { MatButtonModule } from "@angular/material/button";
import { MatIconModule } from "@angular/material/icon";
import { MatInputModule } from "@angular/material/input";
import { MatFormFieldModule } from "@angular/material/form-field";
import { TasksService, Workspace, Project } from "../../services/tasks.service";

@Component({
  selector: "app-workspace",
  standalone: true,
  imports: [
    CommonModule, RouterLink, FormsModule,
    MatCardModule, MatButtonModule, MatIconModule,
    MatInputModule, MatFormFieldModule,
  ],
  template: `
    <div class="p-6">
      <div class="mb-6 flex items-center justify-between">
        <div>
          <a routerLink="/" class="text-sm text-zinc-400 hover:text-white">← Back</a>
          <h1 class="mt-2 text-2xl font-bold">{{ workspace?.name }}</h1>
        </div>
        <button mat-flat-button color="primary" (click)="showNewForm = true">
          <mat-icon>add</mat-icon> New Project
        </button>
      </div>

      @if (showNewForm) {
        <mat-card class="mb-6">
          <mat-card-content>
            <mat-form-field appearance="outline" class="w-full">
              <mat-label>Project Name</mat-label>
              <input matInput [(ngModel)]="newName" />
            </mat-form-field>
            <mat-form-field appearance="outline" class="w-full">
              <mat-label>Description</mat-label>
              <textarea matInput [(ngModel)]="newDesc"></textarea>
            </mat-form-field>
            <div class="flex gap-2">
              <button mat-flat-button color="primary" (click)="createProject()">Create</button>
              <button mat-stroked-button (click)="showNewForm = false">Cancel</button>
            </div>
          </mat-card-content>
        </mat-card>
      }

      <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
        @for (proj of projects; track proj.id) {
          <a [routerLink]="['/project', proj.id]" class="project-card">
            <mat-card>
              <mat-card-header>
                <mat-card-title>{{ proj.name }}</mat-card-title>
                <mat-card-subtitle>{{ proj.taskCount }} tasks</mat-card-subtitle>
              </mat-card-header>
              @if (proj.description) {
                <mat-card-content>
                  <p class="text-sm text-zinc-400">{{ proj.description }}</p>
                </mat-card-content>
              }
            </mat-card>
          </a>
        }
      </div>
    </div>
  `,
  styles: [`
    .project-card { text-decoration: none; display: block; }
    .project-card mat-card { cursor: pointer; transition: transform 0.15s, box-shadow 0.15s; }
    .project-card mat-card:hover { transform: translateY(-2px); box-shadow: 0 4px 16px rgba(0,0,0,0.3); }
  `],
})
export class WorkspaceComponent implements OnInit {
  workspace: (Workspace & { projects: Project[] }) | null = null;
  projects: Project[] = [];
  showNewForm = false;
  newName = "";
  newDesc = "";

  constructor(private route: ActivatedRoute, private service: TasksService) {}

  ngOnInit() {
    const slug = this.route.snapshot.paramMap.get("slug")!;
    this.service.getWorkspace(slug).subscribe((ws) => {
      this.workspace = ws;
      this.projects = ws.projects || [];
    });
  }

  createProject() {
    if (!this.workspace) return;
    this.service.createProject(this.workspace.slug, { name: this.newName, description: this.newDesc }).subscribe((p) => {
      this.projects.push(p);
      this.newName = "";
      this.newDesc = "";
      this.showNewForm = false;
    });
  }
}
