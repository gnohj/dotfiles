{ config, ... }:

# The afk script toggles lid-closed sleep and low power mode without a password prompt.

{
  security.sudo.extraConfig = ''
    ${config.system.primaryUser} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a powermode 0, /usr/bin/pmset -a powermode 1, /usr/bin/pmset -a powermode 2
  '';
}
