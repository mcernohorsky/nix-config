# Draft: OpenCode Shared Setup

## Requirements (confirmed)
- Factor the current OpenCode setup out of the macbook-specific Nix configuration so it can be reused on `matt-desktop`.
- Plan for eventual access to the desktop-hosted OpenCode UI over Tailscale from an iPhone.
- Evaluate whether to keep using the current OpenCode UI/Portal path or switch to a better mobile-friendly UI/native app.
- Maximize search effort before narrowing the implementation plan.
- Keep the initial UI target simple by using the default OpenCode web UI first.
- Add a later follow-up TODO to evaluate alternative UIs/clients after the initial shared setup is complete.
- Include adding the `opencode-desktop` macOS app to the macbook's Homebrew-managed config as part of planned work rather than immediate implementation.

## Technical Decisions
- Intent classified as architecture + refactor with research-heavy discovery.
- Initial approach is to map current OpenCode config, identify shared vs host-specific boundaries, and compare remote access/UI options before locking a target architecture.
- Preliminary decomposition candidate:
  - shared HM module for OpenCode core config and plugin/version wiring
  - shared Portal module with per-OS service backend and per-host overrides
  - host-specific Tailscale exposure kept separate initially, then normalized later
- Preliminary hosting recommendation leans toward `matt-desktop` for always-on access, with tighter ACL review before exposing a UI there.
- Strong architecture recommendation from review: extract shared OpenCode core first; keep service management and Tailscale exposure as separate host adapters instead of building one large cross-platform stack module immediately.
- Security guardrail direction: keep the coding UI bound to localhost and expose it only through Tailscale Serve; avoid direct LAN/public exposure and avoid broad trusted-user assumptions.
- Canonical OpenCode model policy must live in the shared module once extraction is active: `small_model` remains `opencode-go/minimax-m2.5`, direct Kimi lanes should use Fireworks-native IDs, and `opencode-go/kimi-k2.5` is only a deliberate fallback for selected agents/categories.
- Current repo state has already crossed the extraction threshold: both hosts now consume `modules/home/opencode-core.nix`, so the next practical checkpoint is deploying the macbook config and validating agent usability there before resuming the unfinished desktop-service tasks.

## Research Findings
- Repository already contains a macbook-specific Portal/OpenCode module at `hosts/macbook-pro-m2/modules/portal.nix`.
- OpenCode home-manager configuration currently appears to live under `hosts/macbook-pro-m2/home/home.nix` plus `hosts/macbook-pro-m2/home/opencode-plugins.json`.
- Tailscale configuration exists for both macOS and Linux hosts, plus repo-level ACL policy in `tailscale-acl.json`.
- `flake.nix` wires `hosts/macbook-pro-m2/home/home.nix` only into the Darwin host, while `hosts/matt-desktop/home.nix` is separate, so OpenCode is not yet modeled as a shared home-manager module.
- The current macbook setup splits responsibilities across three layers: `home/home.nix` for OpenCode config/plugins, `modules/portal.nix` for the Portal package + launch agent, and `configuration.nix` for `tailscale up --ssh` plus `tailscale serve`.
- `matt-desktop` already runs Tailscale with `--ssh` and trusted tagging, but has no OpenCode/Portal config yet.
- Existing repo comments and commands already frame Portal as the current mobile-first UI path, including `just` recipes for `portal-status`, `portal-logs`, and `portal-reset-serve`.
- Tailscale ACLs currently allow `autogroup:member` and `tag:trusted` to access everything, which likely means phone access to a served desktop UI would already be allowed once the service exists.
- The current Portal module has portability blockers: hardcoded `/Users/matt`, launchd-only service wiring, and a `tailscaleServe` option that is declared but not actually used.
- `matt-desktop` already exposes some tailnet-scoped services and is the most natural always-on host, but it also has a wider service blast radius than the macbook.
- Current remote-access security depends heavily on Tailscale identity and ACL enforcement; app-layer auth for the Portal path is not yet evidenced in repo config.
- External docs support Tailscale Serve for private tailnet-only HTTPS exposure and recommend localhost binding when relying on Tailscale identity headers.
- OpenPortal docs explicitly position Portal as a mobile-first OpenCode UI and note VPN/Tailscale as a normal remote-access path.
- External ecosystem research suggests a reasonable fallback ladder: preserve current Portal path for lowest migration cost, or switch later to official `opencode web` / another client if mobile UX is insufficient.
- Refactor drift already surfaced one concrete failure mode to guard against: once `modules/home/opencode-core.nix` existed, the macbook still kept an inline OpenCode config block and stale model chains, which caused the live config to diverge from the extracted module.
- Fireworks-native Kimi naming is not interchangeable with OpenRouter naming: the shared config should target `fireworks/accounts/fireworks/models/kimi-k2p5` for direct Fireworks usage rather than `openrouter/moonshotai/kimi-k2.5`.
- Fireworks provider wiring is also shape-sensitive in OpenCode: the adapter must be declared at the provider level with OpenAI-compatible `npm` metadata and provider-level `options.baseURL`, otherwise subagents can fail at runtime with `undefined/chat/completions` despite clean evaluation output.
- The immediate next-phase workflow is intentionally staged: stabilize and deploy the macbook shared-config path first, then continue the remaining desktop-app, web-service, Tailscale Serve, and remote-access tasks from that working baseline.

## Open Questions
- Should the reusable OpenCode layer target both macOS and Linux from day one, or only factor out shared config now and add desktop enablement later?
- Is the goal for the always-on UI to run on `matt-desktop`, `macbook-pro-m2`, or both depending on availability?
- Is browser-based phone access sufficient, or is a native/mobile-optimized client a hard requirement?
- Should the shared module include only OpenCode core config/plugins, or also include the Portal service abstraction and Tailscale exposure knobs?
- How much automated verification should the eventual implementation include for this refactor/config work?

## Test Strategy Decision
- **Infrastructure exists**: Limited. No obvious repo-wide automated test harness or CI workflows for this Nix config; only flake deploy checks are present.
- **Automated tests**: Likely tests-after or none for config refactor work unless new validation steps are added.
- **Agent-Executed QA**: Will be required in the eventual plan via `nix`/`darwin-rebuild`/service-status/Tailscale verification scenarios.

## Scope Boundaries
- INCLUDE: shared Nix structure, host-specific boundaries, Tailscale exposure strategy, mobile-access options, plan for future desktop hosting.
- INCLUDE: removal of shared-vs-host OpenCode config drift and explicit model-policy normalization while the extraction is still in progress.
- EXCLUDE: direct implementation during this planning phase.
