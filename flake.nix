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
    username = "elmo";
    homeDirectory = "/Users/${username}";
    hostname = "imsugeno";
    system = "aarch64-darwin";
  in
  {
    darwinConfigurations."${hostname}" = nix-darwin.lib.darwinSystem {
      inherit system;

      specialArgs = { inherit username; };

      modules = [
        ./nix-darwin/default.nix

        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users."${username}" = import ./home-manager/home.nix {
            inherit (nixpkgs) config lib;
            inherit username homeDirectory;
            pkgs = import nixpkgs { inherit system; };
          };
        }
      ];
    };
  };
}