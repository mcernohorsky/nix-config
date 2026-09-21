{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.zed;
in
{
  options.modules.home.zed.enable = lib.mkEnableOption "Zed editor";

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;

      # Extensions auto-install via `auto_install_extensions`. Language
      # servers stay external: `path_lookup` finds nixd from the profile
      # (Mac, shell-launched) or the wrapper PATH (Linux, extraPackages).
      extensions = [
        "nix"
        "toml"
      ];

      userSettings = {
        # Helix-style modal bindings (implies vim_mode; still WIP upstream).
        helix_mode = true;
        theme = {
          mode = "system";
          light = "Gruvbox Light";
          dark = "Gruvbox Dark Hard";
        };
        buffer_font_family = "NordwandMono Nerd Font Mono";
        # Terminal inherits the buffer font when `font_family` is unset,
        # so only the shell needs pinning (Nushell, matching Ghostty).
        terminal = {
          shell = {
            program = lib.getExe pkgs.nushell;
          };
        };
        telemetry = {
          metrics = false;
          diagnostics = false;
        };
        lsp = {
          # The extension tries `nil` first, which isn't installed. Use
          # nixd (the repo standard) via absolute path so it resolves
          # even for Finder-launched Zed, which lacks the Nix PATH.
          nixd = {
            binary = {
              path = lib.getExe pkgs.nixd;
            };
          };
        };
        languages = {
          Nix = {
            language_servers = [
              "nixd"
              "!nil"
            ];
          };
        };
        # NOTE: `auto_update` is set per host, not here. Mac installs via
        # the Homebrew cask (which defers to the app's own updater), while
        # Linux installs from nixpkgs (store must stay source of truth).
      };
    };
  };
}
