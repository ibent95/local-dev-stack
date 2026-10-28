<?php

namespace App\Providers;

use Native\Desktop\Contracts\ProvidesPhpIni;
use Native\Desktop\Facades\Menu;
use Native\Desktop\Facades\MenuBar;
use Native\Desktop\Facades\Window;

class NativeAppServiceProvider implements ProvidesPhpIni
{
    /**
     * `boot()` can run more than once (macOS `activate`); creating the tray
     * twice would stack a second icon, so it is created only once per process.
     * A static flag is used instead of the cache store because the default
     * cache driver is the database, which may not be migrated on first run.
     */
    protected static bool $trayCreated = false;

    /**
     * Executed once the native application has been booted.
     * Opens the panel window and installs the tray icon + context menu.
     */
    public function boot(): void
    {
        if (! self::$trayCreated) {
            MenuBar::create()
                ->icon(public_path('images/tray.png'))
                ->tooltip('LDS Desktop (NativePHP)')
                // Pure tray: no popover window — the panel is a real window.
                ->onlyShowContextMenu()
                // Windows: skips the macOS-only app.dock.hide() call.
                ->showDockIcon()
                ->withContextMenu(
                    Menu::make(
                        Menu::label('Open LDS Desktop')->id('open'),
                        Menu::separator(),
                        Menu::label('Start all profiles')->id('start_all'),
                        Menu::label('Stop all')->id('stop_all'),
                        Menu::separator(),
                        Menu::label('Refresh status')->id('refresh'),
                        Menu::label('Hide panel')->id('hide'),
                        Menu::separator(),
                        Menu::quit(),
                    )
                );

            self::$trayCreated = true;
        }

        // The panel window. `closable(false)` removes the native close
        // affordance (NativePHP 2.3 has no close interception) — hide the
        // panel from the tray or the header's "Hide to tray" button; tray
        // Quit exits the app.
        Window::open('main')
            ->title('LDS Desktop — NativePHP')
            ->width(1180)
            ->height(820)
            ->closable(false);
    }

    /**
     * Return an array of php.ini directives to be set.
     */
    public function phpIni(): array
    {
        return [
        ];
    }
}
