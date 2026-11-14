-- Opens the entries.toml sessions marked autostart; run as `rex do` by rex-autostart-sessions.service when the dev-box server starts.
package.path = os.getenv("HOME") .. "/.config/rex/?.lua;" .. package.path
require("entries").autostart()
