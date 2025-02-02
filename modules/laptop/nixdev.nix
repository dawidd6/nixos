{
  pkgs,
  ...
}:
let
  packages = with pkgs; [
    hydra-check
    nix-diff
    nix-init
    nix-inspect
    nix-tree
    nix-update
    nixd
    nixfmt-rfc-style
    nixos-shell
    nixpkgs-review
    nurl
    nvd
  ];
in

{
  environment.systemPackages = packages;
}
