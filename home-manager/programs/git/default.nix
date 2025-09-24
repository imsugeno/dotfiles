{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "imsugeno";
    userEmail = "g.tokyo.kazusa@gmail.com";

    extraConfig = {
      init.defaultBranch = "main";

      ghq.root = "~/repos";

      pull.rebase = false;

      core = {
        editor = "vim";
        autocrlf = "input";
      };

      push = {
        default = "current";
        autoSetupRemote = true;
      };

      color.ui = true;

      diff.colorMoved = "default";

      merge.conflictStyle = "diff3";
    };

    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      ci = "commit";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      lo = "log --oneline";
      unstage = "reset HEAD --";
      last = "log -1 HEAD";
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".idea/"
      ".vscode/"
      "node_modules/"
      ".env"
      ".env.local"
      ".serena"
      ".claude/settings.local.json"
    ];
  };
}