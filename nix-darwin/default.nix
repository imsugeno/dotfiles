{ pkgs, username, ... }: {

  # darwin-rebuild を実行するプライマリユーザー
  system.primaryUser = username;

  # ⚠️ Determinate Nixとの競合を回避
  nix.enable = false;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Used for backwards compatibility
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Homebrew
  homebrew = {
    enable = true;
    onActivation = {
      # 宣言されていないパッケージを自動削除しない（既存のbrewパッケージを保護）
      cleanup = "none";
    };
    taps = [
      "homebrew/cask-fonts"
    ];
    brews = [
      "gh"
      "ghq"
      "git"
      "go-jsonnet"
      "jq"
      "go"
      "kotlin"
      "mise"
      "ni"
      "peco"
      "qrencode"
      "starship"
      "terraform"
      "tmux"
      "tree"
      "wget"
    ];
    casks = [
      "arc"
      "bettertouchtool"
      "brave-browser"
      "chromedriver"
      "claude-code"
      "cursor"
      "discord"
      "docker-desktop"
      "figma"
      "font-hack-nerd-font"
      "google-chrome"
      "iterm2"
      "karabiner-elements"
      "raycast"
      "scroll-reverser"
      "sequel-ace"
      "slack"
      "spotify"
    ];
  };
}