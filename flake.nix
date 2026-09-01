{
  description = "imsugeno's dotfiles and nix-darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, ... }:
  let
    system = "aarch64-darwin";

    getEnv = name:
      let value = builtins.getEnv name;
      in if value == ""
         then throw "${name} is required. Use make switch/check or pass it with --impure."
         else value;

    username = getEnv "DOTFILES_USER";
    homeDirectory = "/Users/${username}";
    dotfilesPath = "${homeDirectory}/repos/github.com/imsugeno/dotfiles";
    gitConfig = {
      userName = "imsugeno";
      userEmail = "g.tokyo.kazusa@gmail.com";
    };

    # darwinConfiguration生成
    mkDarwinConfig =
      nix-darwin.lib.darwinSystem {
        inherit system;

        # nix-darwin モジュールで利用可能
        specialArgs = {
          inherit username;
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
    darwinConfigurations.current = mkDarwinConfig;
  };
}
