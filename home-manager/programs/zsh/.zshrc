# Git
source ~/.zsh/git-prompt.sh
fpath=(~/.zsh $fpath)
zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash

# Kotlinc completion
autoload -Uz compinit && compinit -u

# ghq + peco function for quick directory navigation
function peco-src () {
  local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

# Additional PATH configurations
export PATH="/opt/homebrew/bin:$PATH"
PATH=~/.console-ninja/.bin:$PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
# Rust toolchain (rustup is keg-only; toolchain shims live in ~/.cargo/bin)
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Enable colors for ls
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Claude configuration
export CLAUDE_CONFIG_DIR="$HOME/.config/claude"

# mise
eval "$(mise activate zsh)"

# zsh-autosuggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# kubectl completion
source <(kubectl completion zsh)  # 現在のzshシェルにコマンド補完を設定します
echo "[[ $commands[kubectl] ]] && source <(kubectl completion zsh)" >> ~/.zshrc # zshシェルでのコマンド補完を永続化するために.zshrcに追記します。