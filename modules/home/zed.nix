# The Mac uses Zed's Homebrew cask and self-updater; Linux uses nixpkgs.
{ lib, pkgs, ... }:
let
  mono = import ../../lib/mono-font.nix { inherit pkgs; };
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  programs.zed-editor = {
    enable = true;
    package = lib.mkIf isDarwin null;
    extensions = [
      "nix"
      "toml"
    ];
    userSettings = {
      auto_update = isDarwin;
      helix_mode = true;
      theme = {
        mode = "system";
        light = "Gruvbox Light";
        dark = "Gruvbox Dark Hard";
      };
      buffer_font_family = mono.family;
      # The integrated terminal is cell-strict, so it gets the Term variant.
      terminal = {
        font_family = mono.term.family;
        shell.program = lib.getExe pkgs.nushell;
      };
      telemetry = {
        metrics = false;
        diagnostics = false;
      };
      # Absolute path so Finder-launched Zed finds nixd; skip the default nil.
      lsp.nixd.binary.path = lib.getExe pkgs.nixd;
      languages.Nix.language_servers = [
        "nixd"
        "!nil"
      ];
    };
  };
}
