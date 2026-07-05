import { Routes } from "@angular/router";

export const routes: Routes = [
  { path: "", loadComponent: () => import("./pages/dashboard/dashboard.component").then((m) => m.DashboardComponent) },
  { path: "workspace/:slug", loadComponent: () => import("./pages/workspace/workspace.component").then((m) => m.WorkspaceComponent) },
  { path: "project/:id", loadComponent: () => import("./pages/project/project.component").then((m) => m.ProjectComponent) },
];
