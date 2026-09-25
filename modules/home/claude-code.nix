{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.claudeCode;

  # Keep Claude's native installation writable so its background updater can
  # replace the binary without a Nix deployment. Only bootstrap it from HM.
  bootstrap = pkgs.writeShellApplication {
    name = "bootstrap-claude-code";
    runtimeInputs = [
      pkgs.bash
      pkgs.curl
    ];
    text = ''
      if [ ! -x "$HOME/.local/bin/claude" ]; then
        curl -fsSL https://claude.ai/install.sh | bash -s latest
      fi
    '';
  };

  desiredSettings = pkgs.writeText "claude-code-settings.json" (
    builtins.toJSON {
      autoUpdatesChannel = "latest";
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
      env = {
        DISABLE_TELEMETRY = "1";
        DISABLE_ERROR_REPORTING = "1";
        DISABLE_FEEDBACK_COMMAND = "1";
        CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL = "1";
        CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS = "1";
        CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
        CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION = "false";
      };
    }
  );

  gitRule = pkgs.writeText "claude-code-git-rule.md" ''
    # Git commits and pull requests

    Before committing, inspect Git status and the repository's recent commit style.
    Use the repository's configured Git author and committer. Never add Claude or
    other AI co-author trailers, "Generated with" text, or Claude session links to
    commit messages or pull request descriptions.
  '';

  configure = pkgs.writeShellApplication {
    name = "configure-claude-code";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      settings_dir="$HOME/.claude"
      settings_file="$settings_dir/settings.json"
      rules_dir="$settings_dir/rules"
      rule_file="$rules_dir/nix-no-attribution.md"

      install -d -m 0700 "$settings_dir" "$rules_dir"

      # Claude writes other preferences here. Merge only our chosen keys into
      # the writable file so /config and the desktop Code view can still edit it.
      settings_temp="$(mktemp "$settings_dir/.settings.json.XXXXXX")"
      trap 'rm -f "$settings_temp"' EXIT
      if [ -e "$settings_file" ]; then
        jq -e 'type == "object"' "$settings_file" >/dev/null
        jq -s '.[0] * .[1]' "$settings_file" ${desiredSettings} >"$settings_temp"
      else
        cp ${desiredSettings} "$settings_temp"
      fi
      if ! cmp -s "$settings_temp" "$settings_file"; then
        chmod 0600 "$settings_temp"
        mv -f "$settings_temp" "$settings_file"
      fi

      # A real file also loads in Cowork, which skips symlinked user rules.
      if ! cmp -s ${gitRule} "$rule_file"; then
        install -m 0600 ${gitRule} "$rule_file"
      fi
    '';
  };
in
{
  options.modules.home.claudeCode.enable = lib.mkEnableOption "Claude Code";

  config = lib.mkIf cfg.enable {
    home.sessionPath = lib.mkAfter [ "$HOME/.local/bin" ];

    # Nushell does not load Home Manager's POSIX session-variable script.
    programs.nushell.extraEnv = lib.mkAfter ''
      let claude_bin_dir = ($nu.home-dir | path join ".local" "bin")
      $env.PATH = (
        $env.PATH
        | prepend $claude_bin_dir
        | uniq
      )
    '';

    home.activation.configureClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe configure}
    '';
    home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "configureClaudeCode" ] ''
      run ${lib.getExe bootstrap}
    '';
  };
}
