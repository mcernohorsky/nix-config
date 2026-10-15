{ lib, pkgs, ... }:
let
  mergeJson = lib.getExe (import ../../lib/merge-json.nix { inherit pkgs; });

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

  # Claude writes other preferences to the same file, so /config and the
  # desktop Code view can still edit it.
  settings = {
    autoUpdatesChannel = "latest";
    # Keep learned cross-session context out of coding sessions.
    autoMemoryEnabled = false;
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
    # DISABLE_TELEMETRY would also stop feature-flag fetching, which gates
    # rolled-out features such as idle compaction and the advisor tool.
    env = {
      DISABLE_ERROR_REPORTING = "1";
      DISABLE_FEEDBACK_COMMAND = "1";
      CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL = "1";
      CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS = "1";
      CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
      CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION = "false";
    };
  };

  gitRule = pkgs.writeText "claude-code-vcs-rule.md" ''
    # Version control and pull requests

    Use Jujutsu (jj) in repositories with a .jj directory. Inspect jj status,
    jj diff, and recent descriptions before committing. Follow the repository's
    AGENTS.md for bookmarks and synchronization. In other repositories, use Git.
    Use the repository's configured author and committer. Never add Claude or
    other AI co-author trailers, "Generated with" text, or Claude session links to
    commit messages or pull request descriptions.
  '';
in
{
  home.activation.configureClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${mergeJson} "$HOME/.claude/settings.json" ${lib.escapeShellArg "del(.env.DISABLE_TELEMETRY) * ${builtins.toJSON settings}"}
    # A real file also loads in Cowork, which skips symlinked user rules.
    rule="$HOME/.claude/rules/nix-no-attribution.md"
    ${pkgs.diffutils}/bin/cmp -s ${gitRule} "$rule" || run install -D -m 0600 ${gitRule} "$rule"
  '';
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "configureClaudeCode" ] ''
    run ${lib.getExe bootstrap}
  '';
}
