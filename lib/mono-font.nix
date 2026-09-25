{ pkgs }:
{
  # Standard spacing for editors / UI / system fallback.
  # NOTE: nixpkgs v2.0.0 names lack upstream's newer " Mono" suffix
  # (upstream now documents "IoskeleyMono Nerd Font Mono"); verify with
  # fontTools nameID 1 before renaming.
  family = "IoskeleyMono Nerd Font";
  package = pkgs.ioskeley-mono.normal-NF;

  # Terminal spacing for cell-strict emulators (Ghostty, Zed integrated
  # terminal). Narrower arrows / box drawing; same visual system.
  term = {
    family = "IoskeleyMonoTerm Nerd Font";
    package = pkgs.ioskeley-mono.normal-term-NF;
  };
}
