#!/usr/bin/env bash
# Start skhd, waiting for secure keyboard entry to clear

MAX_WAIT=30  # Wait up to 30 seconds
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    # Check if any app has secure keyboard entry enabled
    if ioreg -l -w 0 | grep -q "kCGSSessionSecureInputPID"; then
        echo "Waiting for secure keyboard entry to clear... ($WAITED/$MAX_WAIT)"
        sleep 1
        WAITED=$((WAITED + 1))
    else
        echo "Secure keyboard entry clear, starting skhd..."
        exec /opt/homebrew/bin/skhd
        exit 0
    fi
done

echo "Timeout waiting for secure keyboard entry to clear. Starting skhd anyway..."
exec /opt/homebrew/bin/skhd
