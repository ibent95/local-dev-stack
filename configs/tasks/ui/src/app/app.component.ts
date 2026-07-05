import { Component } from "@angular/core";
import { RouterOutlet, RouterLink, RouterLinkActive } from "@angular/router";
import { MatToolbarModule } from "@angular/material/toolbar";
import { MatButtonModule } from "@angular/material/button";
import { MatIconModule } from "@angular/material/icon";
import { MatSidenavModule } from "@angular/material/sidenav";
import { MatListModule } from "@angular/material/list";

@Component({
  selector: "app-root",
  standalone: true,
  imports: [
    RouterOutlet, RouterLink, RouterLinkActive,
    MatToolbarModule, MatButtonModule, MatIconModule,
    MatSidenavModule, MatListModule,
  ],
  template: `
    <mat-toolbar color="primary" class="app-toolbar">
      <button mat-icon-button (click)="sidenav.toggle()">
        <mat-icon>menu</mat-icon>
      </button>
      <span class="title">📋 LDS Tasks</span>
      <span class="subtitle">Project Management</span>
    </mat-toolbar>

    <mat-sidenav-container class="app-container">
      <mat-sidenav #sidenav mode="side" opened class="app-sidenav">
        <mat-nav-list>
          <a mat-list-item routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}">
            <mat-icon matListItemIcon>dashboard</mat-icon>
            <span matListItemTitle>Dashboard</span>
          </a>
          <mat-divider></mat-divider>
          <mat-list-item>
            <span matListItemTitle class="section-title">Workspaces</span>
          </mat-list-item>
        </mat-nav-list>
      </mat-sidenav>

      <mat-sidenav-content class="app-content">
        <router-outlet />
      </mat-sidenav-content>
    </mat-sidenav-container>
  `,
  styles: [`
    :host { display: flex; flex-direction: column; height: 100vh; }
    .app-toolbar { background: #1e1b4b; }
    .title { font-weight: bold; margin-left: 8px; }
    .subtitle { margin-left: 16px; font-size: 12px; opacity: 0.7; }
    .app-container { flex: 1; }
    .app-sidenav { width: 260px; background: #0f0f23; color: #e2e8f0; }
    .app-content { background: #18181b; color: #fafafa; }
    .active { background: rgba(99, 102, 241, 0.15) !important; }
    .section-title { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; opacity: 0.5; }
  `],
})
export class AppComponent {}
