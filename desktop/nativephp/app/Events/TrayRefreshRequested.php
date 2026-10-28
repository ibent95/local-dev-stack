<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Ask the panel to re-poll the stack status (tray → "Refresh status").
 *
 * NativePHP's EventWatcher forwards app events that broadcast on the
 * `nativephp` channel to the window as a `native-event`, which the panel
 * receives with `window.Native.on(...)`. (Events under
 * `Native\Desktop\Events\*` are deliberately skipped there — Electron
 * already broadcasts those itself.)
 */
class TrayRefreshRequested implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public string $requestedAt = '') {}

    /**
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        return [new Channel('nativephp')];
    }
}
