# Emulator test run: 2026-10-16 (GitHub Codespace)

**Outcome: BLOCKED. The APK was not installed, launched or tested.**

| Item | Value |
|---|---|
| APK | `/workspaces/tinystreet/build/tinystreet-debug.apk` (only copy found) |
| SHA-256 | `7c138dd72f88f827c436d3dbbefd70250c5e606ef7e1b70486caa217b0ab69b0` |
| Package / activity | `com.tinystreet.sortrestore` / `com.godot.game.GodotAppLauncher` |
| APK ABIs | arm64-v8a, armeabi-v7a, x86_64; minSdk 24 (Android 7.0), targetSdk 36; GLES 3.0 required |
| Host | GitHub Codespace, x86_64, 2 vCPU, 7.8 GB RAM, 4.8 GB free on `/` |
| Emulator | 37.2.12, AVD `ts36` (sdk_gphone64_x86_64, Pixel 5 profile), Android 16 / API 36, x86_64 |
| Acceleration | **None.** `/dev/kvm` exists but is `root:109 0660`, and this user is not in that group. Granting access with sudo was refused by the agent permission policy. Ran with `-accel off` (QEMU TCG), `-gpu swiftshader_indirect`. |

## What happened
1. Boot took about 7 min under TCG. `sys.boot_completed=1` (PASS).
2. Install attempt 1: adb chose incremental install because `.idsig` sits next to the APK, and it hung at "Serving..." (killed after 5 min).
3. Install attempt 2 (`--no-incremental`): no response in 8 min 20 s.
4. The guest load average was around 40. 69 ANR dumps were written, and `system_server` crashed (`FATAL EXCEPTION IN SYSTEM PROCESS`), after which "Can't find service: package".
5. Install attempt 3, after the settings provider came back: `Broken pipe (32)`. `system_server` died again mid-install.

The failure is in Android itself, not the game. Android 16 cannot run stably under software CPU emulation on 2 cores.

## Checks
| Check | Result |
|---|---|
| Emulator boot | PASS (TCG, slow) |
| Install APK | NOT TESTED (blocked: system_server crashes) |
| Launch, menu, sorting valid/invalid, level complete, rewards, café restore, pause/resume, Back, background/return, persistence, layout | NOT TESTED |

## Evidence files
Not in git; kept locally in `build/test-results-emulator/`: `device-info.txt`, `emulator.log`, `install.log`, `logcat-all.txt`, `system-server-failures.txt`, `anr-list.txt`
