# Idempotency Analysis of Automation Scripts

**Date**: 2025-11-07
**Purpose**: Review all scripts to ensure they are idempotent (safe to run multiple times)

## Summary

| Script | Status | Issues | Action Needed |
|--------|--------|--------|---------------|
| loginvm.sh | ✅ IDEMPOTENT | None | ✓ Already fixed |
| get-logs.sh | ✅ IDEMPOTENT | None | No changes needed |
| select-iso.sh | ✅ IDEMPOTENT | None | No changes needed |
| config.sh | ✅ IDEMPOTENT | None | No changes needed |
| troubleshoot-ssh.sh | ✅ IDEMPOTENT | None | No changes needed |
| check-ssh-vm.sh | ✅ IDEMPOTENT | None | No changes needed |
| get_latest_version.sh | ✅ MOSTLY IDEMPOTENT | Re-downloads sig | Minor - acceptable |
| fix-ssh-firewall.sh | ⚠️ NOT IDEMPOTENT | Duplicates iptables rules | **NEEDS FIX** |
| cpscript.sh | ⚠️ NOT IDEMPOTENT | Always runs operations | **NEEDS FIX** |
| ArchAuto.sh | ❌ NOT IDEMPOTENT | Deletes VM every time | **BY DESIGN** |
| Omarchy-Arm.sh | ❌ NOT IDEMPOTENT | Wipes disk, installs fresh | **BY DESIGN** |

## Detailed Analysis

### ✅ IDEMPOTENT Scripts (No Changes Needed)

#### loginvm.sh
- ✓ Checks if SSH key exists before installing
- ✓ Checks if xterm-ghostty exists before installing
- ✓ Safe to run multiple times
- **Status**: Already fixed in recent update

#### get-logs.sh
- ✓ Only downloads files, doesn't modify VM
- ✓ Overwrites local copies (expected behavior)
- ✓ Safe to run multiple times

#### select-iso.sh
- ✓ Only displays menu and sets variables
- ✓ No side effects
- ✓ Safe to run multiple times

#### config.sh
- ✓ Only sets variables
- ✓ Functions are read-only operations
- ✓ Safe to source multiple times

#### troubleshoot-ssh.sh
- ✓ Read-only diagnostic tool
- ✓ No modifications to system
- ✓ Safe to run multiple times

#### check-ssh-vm.sh
- ✓ Read-only diagnostic tool
- ✓ No modifications to system
- ✓ Safe to run multiple times

#### get_latest_version.sh
- ✓ Checks if ISO exists before downloading
- ⚠️ Always re-downloads signature file (minor issue, acceptable)
- ✓ Mostly idempotent - ISO won't be re-downloaded

### ⚠️ NEEDS FIX - Non-Idempotent Scripts

#### fix-ssh-firewall.sh ⚠️

**Problem**:
```bash
iptables -A INPUT -p tcp --dport 11838 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```
- Uses `-A` (append) which adds duplicate rules on each run
- Running twice creates multiple identical rules

**Impact**: Medium
- Rules still work but clutter iptables
- Wastes resources checking duplicate rules

**Fix**: Check if rule exists before adding
```bash
# Check if rule exists, add only if not present
if ! iptables -C INPUT -p tcp --dport 11838 -j ACCEPT 2>/dev/null; then
    iptables -A INPUT -p tcp --dport 11838 -j ACCEPT
fi
```

#### cpscript.sh ⚠️

**Problem**:
```bash
ssh-copy-id -p $SSH_PORT $SSH_OPTS root@$IP
infocmp -x xterm-ghostty | ssh -p $SSH_PORT $SSH_OPTS root@$IP -- tic -x -
scp -P $SSH_PORT $SSH_OPTS $INSTALL_SCRIPT root@$IP:/tmp/.
scp -P $SSH_PORT $SSH_OPTS bashrc root@$IP:/tmp/.
```
- Always runs ssh-copy-id (even if key exists)
- Always runs infocmp/tic (even if terminfo exists)
- Always copies files (minor - acceptable for script transfer)

