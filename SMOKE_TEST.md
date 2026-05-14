# KeepAwake smoke test

Run each by hand. Pass before declaring build good.

1. Launch: `open KeepAwake.app` → cup-and-saucer icon in menubar, no Dock icon.
2. Left-click → toggles Keep Awake on; icon fills.
3. `pmset -g assertions | grep -i KeepAwake` → shows `PreventUserIdleSystemSleep`.
4. Left-click → toggles off; assertion gone.
5. Right-click → menu opens, header shows "Off" or "On".
6. Menu → Only on network → Set current Wi-Fi as target → SSID saved.
7. Switch to different SSID → within 30s, header countdown "pausing in Ns", icon orange badge.
8. Reconnect within 60s → green again.
9. Stay disconnected 60s → "Paused · waiting for <target>", assertion released.
10. Reconnect → re-acquires assertion.
11. Duration → 15 minutes → after 15min, auto-off + notification "KeepAwake session ended".
12. Duration → Until lid closes → close lid briefly → on wake, off.
13. Toggle Launch at Login → log out + back in → app in menubar.
14. `pkill -9 -f KeepAwake` while on → relaunch → state is off (no persistence).
15. `open KeepAwake.app; sleep 1; open KeepAwake.app` → one instance running.
16. Revoke Location permission in System Settings → menu shows "Grant Location permission..." entry → click → System Settings opens.
17. Sleep + wake Mac → assertion still held (`pmset -g assertions`).
