# matt-desktop Idle Detection Fix

## TL;DR

> **Quick Summary**: Fix broken idle detection (30-min lock, 60-min screen off) after migrating from Hyprland to Niri by converting the evdev-idle-daemon from a system service to a user service that properly inherits the Niri session environment.
>
> **Deliverables**:
> - Evdev-idle-daemon converted to systemd.user.service with session environment
> - Proper child process cleanup (fixes 48→18 dd process leak)
> - Logging added for debugging future issues
>
> **Estimated Effort**: Short
> **Parallel Execution**: NO - sequential changes to same file
> **Critical Path**: Read current config → Write new user service config → Test

---

## Context

### Problem Statement
After migrating from Hyprland to Niri (commit `60eecf6`), idle detection broke:
- 30-minute idle → lock screen (hyprlock) doesn't trigger
- 60-minute idle → power off monitors doesn't trigger

Multiple fix attempts failed (commits `d9e7ad9`, `6c66baa`).

### Root Cause (Confirmed via Live Testing)
**System service lacks session environment**:
- `evdev-idle-daemon` runs as `systemd.services` with `User=matt`
- Missing critical env vars: `NIRI_SOCKET`, `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`
- `niri msg action power-off-monitors` always fails with "NIRI_SOCKET is not set"
- `hyprlock` likely fails silently without proper Wayland context

### Secondary Issue: Process Leak
- Service restarted 3 times on Mar 16, each time leaking old dd processes
- 48 dd processes instead of expected 18 (one per input device)
- Old processes never cleaned up due to missing process group termination

### Research Findings
- **Smithay bug #1892**: `ext_idle_notifier_v1` missing resumed events (affects swayidle, not our evdev approach)
- **Niri has no built-in idle timeout** - external daemon required
- **Niri docs recommend**: user services tied to `graphical-session.target` for session helpers
- **logind idle not viable**: nothing calls `SetIdleHint` for niri sessions
- **Linux input supports multiple readers**: evdev race condition theory was wrong

### Live Test Results (Confirmed)
- `niri msg action power-off-monitors` with proper env vars: **WORKS**
- `hyprlock` with proper env vars: **WORKS**
- dd reading `/dev/input/event*`: **WORKS** (devices idle, not broken)

---

## Work Objectives

### Core Objective
Fix idle detection so 30-min lock and 60-min screen off work reliably with Niri.

### Concrete Deliverables
1. System service converted to user service in `hosts/matt-desktop/configuration.nix`
2. Service bound to `graphical-session.target` instead of `graphical.target`
3. Removed hardcoded env vars - rely on inherited session environment
4. Added proper child process cleanup to prevent leaks
5. Added logging via `systemd-cat` for debugging

### Definition of Done
- [ ] `systemctl --user status evdev-idle-daemon` shows active (running)
- [ ] User environment contains `NIRI_SOCKET`, `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`
- [ ] After 30 min idle, hyprlock activates
- [ ] After 60 min idle, monitors power off
- [ ] No leaked dd processes after service restarts
- [ ] Manual `niri msg action power-off-monitors` works from user context

### Must Have
- User service architecture (not system service)
- Session environment inheritance
- Proper child process lifecycle management
- Debug logging for future troubleshooting

### Must NOT Have (Guardrails)
- **No hardcoded NIRI_SOCKET paths** - socket path changes per session
- **No system service with manually injected env** - brittle, session-specific
- **No swayidle** - still affected by Smithay bug
- **No reverting to Hyprland** - niri migration is the current direction

---

## Verification Strategy

### QA Policy
Every task MUST include agent-executed QA scenarios.

**Scenario: Verify user service is active**
```
Tool: Bash (ssh)
Preconditions: User logged into Niri session
Steps:
  1. ssh matt-desktop 'systemctl --user status evdev-idle-daemon'
  2. Assert output contains "Active: active (running)"
Expected Result: Service is running
Evidence: .sisyphus/evidence/idle-fix-user-service-active.txt
```

