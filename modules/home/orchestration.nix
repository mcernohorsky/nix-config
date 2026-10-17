# The orchestration model-routing skill lives in its own writable repo
# (model-orchestration) so content edits and observation logs need no Nix
# deployment. Only the links into each harness's skill root are declarative,
# so a fresh host cannot be missing the skill.
{ lib, ... }:
{
  home.activation.linkOrchestrationSkill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    skill_src=""
    for repo in "$HOME/code/model-orchestration" "/Volumes/x9-pro/code/model-orchestration"; do
      if [ -d "$repo/skills/orchestration" ]; then
        skill_src="$repo/skills/orchestration"
        break
      fi
    done
    if [ -z "$skill_src" ]; then
      warnEcho "model-orchestration repo not found; skipping orchestration skill links"
    else
      for root in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.config/opencode/skills"; do
        run mkdir -p "$root"
        if [ -L "$root/orchestration" ] && [ "$(readlink "$root/orchestration")" = "$skill_src" ]; then
          :
        elif [ -e "$root/orchestration" ] && [ ! -L "$root/orchestration" ]; then
          warnEcho "$root/orchestration exists and is not a symlink; leaving it alone"
        else
          run ln -sfn "$skill_src" "$root/orchestration"
        fi
      done
    fi
  '';
}
