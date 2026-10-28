<?php

namespace App\Providers;

use App\Events\TrayRefreshRequested;
use App\Services\LdsCli;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use Native\Desktop\Events\Menu\MenuItemClicked;
use Native\Desktop\Events\MenuBar\MenuBarClicked;
use Native\Desktop\Events\MenuBar\MenuBarDoubleClicked;
use Native\Desktop\Facades\Window;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // The panel's only dependency is the lds CLI wrapper (static, no binding needed).
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Tray menu actions (see NativeAppServiceProvider for the menu).
        Event::listen(MenuItemClicked::class, function (MenuItemClicked $event): void {
            $id = $event->item['id'] ?? '';

            match ($id) {
                'open' => Window::open('main'),
                'hide' => Window::hide('main'),
                'start_all' => LdsCli::detached(['up', 'all']),
                'stop_all' => LdsCli::detached(['down']),
                // The panel polls every 5 s anyway; this asks it to refresh now.
                'refresh' => TrayRefreshRequested::dispatch(now()->toTimeString()),
                // Menu::quit() is a native role — Electron exits on its own.
                default => null,
            };
        });

        // Left-click / double-click on the tray icon re-shows the panel.
        Event::listen(MenuBarClicked::class, fn () => Window::open('main'));
        Event::listen(MenuBarDoubleClicked::class, fn () => Window::open('main'));
    }
}
