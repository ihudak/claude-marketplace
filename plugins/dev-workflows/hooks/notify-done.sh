#!/usr/bin/env bash
# Fires at end of every Claude Code turn. Cross-platform completion notification.
# Always exits 0 — must never block Claude.

message="Claude Code finished"

if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e "display notification \"$message\" with title \"Claude Code\"" 2>/dev/null || true
elif grep -qi microsoft /proc/version 2>/dev/null; then
    wsl-notify-send --category "Claude Code" "$message" 2>/dev/null || \
    powershell.exe -Command \
      "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; \$n.ShowBalloonTip(3000, 'Claude Code', '$message', [System.Windows.Forms.ToolTipIcon]::None); Start-Sleep -Milliseconds 3500; \$n.Dispose()" 2>/dev/null || \
    echo -e '\a'
else
    notify-send "Claude Code" "$message" 2>/dev/null || echo -e '\a'
fi

exit 0
