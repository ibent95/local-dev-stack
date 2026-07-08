import { Component, signal, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink, Router } from '@angular/router';
import { NgClass, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { Task, Label, TaskComment } from '../../models/task.models';

@Component({
  selector: 'app-task-detail',
  standalone: true,
  imports: [NgClass, DatePipe, FormsModule, RouterLink],
  template: `
    @if (task(); as t) {
      <div class="task-detail">
        <header class="page-header">
          <a class="back-link" routerLink="/project/{{ t.projectId }}">← Back to Board</a>
          <h1>{{ t.title }}</h1>
          <div class="header-meta">
            <span class="badge" [ngClass]="'priority-' + (t.priority || 'medium')">
              {{ t.priority || 'medium' }}
            </span>
            <span class="date">Created: {{ t.createdAt | date:'medium' }}</span>
          </div>
        </header>

        <div class="detail-grid">
          <div class="main-col">
            <div class="card">
              <h3>Description</h3>
              @if (editingDesc()) {
                <textarea [(ngModel)]="editDesc" rows="4" placeholder="Add a description..."></textarea>
                <div class="form-actions">
                  <button class="btn btn-ghost btn-sm" (click)="editingDesc.set(false)">Cancel</button>
                  <button class="btn btn-primary btn-sm" (click)="saveDescription()">Save</button>
                </div>
              } @else {
                <p class="description" (click)="startEditDesc()">
                  {{ t.description || 'Click to add a description...' }}
                </p>
              }
            </div>

            <div class="card">
              <h3>Comments ({{ t.comments?.length || 0 }})</h3>
              <div class="comments">
                @for (comment of t.comments; track comment.id) {
                  <div class="comment">
                    <div class="comment-header">
                      <strong>{{ comment.author || 'Anonymous' }}</strong>
                      <span class="date">{{ comment.createdAt | date:'medium' }}</span>
                    </div>
                    <p>{{ comment.content }}</p>
                  </div>
                }
              </div>
              <div class="add-comment">
                <textarea [(ngModel)]="newComment" placeholder="Write a comment..." rows="2"></textarea>
                <button class="btn btn-primary btn-sm" (click)="addComment()">Comment</button>
              </div>
            </div>
          </div>

          <div class="side-col">
            <div class="card">
              <h3>Details</h3>
              <div class="detail-row">
                <label>Status</label>
                <select [(ngModel)]="editStatus" (change)="updateField('statusColumnId', editStatus ? +editStatus : null)">
                  <option value="">Unset</option>
                </select>
              </div>
              <div class="detail-row">
                <label>Priority</label>
                <select [(ngModel)]="editPriority" (change)="updateField('priority', editPriority)">
                  <option value="low">Low</option>
                  <option value="medium">Medium</option>
                  <option value="high">High</option>
                  <option value="urgent">Urgent</option>
                </select>
              </div>
              <div class="detail-row">
                <label>Assignee</label>
                <input type="text" [(ngModel)]="editAssignee" placeholder="Unassigned"
                      (blur)="updateField('assignee', editAssignee || null)" />
              </div>
              <div class="detail-row">
                <label>Due Date</label>
                <input type="date" [(ngModel)]="editDueDate"
                      (change)="updateField('dueDate', editDueDate || null)" />
              </div>
            </div>

            <div class="card">
              <h3>Labels</h3>
              <div class="labels-list">
                @for (label of t.labels; track label.id) {
                  <span class="label-tag" [style.background]="label.color || '#6366f1'">
                    {{ label.name }}
                  </span>
                }
              </div>
            </div>

            <div class="card danger-zone">
              <button class="btn btn-danger btn-sm" (click)="deleteTask()">Delete Task</button>
            </div>
          </div>
        </div>
      </div>
    }
  `,
  styleUrl: './task-detail.component.scss',
})
export class TaskDetailComponent implements OnInit {
  task = signal<(Task & { labels: Label[]; comments: TaskComment[] }) | null>(null);
  editingDesc = signal(false);
  editDesc = '';
  newComment = '';
  editStatus = '';
  editPriority = 'medium';
  editAssignee = '';
  editDueDate = '';

  constructor(private api: ApiService, private route: ActivatedRoute, private router: Router) { }

  ngOnInit() {
    this.route.params.subscribe((params) => {
      const id = Number(params['id']);
      if (id) this.loadTask(id);
    });
  }

  loadTask(id: number) {
    this.api.getTask(id).subscribe({
      next: (t) => {
        this.task.set(t);
        this.editDesc = t.description || '';
        this.editStatus = t.statusColumnId ? String(t.statusColumnId) : '';
        this.editPriority = t.priority || 'medium';
        this.editAssignee = t.assignee || '';
        this.editDueDate = t.dueDate ? t.dueDate.split('T')[0] : '';
      },
    });
  }

  startEditDesc() {
    this.editDesc = this.task()?.description || '';
    this.editingDesc.set(true);
  }

  saveDescription() {
    const t = this.task();
    if (!t) return;
    this.api.updateTask(t.id, { description: this.editDesc }).subscribe({
      next: () => {
        this.editingDesc.set(false);
        this.loadTask(t.id);
      },
    });
  }

  updateField(field: string, value: any) {
    const t = this.task();
    if (!t) return;
    this.api.updateTask(t.id, { [field]: value }).subscribe({
      next: () => this.loadTask(t.id),
    });
  }

  addComment() {
    const t = this.task();
    if (!t || !this.newComment.trim()) return;
    this.api.addComment(t.id, { content: this.newComment.trim() }).subscribe({
      next: () => {
        this.newComment = '';
        this.loadTask(t.id);
      },
    });
  }

  deleteTask() {
    const t = this.task();
    if (!t) return;
    if (!confirm('Delete this task?')) return;
    this.api.deleteTask(t.id).subscribe({
      next: () => this.router.navigate(['/project', t.projectId]),
    });
  }
}
