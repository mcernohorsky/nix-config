# A writable Bun-global install lets T3 Code detect and update the CLI.
{ lib, pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  configure = pkgs.writeShellApplication {
    name = "configure-codex-memory";
    runtimeInputs = [ python ];
    text = ''
      python3 - <<'PY'
      import os
      import pathlib
      import tempfile
      import tomlkit

      path = pathlib.Path.home() / ".codex" / "config.toml"
      path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
      original = path.read_text() if path.exists() else ""
      config = tomlkit.parse(original)
      # Preserve writable app preferences while disabling both memory paths.
      for section, values in {
          "features": {"memories": False},
          "memories": {"generate_memories": False, "use_memories": False},
      }.items():
          if section not in config:
              config[section] = tomlkit.table()
          config[section].update(values)
      updated = tomlkit.dumps(config)
      if updated != original:
          fd, temporary = tempfile.mkstemp(prefix=".config.toml.", dir=path.parent)
          try:
              with os.fdopen(fd, "w") as output:
                  output.write(updated)
              os.replace(temporary, path)
          finally:
              if os.path.exists(temporary):
                  os.unlink(temporary)
      PY
    '';
  };
in
{
  home.activation.configureCodexMemory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe configure}
  '';
  home.activation.installCodexCli = lib.hm.dag.entryAfter [ "installOpenCode" ] ''
    if [ ! -x "$HOME/.bun/bin/codex" ]; then
      run env BUN_INSTALL="$HOME/.bun" ${lib.getExe pkgs.bun} install -g @openai/codex
    fi
  '';
}
