{ pkgs, ... }:
{
  home.sessionVariables = {
    ELECTRON_TRASH = "gvfs-trash";
    # TODO: remove this workaround
    __HM_SESS_VARS_SOURCED = "";
  };

  programs.carapace.enable = true;
  programs.carapace.enableFishIntegration = false;

  programs.fish = {
    enable = true;
    generateCompletions = false;
    shellAliases = {
      rm = "trash";
      ssh = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
      hub = "gh";
    };
    shellAbbrs = {
      e = "exit";
      g = "git";
      ga = "git add";
      gc = "git commit -m";
      gca = "git commit --amend --no-edit";
      gcae = "git commit --amend --edit";
      gs = "git status -u";
      gt = "git tag";
      gd = "git diff";
      gdc = "git diff --cached";
      gh = "git checkout";
      gb = "git branch -a";
      gf = "git fetch";
      gp = "git push";
      gfo = "git fetch origin";
      gpo = "git push origin -u";
      clip = "xsel --clipboard";
      mic-test = "arecord -f cd - | aplay -";
      p = "podman";
    };
    interactiveShellInit = ''
      set fish_color_command green
      set fish_color_param normal
      set fish_color_error red --bold
      set fish_color_normal normal
      set fish_color_comment brblack
      set fish_color_quote yellow

      # TODO: use module when it's ready
      ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
    '';
  };

  # TODO: contribute this upstream?
  xdg.configFile =
    let
      commands = [
        "nix-build"
        "nix-instantiate"
        "nix-shell"
        "nixos-rebuild"
      ];
      genAttr = cmd: {
        name = "fish/completions/${cmd}.fish";
        value.source = pkgs.runCommand "${cmd}-fish-completion" { } ''
          ${pkgs.carapace}/bin/carapace ${cmd} fish > $out
          if [ ! -s $out ]; then
            echo "'${cmd}' not recognized by carapace!"
            exit 1
          fi
        '';
      };
    in
    builtins.listToAttrs (builtins.map genAttr commands);
}
