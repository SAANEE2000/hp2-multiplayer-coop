[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][int]$GameProcessId,
    [Parameter(Mandatory=$true)][long]$GameStartTicks,
    [string]$ExpectedExecutable,
    [string]$Title = 'Harry Potter 2 Multiplayer',
    [ValidateRange(100,5000)][int]$PollMilliseconds = 300
)
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace HP2MP {
    public static class WindowFrameWatcher {
        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int Left, Top, Right, Bottom; }
        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
        private static extern int GetWindowLong(IntPtr hWnd, int index);
        [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
        private static extern int SetWindowLong(IntPtr hWnd, int index, int value);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool SetWindowText(IntPtr hWnd, string text);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetWindowPos(
            IntPtr hWnd, IntPtr hWndInsertAfter,
            int X, int Y, int cx, int cy, uint uFlags);

        public static IntPtr FindLargestVisibleWindow(int processId) {
            IntPtr best = IntPtr.Zero;
            long bestArea = 0;
            EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
                uint owner;
                RECT rect;
                GetWindowThreadProcessId(hWnd, out owner);
                if (owner != (uint)processId || !IsWindowVisible(hWnd) || !GetWindowRect(hWnd, out rect))
                    return true;
                long width = Math.Max(0, rect.Right - rect.Left);
                long height = Math.Max(0, rect.Bottom - rect.Top);
                long area = width * height;
                if (area > bestArea) { bestArea = area; best = hWnd; }
                return true;
            }, IntPtr.Zero);
            return best;
        }

        public static bool HasMovableFrame(IntPtr hWnd) {
            const int GWL_STYLE = -16;
            const int WS_POPUP = unchecked((int)0x80000000);
            const int WS_CAPTION = 0x00C00000;
            const int WS_THICKFRAME = 0x00040000;
            int style = GetWindowLong(hWnd, GWL_STYLE);
            return (style & WS_POPUP) == 0
                && (style & WS_CAPTION) == WS_CAPTION
                && (style & WS_THICKFRAME) == WS_THICKFRAME;
        }

        public static bool TryGetWindowSize(IntPtr hWnd, out int width, out int height) {
            RECT rect;
            if (!GetWindowRect(hWnd, out rect)) {
                width = 0;
                height = 0;
                return false;
            }
            width = Math.Max(0, rect.Right - rect.Left);
            height = Math.Max(0, rect.Bottom - rect.Top);
            return width > 0 && height > 0;
        }

        public static bool RestoreMovableFrame(IntPtr hWnd, string title, int width, int height) {
            const int GWL_STYLE = -16;
            const int WS_POPUP = unchecked((int)0x80000000);
            const int WS_OVERLAPPEDWINDOW = 0x00CF0000;
            const uint FRAME_CHANGED_NO_MOVE = 0x0036;
            int style = GetWindowLong(hWnd, GWL_STYLE);
            style = (style & ~WS_POPUP) | WS_OVERLAPPEDWINDOW;
            SetWindowLong(hWnd, GWL_STYLE, style);
            if (!String.IsNullOrEmpty(title)) SetWindowText(hWnd, title);
            bool refreshed = SetWindowPos(
                hWnd, IntPtr.Zero, 0, 0, width, height, FRAME_CHANGED_NO_MOVE);
            return refreshed && HasMovableFrame(hWnd);
        }

        public static bool RestoreWindowSize(IntPtr hWnd, int width, int height) {
            const uint NO_MOVE_NO_ACTIVATE = 0x0016;
            RECT current;
            int requestedWidth = width;
            int requestedHeight = height;
            if (GetWindowRect(hWnd, out current)) {
                int currentWidth = Math.Max(0, current.Right - current.Left);
                int currentHeight = Math.Max(0, current.Bottom - current.Top);
                // M212 reacts to the style change by subtracting the new
                // non-client border once. Compensate only for an observed
                // shortfall; if Windows did not subtract it, the next poll
                // sets the exact target and converges there as well.
                if (currentWidth < width) requestedWidth += width - currentWidth;
                if (currentHeight < height) requestedHeight += height - currentHeight;
            }
            return SetWindowPos(
                hWnd, IntPtr.Zero, 0, 0, requestedWidth, requestedHeight, NO_MOVE_NO_ACTIVATE);
        }
    }
}
'@

$expectedPath = if ($ExpectedExecutable) {
    [IO.Path]::GetFullPath($ExpectedExecutable)
} else {
    $null
}
$lastHandle = [IntPtr]::Zero
$lastFramedWidth = 0
$lastFramedHeight = 0
$sizeLockUntil = [DateTime]::MinValue

while ($true) {
    $game = Get-Process -Id $GameProcessId -ErrorAction SilentlyContinue
    if (!$game) { break }

    try {
        if ($game.StartTime.Ticks -ne $GameStartTicks) { break }
        if ($expectedPath -and ![string]::Equals(
                [IO.Path]::GetFullPath($game.Path), $expectedPath,
                [StringComparison]::OrdinalIgnoreCase)) { break }
    } catch {
        break
    }

    $handle = [HP2MP.WindowFrameWatcher]::FindLargestVisibleWindow($GameProcessId)
    if ($handle -ne [IntPtr]::Zero) {
        if ($handle -ne $lastHandle) {
            Write-Output "Tracking render window 0x$($handle.ToInt64().ToString('X'))."
            $lastHandle = $handle
            $lastFramedWidth = 0
            $lastFramedHeight = 0
            $sizeLockUntil = [DateTime]::MinValue
        }
        if ([HP2MP.WindowFrameWatcher]::HasMovableFrame($handle)) {
            $currentWidth = 0
            $currentHeight = 0
            if ([HP2MP.WindowFrameWatcher]::TryGetWindowSize(
                    $handle, [ref]$currentWidth, [ref]$currentHeight)) {
                if ([DateTime]::UtcNow -lt $sizeLockUntil -and
                    ($currentWidth -ne $lastFramedWidth -or $currentHeight -ne $lastFramedHeight)) {
                    [void][HP2MP.WindowFrameWatcher]::RestoreWindowSize(
                        $handle, $lastFramedWidth, $lastFramedHeight)
                } else {
                    $lastFramedWidth = $currentWidth
                    $lastFramedHeight = $currentHeight
                }
            }
        } else {
            if ($lastFramedWidth -le 0 -or $lastFramedHeight -le 0) {
                [void][HP2MP.WindowFrameWatcher]::TryGetWindowSize(
                    $handle, [ref]$lastFramedWidth, [ref]$lastFramedHeight)
            }
            if ([HP2MP.WindowFrameWatcher]::RestoreMovableFrame(
                    $handle, $Title, $lastFramedWidth, $lastFramedHeight)) {
                # The renderer may react to WM_STYLECHANGED by shrinking the
                # outer rectangle once. Hold the last user-sized rectangle
                # briefly, then resume observing normal user resizes.
                $sizeLockUntil = [DateTime]::UtcNow.AddSeconds(3)
                Write-Output "Restored movable frame at $(Get-Date -Format o)."
            } else {
                Write-Warning "Failed to restore the movable frame at $(Get-Date -Format o)."
            }
        }
    }

    Start-Sleep -Milliseconds $PollMilliseconds
}

Write-Output 'Game process ended; frame watcher stopped.'
