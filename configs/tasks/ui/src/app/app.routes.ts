import { Routes } from '@angular/router';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { ProjectBoardComponent } from './pages/project-board/project-board.component';
import { TaskDetailComponent } from './pages/task-detail/task-detail.component';

export const routes: Routes = [
  { path: '', component: DashboardComponent },
  { path: 'workspace/:slug', component: DashboardComponent },
  { path: 'project/:id', component: ProjectBoardComponent },
  { path: 'task/:id', component: TaskDetailComponent },
  { path: '**', redirectTo: '' },
];
