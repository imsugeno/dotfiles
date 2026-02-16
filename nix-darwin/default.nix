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

  # ─── macOS システム設定 ───

  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleInterfaceStyle = "Dark";
      # キーリピート（値が小さいほど速い）
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };

    # NSGlobalDomain の型付きオプションに無い設定は CustomUserPreferences で管理
    CustomUserPreferences = {
      NSGlobalDomain = {
        # カーソル移動速度
        "com.apple.trackpad.scaling" = 2.5;
        "com.apple.mouse.scaling" = 2;
      };
      # パスワードとパスキーを自動入力をオフ
      "com.apple.Passwords" = {
        AutoFillPasswords = false;
      };
    };

    finder = {
      # リスト表示をデフォルトに
      FXPreferredViewStyle = "Nlsv";
    };

    dock = {
      autohide = true;
      tilesize = 51;
      orientation = "bottom";
      mineffect = "genie";
      show-recents = false;
      persistent-apps = [
        "/System/Applications/App Store.app"
        "/System/Applications/Reminders.app"
        "/System/Applications/Notes.app"
        "/System/Applications/System Settings.app"
        "/Applications/iTerm.app"
        "/Applications/Arc.app"
      ];
    };

    WindowManager = {
      # デスクトップクリックでウィンドウを退避しない
      EnableStandardClickToShowDesktop = false;
    };
  };

  # ─── sudo Touch ID ───

  security.pam.services.sudo_local.touchIdAuth = true;

  # ─── Activation Scripts ───

  system.activationScripts.postActivation.text = ''
    # 未署名 cask の quarantine 属性を除去
    if [ -d "/Applications/Arto.app" ]; then
      xattr -dr com.apple.quarantine /Applications/Arto.app 2>/dev/null || true
    fi
  '';

  # ─── Homebrew ───

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
    };
    taps = [
      "arto-app/tap"
    ];
    brews = [
      "curl"
      "eza"
      "fd"
      "fzf"
      "gh"
      "ghq"
      "git"
      "go-jsonnet"
      "graphviz"
      "jq"
      "mise"
      "ni"
      "peco"
      "qrencode"
      "starship"
      "tfenv"
      "tmux"
      "tree"
      "wget"
      "zsh-autosuggestions"
      "zsh-syntax-highlighting"
      "awscli"
      "gemini-cli"
    ];
    casks = [
      "1password"
      "arto-app/tap/arto"
      "arc"
      "bettertouchtool"
      "brave-browser"
      "chromedriver"
      "claude-code"
      "discord"
      "docker-desktop"
      "figma"
      "font-hack-nerd-font"
      "google-chrome"
      "iterm2"
      "karabiner-elements"
      "mac-mouse-fix"
      "notion"
      "raycast"
      "scroll-reverser"
      "sequel-ace"
      "slack"
      "spotify"
      "visual-studio-code"
    ];
    masApps = {
      "Kindle" = 302584613;
    };
  };
}