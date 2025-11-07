#!/bin/bash
# Check SSH and Firewall Status on Arch Linux VM
# Run this script INSIDE the Arch Linux VM (via console)

echo "==================================="
echo "SSH & Firewall Diagnostic Tool"
echo "==================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check if SSH is installed
echo "1. Checking if SSH is installed..."
if command -v sshd >/dev/null 2>&1; then
    SSHD_PATH=$(which sshd)
    echo -e "   ${GREEN}✓${NC} SSH is installed: $SSHD_PATH"
else
    echo -e "   ${RED}✗${NC} SSH is NOT installed!"
    echo "   Install with: pacman -S openssh"
    exit 1
fi
echo ""

# 2. Check SSH service status
echo "2. Checking SSH service status..."
if systemctl is-active --quiet sshd; then
    echo -e "   ${GREEN}✓${NC} SSH service is RUNNING"
else
    echo -e "   ${RED}✗${NC} SSH service is NOT RUNNING"
    echo "   Start with: systemctl start sshd"
    echo "   Enable on boot: systemctl enable sshd"
fi

if systemctl is-enabled --quiet sshd 2>/dev/null; then
    echo -e "   ${GREEN}✓${NC} SSH service is ENABLED (starts on boot)"
else
    echo -e "   ${YELLOW}⚠${NC} SSH service is DISABLED (won't start on boot)"
    echo "   Enable with: systemctl enable sshd"
fi
echo ""

# 3. Check what port SSH is listening on
echo "3. Checking SSH listening ports..."
if systemctl is-active --quiet sshd; then
    echo "   Active listening ports:"
    ss -tlnp | grep sshd | while read line; do
        PORT=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
        echo -e "   ${GREEN}✓${NC} SSH listening on port: $PORT"
    done

    # Also check with netstat if ss doesn't show anything
    if ! ss -tlnp | grep -q sshd; then
        netstat -tlnp 2>/dev/null | grep sshd | while read line; do
            PORT=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
            echo -e "   ${GREEN}✓${NC} SSH listening on port: $PORT"
        done
    fi
else
    echo -e "   ${YELLOW}⚠${NC} SSH service not running, cannot check listening ports"
fi
echo ""

# 4. Check SSH configuration
echo "4. Checking SSH configuration (/etc/ssh/sshd_config)..."
if [ -f /etc/ssh/sshd_config ]; then
    echo "   Key settings:"

    # Check Port
    PORT_LINE=$(grep -E "^Port " /etc/ssh/sshd_config)
    if [ -n "$PORT_LINE" ]; then
        echo "   $PORT_LINE"
    else
        echo -e "   Port: ${YELLOW}22 (default, not explicitly set)${NC}"
    fi

    # Check PermitRootLogin
    ROOT_LOGIN=$(grep -E "^PermitRootLogin" /etc/ssh/sshd_config)
    if [ -n "$ROOT_LOGIN" ]; then
        if echo "$ROOT_LOGIN" | grep -q "yes"; then
            echo -e "   ${GREEN}✓${NC} $ROOT_LOGIN"
        else
            echo -e "   ${YELLOW}⚠${NC} $ROOT_LOGIN"
        fi
    else
        echo -e "   PermitRootLogin: ${YELLOW}default (may be 'prohibit-password')${NC}"
    fi

    # Check PasswordAuthentication
    PASS_AUTH=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config)
    if [ -n "$PASS_AUTH" ]; then
        if echo "$PASS_AUTH" | grep -q "yes"; then
            echo -e "   ${GREEN}✓${NC} $PASS_AUTH"
        else
            echo -e "   ${YELLOW}⚠${NC} $PASS_AUTH"
        fi
    else
        echo -e "   PasswordAuthentication: ${YELLOW}default (usually 'yes')${NC}"
    fi
else
    echo -e "   ${RED}✗${NC} SSH config file not found!"
fi
echo ""

# 5. Check firewall status
echo "5. Checking firewall status..."

