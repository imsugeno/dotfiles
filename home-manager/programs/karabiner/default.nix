{ config, dotfilesPath, ... }:
{
  # Karabiner-Elements configuration management
  # 外付けキーボード用のキーマッピング設定を管理

  xdg.configFile."karabiner/karabiner.json" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${dotfilesPath}/home-manager/programs/karabiner/karabiner.json";
  };
}
