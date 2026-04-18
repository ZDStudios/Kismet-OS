export EDITOR=nvim
export VISUAL=nvim
export KISMET_OS=1

if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

alias ll='ls -lah'
alias gs='git status'
alias kismet-status='cat ~/.config/kismet/kismet.conf 2>/dev/null || true'