**Scenario: Verify session environment inherited**
```
Tool: Bash (ssh)
Preconditions: User logged into Niri session
Steps:
  1. ssh matt-desktop 'systemctl --user show-environment'
  2. grep for "NIRI_SOCKET\|WAYLAND_DISPLAY\|XDG_RUNTIME_DIR"
Expected Result: All three env vars present
Evidence: .sisyphus/evidence/idle-fix-session-env.txt
```

**Scenario: Verify dd process count after restart**
```
Tool: Bash (ssh)
Preconditions: Service will be restarted as part of config activation
Steps:
  1. Before: count dd processes with pgrep -c -f "dd if=/dev/input"
  2. Rebuild config: nixos-rebuild switch --flake .#matt-desktop
  3. After: count dd processes again
Expected Result: Process count stable at ~18 (one per input device)
Evidence: .sisyphus/evidence/idle-fix-dd-count.txt
```

**Scenario: Verify monitor power-off works**
```
Tool: Bash (ssh)
Preconditions: User logged into Niri session
Steps:
  1. ssh matt-desktop 'NIRI_SOCKET=$(grep NIRI_SOCKET < /proc/$(pgrep niri)/environ | cut -d= -f2) niri msg action power-off-monitors'
  2. Observe monitors turn off
  3. ssh matt-desktop 'NIRI_SOCKET=$(grep NIRI_SOCKET < /proc/$(pgrep niri)/environ | cut -d= -f2) niri msg action power-on-monitors'
Expected Result: Monitors off, then on
Evidence: .sisyphus/evidence/idle-fix-monitor-control.txt
```

---

## Execution Strategy

### Single Task (Sequential)

**Task 1: Convert evdev-idle-daemon from system service to user service**

Location: `hosts/matt-desktop/configuration.nix` (lines 298-399)

Changes:
1. Remove `systemd.services.evdev-idle-daemon` block
2. Add `systemd.user.services.evdev-idle-daemon` block
3. Change `wantedBy` from `graphical.target` to `graphical-session.target`
4. Remove hardcoded env vars (NIRI_SOCKET, WAYLAND_DISPLAY, XDG_RUNTIME_DIR)
5. Add `Environment="SYSTEMD_EXEC_BIN=/run/current-system/sw/bin/systemd"` for systemd-cat
6. Update script to use `ExecStartPost` for proper child process group cleanup
7. Add logging: `echo "idle-daemon: starting" | systemd-cat -t evdev-idle`
8. Add logging before each action with env var inspection

### Changes to Current Script Logic
- Keep same timeout values (LOCK_TIMEOUT=1800000, DISPLAY_TIMEOUT=3600000)
- Keep same state machine (active → locked → display_off)
- Keep same niri socket glob discovery (`/run/user/1000/niri.*.sock`)
- Add `trap` for proper cleanup of child processes on service stop
- Add `KillMode=process` to ensure children are killed on restart

---

## TODOs