# Check iptables
if command -v iptables >/dev/null 2>&1; then
    echo "   Checking iptables..."
    IPTABLES_RULES=$(iptables -L -n 2>/dev/null | grep -v "^Chain\|^target" | grep -v "^$" | wc -l)
    if [ "$IPTABLES_RULES" -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} iptables: No filtering rules (ACCEPT all)"
    else
        echo -e "   ${YELLOW}⚠${NC} iptables: Active rules found"
        echo "   Checking INPUT chain for SSH ports:"
        iptables -L INPUT -n -v | grep -E "dpt:22|dpt:11838" || echo "   No specific SSH rules found"
    fi
else
    echo "   iptables: Not installed"
fi

# Check nftables
if command -v nft >/dev/null 2>&1; then
    echo "   Checking nftables..."
    NFT_RULES=$(nft list ruleset 2>/dev/null | wc -l)
    if [ "$NFT_RULES" -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} nftables: No rules configured"
    else
        echo -e "   ${YELLOW}⚠${NC} nftables: Active rules found"
        nft list ruleset | grep -E "ssh|22|11838" || echo "   No specific SSH rules found"
    fi
else
    echo "   nftables: Not installed"
fi

# Check UFW
if command -v ufw >/dev/null 2>&1; then
    echo "   Checking UFW..."
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    if echo "$UFW_STATUS" | grep -q "inactive"; then
        echo -e "   ${GREEN}✓${NC} UFW: inactive"
    else
        echo -e "   ${YELLOW}⚠${NC} UFW: $UFW_STATUS"
        ufw status | grep -E "22|11838"
    fi
else
    echo "   UFW: Not installed"
fi

# Check firewalld
if command -v firewall-cmd >/dev/null 2>&1; then
    echo "   Checking firewalld..."
    if systemctl is-active --quiet firewalld; then
        echo -e "   ${YELLOW}⚠${NC} firewalld: RUNNING"
        firewall-cmd --list-services 2>/dev/null | grep -q ssh && echo -e "   ${GREEN}✓${NC} SSH service allowed" || echo -e "   ${RED}✗${NC} SSH service not allowed"
        firewall-cmd --list-ports 2>/dev/null | grep -E "22|11838"
    else
        echo -e "   ${GREEN}✓${NC} firewalld: not running"
    fi
else
    echo "   firewalld: Not installed"
fi
echo ""

# 6. Check network interfaces and IP
echo "6. Network Configuration..."
echo "   IP Addresses:"
ip -4 addr show | grep "inet " | awk '{print "   " $2 " on " $NF}'
echo ""

# 7. Summary and recommendations
echo "==================================="
echo "Summary & Recommendations"
echo "==================================="
echo ""

if systemctl is-active --quiet sshd; then
    echo -e "${GREEN}✓ SSH is running${NC}"

    # Check if any firewall is blocking
    FIREWALL_ACTIVE=false
    if command -v iptables >/dev/null 2>&1; then
        IPTABLES_RULES=$(iptables -L -n 2>/dev/null | grep -v "^Chain\|^target" | grep -v "^$" | wc -l)
        [ "$IPTABLES_RULES" -gt 0 ] && FIREWALL_ACTIVE=true
    fi

    if [ "$FIREWALL_ACTIVE" = true ]; then
        echo -e "${YELLOW}⚠ Firewall may be filtering SSH${NC}"
        echo "  Check firewall rules and ensure SSH ports are allowed"
    else
        echo -e "${GREEN}✓ No firewall blocking SSH${NC}"
    fi

    echo ""
    echo "You should be able to connect with:"
    PORT=$(ss -tlnp 2>/dev/null | grep sshd | head -1 | awk '{print $4}' | rev | cut -d: -f1 | rev)
    if [ -z "$PORT" ]; then
        PORT=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    fi
    if [ -z "$PORT" ]; then
        PORT="22"
    fi
    IP=$(ip -4 addr show | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}' | cut -d/ -f1)
    echo "  ssh -p $PORT root@$IP"

else
    echo -e "${RED}✗ SSH is NOT running${NC}"
    echo ""
    echo "Start SSH with:"
    echo "  systemctl start sshd"
    echo "  systemctl enable sshd"
fi

echo ""
echo "==================================="
