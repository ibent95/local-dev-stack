import { Component, signal, OnInit } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { ApiService } from './services/api.service';
import { Workspace } from './models/task.models';
import { NgIf } from '@angular/common';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, NgIf],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App implements OnInit {
  workspaces = signal<Workspace[]>([]);

  constructor(private api: ApiService) {}

  ngOnInit() {
    this.api.getWorkspaces().subscribe({
      next: (ws) => this.workspaces.set(ws),
      error: () => {},
    });
  }
}