- [x] 1. Convert evdev-idle-daemon to systemd.user.services

  **What to do**:
  - Read current `systemd.services.evdev-idle-daemon` definition (lines 298-399)
  - Delete the system service block
  - Create new `systemd.user.services.evdev-idle-daemon` block with:
    - `wantedBy = ["graphical-session.target"]`
    - `after = ["graphical-session.target"]`
    - `PartOf = ["graphical-session.target"]`
    - Remove all hardcoded env vars from script
    - Add child process group cleanup (`kill 0` on exit)
    - Add `systemd-cat` logging for debugging
    - Keep same timeout and state machine logic
  - Run `nixos-rebuild switch --flake .#matt-desktop`
  - Verify service is active: `systemctl --user status evdev-idle-daemon`
  - Verify dd process count is stable (~18, not 48)
  - Manual test: `niri msg action power-off-monitors` works

  **Must NOT do**:
  - Hardcode `NIRI_SOCKET=/run/user/1000/niri.wayland-1.41080.sock`
  - Keep as system service
  - Remove the timeout logic (it works, just needs proper env)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single-file Nix change, well-understood modification
  - **Skills**: `nixos`
    - nixos: Required for understanding systemd.user.services syntax

  **References**:
  - `hosts/matt-desktop/configuration.nix:298-399` - Current broken system service
  - Niri wiki: "Example systemd Setup" - User service pattern for niri session helpers

  **Acceptance Criteria**:
  - [ ] `systemctl --user status evdev-idle-daemon` shows "Active: active (running)"
  - [ ] `systemctl --user show-environment | grep -E "NIRI_SOCKET|WAYLAND_DISPLAY"` shows both vars
  - [ ] `pgrep -c -f "dd if=/dev/input"` returns ~18 (one per device, no leak)
  - [ ] Manual `niri msg action power-off-monitors` succeeds
  - [ ] After rebuilding, service auto-starts on next login

  **QA Scenarios**:

  Scenario: User service starts and inherits session environment
    Tool: Bash (ssh)
    Preconditions: User logged into Niri session
    Steps:
      1. ssh matt-desktop 'systemctl --user status evdev-idle-daemon 2>&1'
      2. Extract "Active:" line from output
    Expected Result: "Active: active (running)"
    Failure Indicators: "Unit not found" = service didn't register; "failed" = startup error
    Evidence: .sisyphus/evidence/task1-service-active.txt

  Scenario: Session environment has required variables
    Tool: Bash (ssh)
    Preconditions: User logged into Niri session
    Steps:
      1. ssh matt-desktop 'systemctl --user show-environment 2>&1'
      2. grep for "NIRI_SOCKET" and "WAYLAND_DISPLAY"
    Expected Result: Both variables present with values
    Failure Indicators: Empty values = session not fully started; missing = niri-session bug
    Evidence: .sisyphus/evidence/task1-session-env.txt

  Scenario: No leaked dd processes after service restart
    Tool: Bash (ssh)
    Preconditions: Service has been running for at least 30 seconds
    Steps:
      1. Count dd processes: ssh matt-desktop 'pgrep -c -f "dd if=/dev/input" 2>/dev/null || echo 0'
      2. Record count (should be ~18)
    Expected Result: Count is stable, not growing over time
    Failure Indicators: Count > 30 = process leak occurring
    Evidence: .sisyphus/evidence/task1-dd-count.txt

  **Commit**: YES
  - Message: `fix(matt-desktop): convert evdev-idle-daemon to user service`
  - Files: `hosts/matt-desktop/configuration.nix`

---

## Final Verification Wave

- [ ] F1. **Plan Compliance Audit** — Verify all TODOs completed
- [ ] F2. **Idle Detection Functional Test** — Wait ~30 seconds, verify daemon is tracking activity (check /tmp/evdev-idle-activity creation when input detected)
- [ ] F3. **Service Restart Test** — Reboot or restart session, verify service auto-starts
- [ ] F4. **Process Cleanup Verification** — After service restart, verify dd count stays ~18

---

## Success Criteria

### Verification Commands
```bash
# Service should be active
systemctl --user status evdev-idle-daemon
# Expected: "Active: active (running)"

# Session env should have niri socket
systemctl --user show-environment | grep NIRI_SOCKET
# Expected: NIRI_SOCKET=/run/user/1000/niri.wayland-X.sock

# dd count should be stable (~18, not 48)
pgrep -c -f "dd if=/dev/input"
# Expected: ~18

# Manual monitor control should work
NIRI_SOCKET=/run/user/1000/niri.wayland-X.sock niri msg action power-off-monitors
# Expected: monitors turn off, exit code 0
```

### Final Checklist
- [ ] All TODOs complete
- [ ] Service is active and inheriting session environment
- [ ] No process leak (dd count stable)
- [ ] Manual action commands work
- [ ] No "hacky" workarounds - clean systemd architecture
