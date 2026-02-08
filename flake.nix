{
  description = "imsugeno's dotfiles and nix-darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, ... }:
  let
    system = "aarch64-darwin";

    # マシン設定
    machines = {
      imsugeno = {
        username = "elmo";
        hostname = "imsugeno";
        dotfilesPath = "/Users/elmo/repos/github.com/imsugeno/dotfiles";
        gitConfig = {
          userName = "imsugeno";
          userEmail = "g.tokyo.kazusa@gmail.com";
        };
      };
      kazusa-sugeno = {
        username = "canly";
        hostname = "kazusa-sugeno";
        dotfilesPath = "/Users/canly/src/github.com/imsugeno/dotfiles";
        gitConfig = {
          userName = "imsugeno";
          userEmail = "g.tokyo.kazusa@gmail.com";
        };
      };
    };

    # darwinConfiguration生成
    mkDarwinConfig = name: { username, hostname, dotfilesPath, gitConfig }:
      let
        homeDirectory = "/Users/${username}";
      in
      nix-darwin.lib.darwinSystem {
        inherit system;

        # nix-darwin モジュールで利用可能
        specialArgs = {
          inherit username hostname;
        };

        modules = [
          ./nix-darwin/default.nix

          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";

            # home-manager モジュールで利用可能
            home-manager.extraSpecialArgs = {
              inherit username homeDirectory dotfilesPath gitConfig;
            };

            home-manager.users."${username}" = import ./home-manager/home.nix;
          }
        ];
      };
  in
  {
    darwinConfigurations = builtins.mapAttrs mkDarwinConfig machines;
  };
}