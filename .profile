# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n
alias dmesgh='dmesg --color=always|less -R'
alias sudo='sudo -E'
alias lls='ls -lA --group-directories-first --color=auto'

export LIBGL_ALWAYS_INDIRECT=true
export NO_AT_BRIDGE=1
export QT_XCB_GL_INTEGRATION=xcb_egl