**Impact**: Low
- ssh-copy-id is mostly harmless if key exists
- infocmp/tic overwrites existing terminfo (acceptable)
- File copies are expected behavior

**Fix**: Add checks like loginvm.sh
```bash
# Check if key auth works before ssh-copy-id
# Check if terminfo exists before infocmp/tic
```

### ❌ NOT IDEMPOTENT BY DESIGN

#### ArchAuto.sh ❌

**Behavior**:
```bash
prlctl delete "$VM_NAME"
prlctl create "$VM_NAME" ...
```
- **Intentionally** deletes and recreates VM
- This is the expected behavior for a "create fresh VM" script

**Status**: Correct as-is
- Users expect a clean slate
- Deleting existing VM prevents conflicts
- Not meant to be idempotent

#### Omarchy-Arm.sh ❌

**Behavior**:
```bash
wipefs -af "${DISK}"
sgdisk --zap-all "${DISK}"
```
- **Intentionally** wipes disk and installs fresh
- This is an installation script, not a configuration script

**Status**: Correct as-is
- Installation scripts should start fresh
- Asks for "YES" confirmation before proceeding
- Not meant to be idempotent

## Recommendations

### High Priority Fixes

1. **fix-ssh-firewall.sh** - Add rule existence checks
   - Prevents duplicate iptables rules
   - Makes script truly idempotent

2. **cpscript.sh** - Add conditional checks
   - Check SSH key before ssh-copy-id
   - Check terminfo before infocmp/tic
   - Matches loginvm.sh behavior

### Low Priority

3. **get_latest_version.sh** - Optionally skip sig re-download
   - Check if sig file exists and is recent
   - Very minor optimization

### No Changes Needed

4. **ArchAuto.sh** - Keep as-is (intentionally destructive)
5. **Omarchy-Arm.sh** - Keep as-is (installation script)

## Implementation Plan

### 1. Fix fix-ssh-firewall.sh

Add checks before adding iptables rules:
```bash
echo "1. Checking and adding iptables rules..."
# Check port 11838
if iptables -C INPUT -p tcp --dport 11838 -j ACCEPT 2>/dev/null; then
    echo "   ✓ Port 11838 already allowed"
else
    iptables -A INPUT -p tcp --dport 11838 -j ACCEPT
    echo "   ✓ Port 11838 rule added"
fi

# Check port 22
if iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null; then
    echo "   ✓ Port 22 already allowed"
else
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    echo "   ✓ Port 22 rule added"
fi
```

### 2. Fix cpscript.sh

Add checks similar to loginvm.sh:
```bash
# Check SSH key authentication
if ssh -p $SSH_PORT $SSH_OPTS -o BatchMode=yes root@$IP "echo ok" 2>/dev/null | grep -q ok; then
    echo "✓ SSH key already configured"
else
    echo "Installing SSH key..."
    ssh-copy-id -p $SSH_PORT $SSH_OPTS root@$IP
fi

# Check terminfo
if ssh -p $SSH_PORT $SSH_OPTS root@$IP "infocmp xterm-ghostty >/dev/null 2>&1"; then
    echo "✓ xterm-ghostty terminfo already installed"
else
    echo "Installing xterm-ghostty terminfo..."
    infocmp -x xterm-ghostty | ssh -p $SSH_PORT $SSH_OPTS root@$IP -- tic -x -
fi
```

## Testing Checklist

After implementing fixes, verify:

- [ ] fix-ssh-firewall.sh can run twice without duplicating rules
- [ ] cpscript.sh can run twice without errors
- [ ] Running scripts multiple times produces same result
- [ ] Status messages clearly indicate what was skipped vs added

## Conclusion

Most scripts are already idempotent or idempotent by design. Two scripts need fixes:
1. **fix-ssh-firewall.sh** - Add iptables rule checks
2. **cpscript.sh** - Add SSH key and terminfo checks

These fixes will make the entire toolkit safely re-runnable without side effects.
