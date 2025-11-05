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
PATH=~/.console-ninja/.bin:$PATH
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# Claude configuration
export CLAUDE_CONFIG_DIR="$HOME/.config/claude"

# mise
eval "$(mise activate zsh)"