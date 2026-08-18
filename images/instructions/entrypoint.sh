#!/bin/sh
set -eu

echo "================================================================"
echo "  SCENARIO 2 - INSTRUCTIONS"
echo "================================================================"
echo "application-a pods seem to be stuck in a Pending state."
echo "Can you check why?"
echo ""
echo "Once it is scheduled, read application-a's pod logs for the"
echo "next instruction."
echo "================================================================"

exec sleep infinity
