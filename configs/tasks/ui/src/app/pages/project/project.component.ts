import { Component, OnInit } from "@angular/core";
import { CommonModule } from "@angular/common";
import { ActivatedRoute } from "@angular/router";
import { FormsModule } from "@angular/forms";
import { DragDropModule, CdkDragDrop, moveItemInArray, transferArrayItem } from "@angular/cdk/drag-drop";
import { MatCardModule } from "@angular/material/card";
import { MatButtonModule } from "@angular/material/button";
import { MatIconModule } from "@angular/material/icon";
import { MatInputModule } from "@angular/material/input";
import { MatFormFieldModule } from "@angular/material/form-field";
import { MatMenuModule } from "@angular/material/menu";
import { MatChipsModule } from "@angular/material/chips";
import { TasksService, Project, StatusColumn, Task } from "../../services/tasks.service";

@Component({
  selector: "app-project",
  standalone: true,
  imports: [
    CommonModule, FormsModule, DragDropModule,
    MatCardModule, MatButtonModule, MatIconModule,
    MatInputModule, MatFormFieldModule, MatMenuModule, MatChipsModule,
  ],
  template: `
    <div class="p-6">
      <div class="mb-6">
        <h1 class="text-2xl font-bold">{{ project?.name }}</h1>
        <p class="text-sm text-zinc-400">{{ project?.description }}</p>
      </div>

      @if (showNewTask) {
        <mat-card class="mb-4 max-w-md">
          <mat-card-content>
            <mat-form-field appearance="outline" class="w-full">
              <mat-label>Task title</mat-label>
              <input matInput [(ngModel)]="newTaskTitle" (keyup.enter)="createTask()" />
            </mat-form-field>
            <div class="flex gap-2">
              <button mat-flat-button color="primary" (click)="createTask()">Add</button>
              <button mat-stroked-button (click)="showNewTask = false">Cancel</button>
            </div>
          </mat-card-content>
        </mat-card>
      }

      <button mat-stroked-button class="mb-4" (click)="showNewTask = true">
        <mat-icon>add</mat-icon> Add Task
      </button>

      <!-- Kanban Board -->
      <div cdkDropListContainer class="kanban-board">
        @for (col of statusColumns; track col.id) {
          <div class="kanban-column" [style.border-top-color]="col.color">
            <div class="kanban-header">
              <span class="font-medium">{{ col.name }}</span>
              <span class="text-xs text-zinc-500">{{ getColumnTasks(col.id).length }}</span>
            </div>
            <div
              cdkDropList
              [cdkDropListData]="col.id"
              [id]="'col-' + col.id"
              [cdkDropListConnectedTo]="getConnectedListIds(col.id)"
              (cdkDropListDropped)="onDrop($event)"
              class="kanban-list"
            >
              @for (task of getColumnTasks(col.id); track task.id) {
                <mat-card cdkDrag class="task-card">
                  <mat-card-content>
                    <div class="flex items-start justify-between">
                      <span class="text-sm font-medium">{{ task.title }}</span>
                      <button mat-icon-button [matMenuTriggerFor]="taskMenu" class="-mt-1 -mr-2">
                        <mat-icon class="text-xs">more_vert</mat-icon>
                      </button>
                      <mat-menu #taskMenu="matMenu">
                        <button mat-menu-item (click)="deleteTask(task.id)">
                          <mat-icon color="warn">delete</mat-icon> Delete
                        </button>
                      </mat-menu>
                    </div>
                    <div class="mt-2 flex items-center gap-2">
                      @if (task.priority) {
                        <span class="rounded-full px-2 py-0.5 text-xs" [class]="priorityClass(task.priority)">
                          {{ task.priority }}
                        </span>
                      }
                      @if (task.assignee) {
                        <span class="text-xs text-zinc-400">→ {{ task.assignee }}</span>
                      }
                    </div>
                  </mat-card-content>
                </mat-card>
              }
            </div>
          </div>
        }
      </div>
    </div>
  `,
  styles: [`
    .kanban-board { display: flex; gap: 16px; overflow-x: auto; padding-bottom: 16px; }
    .kanban-column { min-width: 280px; flex-shrink: 0; background: #1a1a2e; border-radius: 8px; padding: 12px; border-top: 3px solid #6366f1; }
    .kanban-header { display: flex; justify-content: space-between; margin-bottom: 12px; padding: 4px 0; }
    .kanban-list { min-height: 200px; }
    .task-card { margin-bottom: 8px; cursor: move; background: #27272a !important; }
    .task-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.3); }
    .priority-low { background: #1e3a5f; color: #60a5fa; }
    .priority-medium { background: #3b2f00; color: #fbbf24; }
    .priority-high { background: #3b1219; color: #f87171; }
    .priority-urgent { background: #4c0519; color: #ef4444; font-weight: bold; }
    .cdk-drag-preview { box-shadow: 0 8px 24px rgba(0,0,0,0.4); }
    .cdk-drag-placeholder { opacity: 0.3; border: 2px dashed #6366f1; border-radius: 8px; min-height: 60px; }
  `],
})
export class ProjectComponent implements OnInit {
  project: (Project & { statusColumns: StatusColumn[] }) | null = null;
  statusColumns: StatusColumn[] = [];
  tasks: Task[] = [];
  showNewTask = false;
  newTaskTitle = "";

  constructor(private route: ActivatedRoute, private service: TasksService) {}

  ngOnInit() {
    const id = Number(this.route.snapshot.paramMap.get("id"));
    this.service.getProject(id).subscribe((p) => {
      this.project = p;
      this.statusColumns = p.statusColumns || [];
      this.loadTasks();
    });
  }

  loadTasks() {
    if (!this.project) return;
    this.service.getTasks(this.project.id).subscribe((t) => (this.tasks = t));
  }

  getColumnTasks(colId: number): Task[] {
    return this.tasks.filter((t) => t.statusColumnId === colId);
  }

  getConnectedListIds(currentColId: number): string[] {
    return this.statusColumns
      .filter((c) => c.id !== currentColId)
      .map((c) => "col-" + c.id);
  }

  onDrop(event: CdkDragDrop<number>) {
    if (event.previousContainer === event.container) {
      moveItemInArray(this.getColumnTasks(event.container.data), event.previousIndex, event.currentIndex);
    } else {
      const task = event.previousContainer.data === event.container.data
        ? this.getColumnTasks(event.container.data)[event.previousIndex]
        : (event.item.data as Task);
      task.statusColumnId = event.container.data;
      this.service.updateTask(task.id, { statusColumnId: event.container.data }).subscribe();
      transferArrayItem(
        event.previousContainer.data === event.container.data
          ? this.getColumnTasks(event.previousContainer.data)
          : this.tasks,
        this.getColumnTasks(event.container.data),
        event.previousIndex,
        event.currentIndex,
      );
    }
  }

  createTask() {
    if (!this.project || !this.newTaskTitle.trim()) return;
    const firstCol = this.statusColumns[0];
    this.service.createTask(this.project.id, {
      title: this.newTaskTitle,
      statusColumnId: firstCol?.id,
      priority: "medium",
    }).subscribe((t) => {
      this.tasks.push(t);
      this.newTaskTitle = "";
      this.showNewTask = false;
    });
  }

  deleteTask(id: number) {
    this.service.deleteTask(id).subscribe(() => {
      this.tasks = this.tasks.filter((t) => t.id !== id);
    });
  }

  priorityClass(priority: string): string {
    return `rounded-full px-2 py-0.5 text-xs priority-${priority}`;
  }
}
