{ pkgs }:
{
  # Standard spacing for editors, UI, and the system fallback.
  family = "IoskeleyMono Nerd Font Mono";
  package = pkgs.ioskeley-mono.nf;

  # Narrower arrows and box drawing for cell-strict terminals (Ghostty, Zed's terminal).
  term = {
    family = "IoskeleyMonoTerm Nerd Font Mono";
    package = pkgs.ioskeley-mono.term-nf;
  };
}
