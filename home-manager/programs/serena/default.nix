{
  config,
  pkgs,
  lib,
  homeDirectory,
  ghqRoot,
  ...
}:
let
  yamlFormat = pkgs.formats.yaml { };
  # ~/.config/serena/projects.nix から読み込む（Git 管理外）
  projectsFile = "${homeDirectory}/.config/serena/projects.nix";
  allProjects = if builtins.pathExists projectsFile then import projectsFile else [];
  # Serena を無効化するプロジェクトのパス（ghqRoot 配下の相対パスで指定）
  excludedProjects = map (p: "${ghqRoot}/${p}") [
    "github.com/imsugeno/dotfiles"
  ];
  projects = builtins.filter (p: !builtins.elem p excludedProjects) allProjects;
  serenaConfig = {
    gui_log_window = false;
    web_dashboard = true;
    web_dashboard_open_on_launch = false;
    log_level = 20;
    trace_lsp_communication = false;
    tool_timeout = 240;
    excluded_tools = [ ];
    included_optional_tools = [ ];
    jetbrains = false;
    record_tool_usage_stats = false;
    token_count_estimator = "TIKTOKEN_GPT4O";
    inherit projects;
  };
in
{
  # Serena は設定ファイルに書き込むため、Nix store への symlink ではなく
  # activation script でコピーして書き込み可能にする
  home.activation.serenaConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.serena"
    cp -f ${yamlFormat.generate "serena_config.yml" serenaConfig} "$HOME/.serena/serena_config.yml"
    chmod 644 "$HOME/.serena/serena_config.yml"
  '';
}
