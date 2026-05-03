# Global Pi Agent Instructions

## Configuration Management

Always update pi agent configuration files via the chezmoi source directory:

```
~/.local/share/chezmoi/dot_pi/
```

Then apply with:

```bash
chezmoi apply
```

**Never edit files directly under `~/.pi/` or `~/.config/`.** Changes made there will be lost or overwritten by chezmoi.
