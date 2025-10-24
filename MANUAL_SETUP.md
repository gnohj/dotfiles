# macOS Manual Setup Guide

This document covers macOS settings that **cannot be automated** through nix-darwin due to TCC (Transparency, Consent, and Control) security restrictions or lack of API support.

## Table of Contents

- [Why These Cannot Be Automated](#why-these-cannot-be-automated)
- [Privacy & Security Permissions (TCC)](#privacy--security-permissions-tcc)
  - [Accessibility](#accessibility)
  - [Full Disk Access](#full-disk-access)
  - [Screen Recording](#screen-recording)
  - [Automation](#automation)
  - [App Management](#app-management)
  - [Files and Folders](#files-and-folders)
- [Trackpad Gestures](#trackpad-gestures)
- [Lock Screen UI](#lock-screen-ui)
- [Touch ID](#touch-id)
- [Other Settings](#other-settings)

---

## Why These Cannot Be Automated

### TCC (Privacy & Security) Permissions

**Cannot be scripted** because:
- Apple's security design requires user consent
- TCC database is protected by SIP (System Integrity Protection)
- No supported macOS API for programmatic permission grants
- `tccutil` only supports `reset` (removing), not granting permissions

**The ONLY automation path**: MDM (Mobile Device Management) with PPPC profiles in enterprise environments

### Gesture Settings

**Cannot be scripted** because:
- Not exposed through `defaults` API
- No nix-darwin module support
- Stored in complex preference domains

---

## Privacy & Security Permissions (TCC)

**Location**: System Settings → Privacy & Security

### Accessibility

**Path**: System Settings → Privacy & Security → Accessibility

These apps need to control your computer:

- ✅ AEServer
- ✅ AeroSpace (window management)
- ✅ BetterDisplay (display management)
- ✅ borders (4 instances - window decoration)
- ✅ Flameshot (screenshot tool)
- ✅ Ghostty (terminal emulator)
- ✅ Homerow (keyboard navigation)
- ✅ kanata (keyboard remapper)
- ✅ karabiner_cli (Karabiner Elements)
- ✅ kitty (terminal emulator)
- ✅ Logi Options+ (Logitech device manager)
- ✅ LogiPluginService (Logitech plugin)
- ✅ Mouseless (mouse-free navigation)
- ✅ Raycast (launcher/productivity)
- ✅ sketchybar (status bar)
- ✅ skhd (hotkey daemon)
- ✅ WezTerm (terminal emulator)

**How to grant**:
1. Open System Settings → Privacy & Security → Accessibility
2. Click the lock icon and authenticate
3. Click the "+" button
4. Navigate to the app location (usually `/Applications` or `/usr/local/bin`)
5. Select the app and click "Open"
6. Toggle the switch to enable

---

### Full Disk Access

**Path**: System Settings → Privacy & Security → Full Disk Access

Terminal emulators need this for shell integration and file system operations:

- ✅ Ghostty
- ✅ kitty
- ✅ WezTerm

**How to grant**:
1. Open System Settings → Privacy & Security → Full Disk Access
2. Click the lock icon and authenticate
3. Click the "+" button
4. Navigate to `/Applications`
5. Select the terminal app and click "Open"
6. Toggle the switch to enable

---

### Screen Recording

**Path**: System Settings → Privacy & Security → Screen Recording

These apps need to capture screen content:

- ✅ iStat Menus (system monitor)
- ✅ Raycast (screenshot and screen capture features)

**How to grant**:
1. Open System Settings → Privacy & Security → Screen Recording
2. Click the lock icon and authenticate
3. Click the "+" button
4. Navigate to the app location
5. Select the app and click "Open"
6. Toggle the switch to enable

---

### Automation

**Path**: System Settings → Privacy & Security → Automation

Apps that need to control other applications:

#### AeroSpace
- ✅ Spotify (window management with music integration)

#### Ghostty
- ✅ Brave Browser
- ✅ Google Chrome
- ✅ Spotify
- ✅ System Events

#### kitty
- ✅ System Events

#### Only Switch
- ✅ System Events

#### osascript
- ✅ Finder (for AppleScript automation)

#### Raycast
- ✅ Finder
- ✅ Google Chrome
- ✅ QuickTime Player
- ✅ System Events

#### sketchybar
- ✅ Spotify (status bar music integration)

#### skhd
- ✅ System Events (hotkey system control)

#### Sublime Text
- ✅ Finder (file operations)

#### VLC
- ✅ Spotify (media player integration)

#### WezTerm
- ✅ System Events

**How to grant**:
1. Open System Settings → Privacy & Security → Automation
2. Find the app in the list
3. Expand it to see target applications
4. Toggle each required target application
5. If an app doesn't appear, trigger the automation action in the app (it will prompt for permission)

---

### App Management

**Path**: System Settings → Privacy & Security → App Management

Apps that can update or delete other applications:

- ✅ Latest (app updater)
- ✅ Marta (file manager)
- ✅ Raycast (app uninstall features)
- ✅ System Events
- ✅ WezTerm

**How to grant**:
1. Open System Settings → Privacy & Security → App Management
2. Toggle the switch for each app

---

### Files and Folders

**Path**: System Settings → Privacy & Security → Files and Folders

#### Marta (File Manager)
Needs access to:
- ✅ Desktop Folder
- ✅ Documents Folder
- ✅ Downloads Folder
- ✅ Google Drive
- ✅ Photos (full access)

**How to grant**:
1. Open System Settings → Privacy & Security → Files and Folders
2. Find "Marta" in the list
3. Toggle each required folder/service
4. For Photos, go to Privacy & Security → Photos and enable Marta

---

## Trackpad Gestures

**Path**: System Settings → Trackpad → More Gestures

The following gestures from your screenshots **cannot be automated**:

### Your Current Configuration

- ❌ **Swipe between pages**: Off
- ❌ **Swipe between full-screen applications**: Swipe Left or Right with Three Fingers
- ❌ **Notification Center**: Swipe left from the right edge with two fingers - **Enabled**
- ❌ **Mission Control**: Swipe Up with Three Fingers - **Enabled**
- ❌ **App Exposé**: Off
- ❌ **Launchpad**: Pinch with thumb and three fingers - **Enabled**
- ❌ **Show Desktop**: Spread with thumb and three fingers - **Enabled**

**How to configure**:
1. Open System Settings → Trackpad
2. Click "More Gestures" tab
3. Configure each gesture according to your preferences above

**Note**: The "Point & Click" and "Scroll & Zoom" tabs are mostly automated via nix-darwin (see `system-settings.nix`).

---

## Lock Screen UI

**Path**: System Settings → Lock Screen

The following UI settings **cannot be automated**:

- ❌ **Show large clock**: On Lock Screen (your setting)
- ❌ **Show 24-hour time**: Off (your setting)
- ❌ **Show user name and photo**: Enabled (your setting)
- ❌ **Show Sleep, Restart, and Shut Down buttons**: Enabled (your setting)

**Automated settings** (via nix-darwin):
- ✅ **Require password after screensaver begins**: After 1 hour (automated)

**How to configure**:
1. Open System Settings → Lock Screen
2. Configure "Show large clock" to "On Lock Screen"
3. Keep "Show 24-hour time" disabled
4. Scroll to "When Switching User" section
5. Ensure "Show user name and photo" is enabled
6. Ensure "Show the Sleep, Restart, and Shut Down buttons" is enabled

---

## Touch ID

**Path**: System Settings → Touch ID & Password

**Cannot be automated**:
- ❌ Adding fingerprints
- ❌ Configuring Touch ID settings
- ❌ Touch ID unlock preferences

**How to configure**:
1. Open System Settings → Touch ID & Password
2. Click "Add Fingerprint..."
3. Follow the on-screen instructions to scan your fingerprint
4. Name your fingerprint
5. Repeat for additional fingerprints
6. Configure Touch ID unlock settings

---

## Other Settings

### Recent Items

**Path**: Apple menu  → Recent Items

**Setting**: None (0 items)

**Manual command** (nix-darwin doesn't support this):
```bash
defaults write NSGlobalDomain NSRecentDocumentsLimit 0
```

To verify:
```bash
defaults read NSGlobalDomain NSRecentDocumentsLimit
# Should return: 0
```

---

### Clone Personal Repositories

**Cannot be automated**: Requires SSH authentication and personal workflow decisions

Clone your frequently-used repositories to your preferred locations. Example:

```bash
# Create projects directory
mkdir -p ~/projects

# Clone your dotfiles (if not already cloned via chezmoi)
git clone git@github.com:gnohj/dotfiles.git ~/projects/dotfiles

# Clone other personal repos as needed
# git clone git@github.com:gnohj/repo-name.git ~/projects/repo-name
```

**Note**: This assumes your SSH key is already configured via `user-setup.sh` and Bitwarden.

---

### Migrate Wallpapers from iCloud

**Cannot be automated**: Large binary files not suitable for git storage

If you sync wallpapers via iCloud Drive, create a local copy:

```bash
# Copy wallpapers from iCloud to local Pictures folder
# iCloud path: ~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Pictures/wallpapers
# Local path: ~/Pictures/wallpapers

# If wallpapers exist in iCloud:
if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Pictures/wallpapers" ]; then
  cp -r "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Pictures/wallpapers" \
        "$HOME/Pictures/wallpapers"
  echo "✓ Wallpapers copied from iCloud to ~/Pictures/wallpapers"
else
  echo "⚠ iCloud wallpapers not found. Ensure iCloud Drive is synced."
fi
```

**Alternative**: If wallpapers are already in `~/Pictures/wallpapers`, no action needed.

**Why manual?**:
- Wallpapers are large binary files (several MB each)
- Not suitable for git repository storage
- Better synced via iCloud Drive or copied manually per machine

---

### Create Global Git Ignore File

**Cannot be automated**: Personal preference for global ignore patterns

Create a global gitignore file to exclude common files across all repositories:

```bash
# Create global gitignore file
cat > ~/.gitignore_global << 'EOF'
# macOS
.DS_Store
.AppleDouble
.LSOverride
._*

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Environment
.env
.env.local
*.local

# Node
node_modules/
npm-debug.log*

# Python
__pycache__/
*.py[cod]
.venv/
venv/

# Logs
*.log
logs/

# Temporary files
*.tmp
*.temp
.cache/
EOF

# Configure git to use the global gitignore
git config --global core.excludesfile ~/.gitignore_global

echo "✓ Global gitignore created at ~/.gitignore_global"
```

**Why manual?**:
- Personal ignore patterns vary by developer workflow
- Not all patterns may be desired for your use case
- Easier to customize directly than templating

**Verify**:
```bash
git config --global core.excludesfile
# Should return: /Users/yourusername/.gitignore_global
```

---

## Verification Checklist

After running through this guide, verify:

- [ ] All Accessibility permissions granted (17 apps)
- [ ] Full Disk Access granted to terminal apps (3 apps)
- [ ] Screen Recording permissions granted (2 apps)
- [ ] Automation permissions configured (11 apps with various targets)
- [ ] App Management permissions granted (5 apps)
- [ ] Marta has Files and Folders access (5 locations)
- [ ] Trackpad gestures configured (7 settings)
- [ ] Lock Screen UI options configured (4 settings)
- [ ] Touch ID fingerprints added
- [ ] Recent Items set to None
- [ ] Personal repositories cloned
- [ ] Wallpapers migrated from iCloud to `~/Pictures/wallpapers`
- [ ] Global gitignore file created at `~/.gitignore_global`

---

## Troubleshooting

### App doesn't appear in Privacy & Security list

**Solution**:
1. Launch the app at least once
2. Trigger the action that requires permission
3. The system will prompt for permission
4. The app should then appear in Settings

### Permission toggle is grayed out

**Solution**:
1. Click the lock icon at the bottom left
2. Enter your password to unlock
3. The toggles should become clickable

### Changes don't take effect

**Solution**:
1. Restart the affected application
2. If still not working, log out and log back in
3. For some settings, a full reboot may be required

### Reset all permissions for an app

**Command**:
```bash
# Reset all TCC permissions for specific app
tccutil reset All com.bundle.identifier

# Reset specific TCC service for an app
tccutil reset Accessibility com.bundle.identifier
```

**Note**: This removes all permissions. You'll need to re-grant them manually.

---

## Additional Resources

- [nix-darwin manual](https://daiderd.com/nix-darwin/manual/index.html)
- [macOS TCC documentation](https://book.hacktricks.xyz/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-tcc)
- [macOS defaults commands](https://macos-defaults.com/)

---

**Last Updated**: 2025-01-23
**macOS Version**: Sequoia and later
**nix-darwin Version**: See flake.lock
