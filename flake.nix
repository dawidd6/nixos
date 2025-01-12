{
  nixConfig = {
    extra-substituters = [ "https://dawidd6.cachix.org" ];
    extra-trusted-public-keys = [ "dawidd6.cachix.org-1:dvy2Br48mAee39Yit5P+jLLIUR3gOa1ts4w4DTJw+XQ=" ];
  };

  inputs = {
    hardware.url = "github:nixos/nixos-hardware";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-24.11";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.nuschtosSearch.follows = "";
      inputs.devshell.follows = "";
      inputs.flake-compat.follows = "";
      inputs.git-hooks.follows = "";
      inputs.home-manager.follows = "";
      inputs.nix-darwin.follows = "";
      inputs.treefmt-nix.follows = "";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.self) outputs;
      inherit (inputs.nixpkgs) lib;
      forAllSystems = function: lib.genAttrs lib.systems.flakeExposed function;
      forAllPkgs = input: function: forAllSystems (system: function (import input { inherit system; }));
      userName = "dawidd6";
      specialArgs = {
        inherit inputs outputs userName;
      };
    in
    {
      inherit lib;

      overlays.default = final: prev: {
        # https://github.com/NixOS/nixpkgs/pull/173364
        ansible = prev.ansible.overrideAttrs (oldAttrs: {
          propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [ final.python3Packages.jmespath ];
        });
      };

      nixosConfigurations = {
        coruscant = inputs.nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/_common/core.nix
            ./hosts/_common/desktop.nix
            ./hosts/coruscant/configuration.nix
            ./hosts/coruscant/disko-config.nix
            ./hosts/coruscant/hardware-configuration.nix
            inputs.hardware.nixosModules.lenovo-thinkpad-t14-amd-gen1
            inputs.disko.nixosModules.default
            inputs.home-manager.nixosModules.default
            {
              home-manager = {
                users.${userName} = { };
                sharedModules = [
                  ./users/_common/core.nix
                  inputs.nix-index-database.hmModules.nix-index
                  inputs.nixvim.homeManagerModules.nixvim
                ];
                extraSpecialArgs = specialArgs;
                useUserPackages = true;
                useGlobalPkgs = true;
              };
            }
          ];
          specialArgs = specialArgs // {
            hostName = "coruscant";
          };
        };
        hoth = inputs.nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/_common/core.nix
            ./hosts/hoth/configuration.nix
            ./hosts/hoth/disko-config.nix
            ./hosts/hoth/hardware-configuration.nix
            inputs.disko.nixosModules.default
          ];
          specialArgs = specialArgs // {
            hostName = "hoth";
          };
        };
        yavin = inputs.nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/_common/core.nix
            ./hosts/yavin/configuration.nix
            ./hosts/yavin/hardware-configuration.nix
            inputs.hardware.nixosModules.common-cpu-intel
          ];
          specialArgs = specialArgs // {
            hostName = "yavin";
          };
        };
      };

      homeConfigurations = {
        dawid = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            ./users/_common/core.nix
            ./users/dawid/home.nix
            inputs.nix-index-database.hmModules.nix-index
            inputs.nixvim.homeManagerModules.nixvim
          ];
          extraSpecialArgs = specialArgs // {
            userName = "dawid";
          };
        };
      };

      checks = forAllSystems (
        system:
        let
          nixosTops = lib.mapAttrs (_: c: c.config.system.build.toplevel) outputs.nixosConfigurations;
          homeTops = lib.mapAttrs (_: c: c.activationPackage) outputs.homeConfigurations;
          allTops = nixosTops // homeTops;
        in
        allTops
        // {
          pre-commit = inputs.pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks.treefmt.enable = true;
            hooks.treefmt.package = outputs.formatter.${system};
          };
        }
      );

      devShells = forAllPkgs inputs.nixpkgs-unstable (pkgs: {
        default = pkgs.mkShellNoCC {
          NIX_CONFIG = "experimental-features = nix-command flakes";
          shellHook = ''
            ${outputs.checks.${pkgs.system}.pre-commit.shellHook}
          '';
        };
      });

      formatter = forAllPkgs inputs.nixpkgs-unstable (
        pkgs:
        inputs.treefmt.lib.mkWrapper pkgs {
          projectRootFile = "flake.nix";
          programs.deadnix.enable = true;
          programs.nixfmt.enable = true;
          programs.statix.enable = true;
          settings.on-unmatched = "info";
        }
      );

      packages = forAllPkgs inputs.nixpkgs (pkgs: {
        scripts = pkgs.runCommandNoCCLocal "scripts" { } ''
          mkdir -p $out
          cp -R ${./scripts} $out/bin
        '';
      });
    };
}
