import { Component, signal, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { NgFor, NgIf, NgClass, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { CdkDragDrop, CdkDrag, CdkDropList, CdkDropListGroup } from '@angular/cdk/drag-drop';
import { ApiService } from '../../services/api.service';
import { Project, StatusColumn, Task, Label } from '../../models/task.models';

@Component({
  selector: 'app-project-board',
  standalone: true,
  imports: [NgFor, NgIf, NgClass, DatePipe, FormsModule, RouterLink, CdkDropList, CdkDrag, CdkDropListGroup],
  template: `
    <div class="board" *ngIf="project() as p">
      <header class="page-header">
        <a class="back-link" routerLink="/workspace/default">← Workspace</a>
        <h1>{{ p.name }}</h1>
        <p class="subtitle" *ngIf="p.description">{{ p.description }}</p>
      </header>

      @if (showNewTask()) {
        <div class="new-task-form card">
          <input type="text" placeholder="Task title" [(ngModel)]="newTaskTitle"
                 (keydown.enter)="createTask()" autofocus />
          <div class="form-row">
            <select [(ngModel)]="newTaskStatus">
              <option value="">Select column</option>
              @for (col of columns(); track col.id) {
                <option [value]="col.id">{{ col.name }}</option>
              }
            </select>
            <select [(ngModel)]="newTaskPriority">
              <option value="low">Low</option>
              <option value="medium" selected>Medium</option>
              <option value="high">High</option>
              <option value="urgent">Urgent</option>
            </select>
          </div>
          <div class="form-actions">
            <button class="btn btn-ghost btn-sm" (click)="showNewTask.set(false)">Cancel</button>
            <button class="btn btn-primary btn-sm" (click)="createTask()">Create Task</button>
          </div>
        </div>
      }

      <div class="kanban" cdkDropListGroup>
        @for (col of columns(); track col.id) {
          <div class="column">
            <div class="column-header">
              <span class="col-dot" [style.background]="col.color || '#6366f1'"></span>
              <h3>{{ col.name }}</h3>
              <span class="col-count">{{ getTasksForColumn(col.id).length }}</span>
              <button class="btn-icon" (click)="showNewTaskForColumn(col.id)">+</button>
            </div>

            <div class="task-list" cdkDropList [cdkDropListData]="col.id"
                 (cdkDropListDropped)="onDrop($event)">
              @for (task of getTasksForColumn(col.id); track task.id) {
                <a class="task-card card" [routerLink]="['/task', task.id]" cdkDrag [cdkDragData]="task">
                  <h4>{{ task.title }}</h4>
                  <div class="task-meta">
                    <span class="badge" [ngClass]="'priority-' + (task.priority || 'medium')">
                      {{ task.priority || 'medium' }}
                    </span>
                    @if (task.labels && task.labels.length > 0) {
                      <span class="label-dot" *ngFor="let label of task.labels"
                            [style.background]="label.color || '#6366f1'"
                            [title]="label.name"></span>
                    }
                    @if (task.assignee) {
                      <span class="assignee">{{ task.assignee }}</span>
                    }
                  </div>
                  @if (task.dueDate) {
                    <div class="due-date">Due: {{ task.dueDate | date:'mediumDate' }}</div>
                  }
                </a>
              }
            </div>
          </div>
        }

        <div class="column add-column">
          <button class="add-col-btn" (click)="addColumn()">
            + Add Column
          </button>
        </div>
      </div>
    </div>
  `,
  styleUrl: './project-board.component.scss',
})
export class ProjectBoardComponent implements OnInit {
  project = signal<(Project & { statusColumns: StatusColumn[]; labels: Label[] }) | null>(null);
  columns = signal<StatusColumn[]>([]);
  tasks = signal<Task[]>([]);
  showNewTask = signal(false);
  newTaskTitle = '';
  newTaskStatus = '';
  newTaskPriority = 'medium';
  private projectId = 0;

  constructor(private api: ApiService, private route: ActivatedRoute) {}

  ngOnInit() {
    this.route.params.subscribe((params) => {
      this.projectId = Number(params['id']);
      if (this.projectId) this.loadProject();
    });
  }

  loadProject() {
    this.api.getProject(this.projectId).subscribe({
      next: (p) => {
        this.project.set(p);
        this.columns.set(p.statusColumns || []);
        this.loadTasks();
      },
    });
  }

  loadTasks() {
    this.api.getTasks(this.projectId).subscribe({
      next: (t) => this.tasks.set(t),
    });
  }

  getTasksForColumn(colId: number): Task[] {
    return this.tasks().filter((t) => t.statusColumnId === colId);
  }

  showNewTaskForColumn(colId: number) {
    this.newTaskStatus = String(colId);
    this.showNewTask.set(true);
  }

  createTask() {
    if (!this.newTaskTitle.trim()) return;
    this.api.createTask(this.projectId, {
      title: this.newTaskTitle.trim(),
      statusColumnId: this.newTaskStatus ? Number(this.newTaskStatus) : undefined,
      priority: this.newTaskPriority,
    }).subscribe({
      next: () => {
        this.newTaskTitle = '';
        this.showNewTask.set(false);
        this.loadTasks();
      },
    });
  }

  addColumn() {
    const name = prompt('Column name:');
    if (!name) return;
    this.api.createStatusColumn(this.projectId, { name }).subscribe({
      next: (col) => this.columns.update((cols) => [...cols, col]),
    });
  }

  onDrop(event: CdkDragDrop<number>) {
    if (event.previousContainer === event.container) return;
    const task = event.item.data as Task;
    this.api.updateTask(task.id, { statusColumnId: event.container.data }).subscribe({
      next: () => this.loadTasks(),
    });
  }
}
