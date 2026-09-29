# uv-managed global Python in uv's standard ~/.local/bin.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.uv ];

  home.activation.installUvPython = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export UV_PYTHON_BIN_DIR="$HOME/.local/bin"
    export UV_PYTHON_INSTALL_DIR="${config.xdg.dataHome}/uv/python"
    export PATH="$UV_PYTHON_BIN_DIR:$PATH"
    ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      # uv uses Apple's install_name_tool to keep managed Python relocatable.
      export PATH="$PATH:/usr/bin"
    ''}
    run ${lib.getExe pkgs.uv} python install 3.14 --default --preview-features python-install-default
  '';
}
