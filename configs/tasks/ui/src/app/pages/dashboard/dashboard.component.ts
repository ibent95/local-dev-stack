import { Component, OnInit } from "@angular/core";
import { CommonModule } from "@angular/common";
import { RouterLink } from "@angular/router";
import { FormsModule } from "@angular/forms";
import { MatCardModule } from "@angular/material/card";
import { MatButtonModule } from "@angular/material/button";
import { MatIconModule } from "@angular/material/icon";
import { MatInputModule } from "@angular/material/input";
import { MatFormFieldModule } from "@angular/material/form-field";
import { TasksService, Workspace } from "../../services/tasks.service";

@Component({
  selector: "app-dashboard",
  standalone: true,
  imports: [
    CommonModule, RouterLink, FormsModule,
    MatCardModule, MatButtonModule, MatIconModule,
    MatInputModule, MatFormFieldModule,
  ],
  template: `
    <div class="p-6">
      <div class="mb-6 flex items-center justify-between">
        <h1 class="text-2xl font-bold">Workspaces</h1>
        <button mat-flat-button color="primary" (click)="showNewForm = true">
          <mat-icon>add</mat-icon> New Workspace
        </button>
      </div>

      @if (showNewForm) {
        <mat-card class="mb-6">
          <mat-card-content>
            <mat-form-field appearance="outline" class="w-full">
              <mat-label>Workspace Name</mat-label>
              <input matInput [(ngModel)]="newName" placeholder="My Workspace" />
            </mat-form-field>
            <div class="flex gap-2">
              <button mat-flat-button color="primary" (click)="createWorkspace()">Create</button>
              <button mat-stroked-button (click)="showNewForm = false">Cancel</button>
            </div>
          </mat-card-content>
        </mat-card>
      }

      <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
        @for (ws of workspaces; track ws.id) {
          <a [routerLink]="['/workspace', ws.slug]" class="workspace-card">
            <mat-card>
              <mat-card-header>
                <mat-card-title>{{ ws.name }}</mat-card-title>
                <mat-card-subtitle>{{ ws.projectCount }} projects</mat-card-subtitle>
              </mat-card-header>
            </mat-card>
          </a>
        }
      </div>
    </div>
  `,
  styles: [`
    .workspace-card { text-decoration: none; display: block; }
    .workspace-card mat-card { cursor: pointer; transition: transform 0.15s, box-shadow 0.15s; }
    .workspace-card mat-card:hover { transform: translateY(-2px); box-shadow: 0 4px 16px rgba(0,0,0,0.3); }
  `],
})
export class DashboardComponent implements OnInit {
  workspaces: Workspace[] = [];
  showNewForm = false;
  newName = "";

  constructor(private service: TasksService) {}

  ngOnInit() {
    this.service.getWorkspaces().subscribe((ws) => (this.workspaces = ws));
  }

  createWorkspace() {
    this.service.createWorkspace({ name: this.newName }).subscribe((ws) => {
      this.workspaces.push(ws);
      this.newName = "";
      this.showNewForm = false;
    });
  }
}
