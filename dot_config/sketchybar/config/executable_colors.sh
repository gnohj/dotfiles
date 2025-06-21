#!/bin/bash

# Source the colorscheme file
source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

export BLACK=0xff${gnohj_color10#\#}
export WHITE=0xff${gnohj_color14#\#}
export RED=0xff${gnohj_color11#\#}
export GREEN=0xff${gnohj_color02#\#}
export BLUE=0xff${gnohj_color03#\#}
export YELLOW=0xff${gnohj_color12#\#}
export ORANGE=0xff${gnohj_color04#\#}
export MAGENTA=0xff${gnohj_color01#\#}
export GREY=0xff${gnohj_color09#\#}
export TRANSPARENT=0x00000000
export BG0=0xff${gnohj_color10#\#}
export BG0O50=0x80${gnohj_color10#\#}
export BG0O60=0x99${gnohj_color10#\#}
export BG0O70=0xb2${gnohj_color10#\#}
export BG0O80=0xcc${gnohj_color10#\#}
# export BG0O85=0xD91e1e2e
# export BG0O85=0xD9212337
# This sets the color of the bar
# Eldritch dark
export BG0O85=0x55${gnohj_color10#\#}
# Eldritch light
# export BG0O85=0xCF212337
export BG1=0x60${gnohj_color13#\#}
export BG2=0x60${gnohj_color07#\#}

# General bar colors
export BAR_COLOR=$BG0O85
export BAR_BORDER_COLOR=$BG2
export BACKGROUND_1=$BG1
export BACKGROUND_2=$BG2
export ICON_COLOR=$WHITE  # Color of all icons
export LABEL_COLOR=$WHITE # Color of all labels
export POPUP_BACKGROUND_COLOR=$BAR_COLOR
export POPUP_BORDER_COLOR=$WHITE
export SHADOW_COLOR=$BLACK
