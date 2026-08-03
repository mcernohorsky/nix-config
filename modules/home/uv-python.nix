{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.uvPython;
in
{
  options.modules.home.uvPython = {
    enable = lib.mkEnableOption "uv and a uv-managed global Python";

    version = lib.mkOption {
      type = lib.types.str;
      default = "3.14";
      description = ''
        Python version request installed and managed by uv. The pinned uv
        package determines the exact patch release for a minor-version request.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.uv ];

    # This is uv's standard executable directory. It contains the managed
    # python, python3, and versioned Python links created below.
    home.sessionPath = lib.mkBefore [ "$HOME/.local/bin" ];

    # Nushell does not consume Home Manager's POSIX session-variable script.
    # Set its structured PATH directly so `nu` also works when it is launched
    # without an intermediate Bash or Zsh login shell.
    programs.nushell.extraEnv = lib.mkAfter ''
      let uv_python_bin_dir = ($nu.home-dir | path join ".local" "bin")
      let home_profile_bin_dir = "${config.home.profileDirectory}/bin"
      $env.PATH = (
        $env.PATH
        | prepend $home_profile_bin_dir
        | prepend $uv_python_bin_dir
        | uniq
      )
    '';

    home.activation.installUvPython = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export UV_PYTHON_BIN_DIR="$HOME/.local/bin"
      export UV_PYTHON_INSTALL_DIR="${config.xdg.dataHome}/uv/python"
      export PATH="$UV_PYTHON_BIN_DIR:$PATH"
      ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
        # uv uses Apple's install_name_tool to keep managed Python relocatable.
        export PATH="$PATH:/usr/bin"
      ''}

      run ${lib.getExe pkgs.uv} python install ${lib.escapeShellArg cfg.version} \
        --default --preview-features python-install-default
    '';
  };
}
