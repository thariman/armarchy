# Omarchy Installation Failure Analysis

**Date**: 2025-11-07 12:00:56
**Status**: FAILED ❌

## Summary

The Omarchy installation failed due to **multiple package build failures**, primarily:
1. **ghostty-git**: File conflicts with existing terminfo files
2. **hyprland**: Compiler errors (calloc-transposed-args warnings)
3. **wlroots**: Build errors from upstream code issues

## Detailed Failure Analysis

### Primary Failure: ghostty-git

**Error**:
```
error: failed to commit transaction (conflicting files)
ghostty-terminfo-git: /usr/share/terminfo/g/ghostty exists in filesystem
ghostty-terminfo-git: /usr/share/terminfo/x/xterm-ghostty exists in filesystem
Errors occurred, no packages were upgraded.
```

**Root Cause**:
- The terminfo files for ghostty already exist in the filesystem
- This happens when ghostty was previously installed or when terminfo was manually added
- The package manager refuses to overwrite existing files

**Fix**:
```bash
# Remove existing terminfo files before installation
sudo rm -f /usr/share/terminfo/g/ghostty
sudo rm -f /usr/share/terminfo/x/xterm-ghostty

# Or force overwrite
pacman -U --overwrite '*' ghostty-terminfo-git-*.pkg.tar.zst
```

### Secondary Failure: hyprland

**Error**:
```
../examples/touch.c:223:60: error: 'calloc' sizes specified with 'sizeof' in the earlier
argument and not in the later argument [-Werror=calloc-transposed-args]
../examples/tablet.c:312:65: error: 'calloc' sizes specified with 'sizeof' in the earlier
argument and not in the later argument [-Werror=calloc-transposed-args]
cc1: all warnings being treated as errors
ninja: build stopped: subcommand failed.
```

**Root Cause**:
- wlroots (dependency of hyprland) has compiler warnings treated as errors
- Recent GCC versions added `-Wcalloc-transposed-args` warning
- Upstream wlroots code has calloc arguments in wrong order
- This is a known issue with wlroots 0.18.x on newer GCC versions

**Fix**:
- Wait for wlroots upstream fix
- Or patch the build to disable the warning:
  ```bash
  CFLAGS="-Wno-error=calloc-transposed-args" makepkg
  ```

### Impact Chain

```
wlroots (build failed)
   ↓
hyprland (depends on wlroots) → FAILED
   ↓
hyprshade (depends on hyprland) → FAILED
   ↓
aether (depends on hyprshade) → FAILED
```

## Successful Installation Comparison

### Working VM (omarchy)

**Installation Date**: 2025-11-03 17:07:13
**Status**: SUCCESS ✅

**Key Details**:
- Installation completed successfully
- All packages built and installed properly
- System is currently running and accessible

**Likely ISO Used**:
- archboot-2025.11.03 or earlier version
- Used "local" variant (full local packages)

### Failed Installation

**Installation Date**: 2025-11-07 12:00:56
**ISO Used**: archboot-2025.11.06-02.28-6.17.7-3-aarch64-ARCH-local-aarch64.iso
**Status**: FAILED ❌

**Key Difference**:
- **Newer ISO with updated packages**
- Updated GCC/compiler toolchain causing stricter warnings
- Updated package versions exposing upstream bugs

## Root Cause Summary

The failure is **NOT due to the automation scripts**, but rather:

1. **Package repository state changes** between Nov 3 and Nov 7
2. **Upstream package issues** (wlroots, ghostty terminfo conflicts)
3. **Compiler toolchain updates** in the newer ISO

## Recommended Solutions

### Option 1: Use the Working ISO (Safest)

```bash
# Download the ISO from Nov 3 or earlier
# Check your Downloads folder for:
archboot-2025.11.03-*-aarch64-ARCH-local-aarch64.iso

# Use this in config.sh
ISO_PATH="$HOME/Downloads/archboot-2025.11.03-*-aarch64-ARCH-local-aarch64.iso"
```

### Option 2: Skip Problematic Packages

Add to Omarchy installation environment:
```bash
export SKIP_GHOSTTY=1
export SKIP_HYPRLAND=1  # If available
```

### Option 3: Wait for Upstream Fixes

- wlroots maintainers need to fix calloc argument order
- ghostty-git needs better conflict handling
- Check again in a few days when packages are updated

### Option 4: Manual Fixes (Advanced)

**For ghostty**:
```bash
# Remove conflicting files first
ssh -p 11838 root@<VM_IP>
rm -f /usr/share/terminfo/g/ghostty /usr/share/terminfo/x/xterm-ghostty

# Then retry Omarchy installation
```

**For hyprland/wlroots**:
```bash
# Build with relaxed warnings
yay -S --editmenu wlroots
# Add to PKGBUILD:
# CFLAGS+=" -Wno-error=calloc-transposed-args"
```

## ISO Version Information

### Latest ISO (Failed)
- **Version**: 2025.11.06-02.28-6.17.7-3
- **Kernel**: 6.17.7
- **Build Date**: Nov 06, 2025 02:28
- **Variant**: local (full packages)
- **Size**: 908 MB
- **Result**: Installation fails on ghostty/hyprland

### Previous ISO (Working)
- **Date**: Nov 03, 2025 or earlier
- **Result**: Installation successful
- **Status**: Confirmed working on "omarchy" VM

## Recommendations

### For Immediate Use

1. **Use the Nov 3 ISO** if you have it
2. Or **download an older ISO** from Archboot archives
3. Skip problematic packages using environment variables

### For Future Installations

1. **Test new ISOs** in a separate VM first
2. **Keep working ISOs** as backups
3. **Monitor upstream issues**:
   - wlroots GitHub: https://gitlab.freedesktop.org/wlroots/wlroots
   - ghostty GitHub: https://github.com/ghostty-org/ghostty

### For the Automation Scripts

**No changes needed** - the scripts work correctly. The issue is:
- ✅ VM creation: Working
- ✅ Arch base install: Working
- ✅ GRUB configuration: Working
- ✅ System configuration: Working
- ❌ Omarchy package builds: **Upstream package issues**

## Timeline

- **Nov 3, 2025**: Successful installation with earlier ISO
- **Nov 6, 2025**: New Archboot ISO released (2025.11.06-02.28)
- **Nov 7, 2025**: Installation attempted with new ISO → FAILED
  - 11:55 - Base system installation successful
  - 12:00 - Omarchy installation started
  - 12:33 - ghostty build completed but installation failed
  - Package build chain failures cascaded

## Conclusion

The installation failure is due to **upstream package issues** in the newer repository state, not the automation scripts. The base Arch Linux installation completed successfully.

**Best immediate action**: Use the Nov 3 ISO or skip the problematic packages until upstream fixes are available.
