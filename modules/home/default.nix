# Home Manager configuration shared by the Mac and the Linux desktop.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  mono = import ../../lib/mono-font.nix { inherit pkgs; };

  # Writable, self-updating tool installs (uv Python, Claude Code,
  # T3 Code, and Bun globals) live outside the Nix store.
  userBinDirs = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];
in
{
  imports = [
    ./claude-code.nix
    ./codex-cli.nix
    ./dev-templates.nix
    ./just.nix
    ./opencode.nix
    ./t3code.nix
    ./tailscale-policy.nix
    ./uv-python.nix
    ./zed.nix
  ];

  home.sessionPath = userBinDirs;
  home.shellAliases = {
    vi = "hx";
    vim = "hx";
    js = "jj status";
    jd = "jj diff";
    jl = "jj log";
    jc = "jj commit";
    jf = "jj git fetch";
    jp = "jj git push --bookmark main";
  };

  # Interactive non-login bash (notably over SSH) never sources
  # hm-session-vars.sh, where sessionPath lives.
  programs.bash = {
    enable = true;
    initExtra = ''
      for dir in ${lib.concatMapStringsSep " " (dir: ''"${dir}"'') (lib.reverseList userBinDirs)}; do
        case ":$PATH:" in
          *":$dir:"*) ;;
          *) PATH="$dir''${PATH:+:}$PATH" ;;
        esac
      done
    '';
  };

  # Nushell does not read hm-session-vars.sh.
  programs.nushell = {
    enable = true;
    settings.show_banner = false;
    environmentVariables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };
    extraEnv = lib.mkAfter ''
      $env.PATH = (
        $env.PATH
        | prepend [
          ($nu.home-dir | path join ".local" "bin")
          "${config.home.profileDirectory}/bin"
          ($nu.home-dir | path join ".bun" "bin")
        ]
        | uniq
      )
    '';
  };

  programs.ghostty.settings = {
    command = lib.getExe pkgs.nushell;
    theme = "light:Gruvbox Light,dark:Gruvbox Dark Hard";
    font-family = [
      mono.term.family
      "Noto Color Emoji"
    ];
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Matt Cernohorsky";
      user.email = "matt@cernohorsky.ca";
      github.user = "mcernohorsky";
      init.defaultBranch = "main";
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Matt Cernohorsky";
        email = "matt@cernohorsky.ca";
      };
      ui = {
        default-command = "status";
        editor = "hx";
      };
      git.colocate = true;
      aliases = {
        st = [ "status" ];
        d = [ "diff" ];
        l = [ "log" ];
      };
    };
  };

  programs.bat.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.fzf.enable = true;
  programs.ripgrep.enable = true;
  programs.starship.enable = true;
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };
  programs.zoxide.enable = true;

  home.packages = with pkgs; [
    gh
    nodejs # `node` for Node-targeted CLIs and language servers
    runebender
  ];

  programs.home-manager.enable = true;
  manual = {
    manpages.enable = false;
    html.enable = false;
    json.enable = false;
  };
}
