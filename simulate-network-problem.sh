#!/bin/sh
if [ "$1" = "" ]; then
  echo "Syntax:"
  echo "$0 <source-addr> <destination-address> <destination-port> <probability> <duration>"
  echo "Example to drop ALL traffic (probability=1) during 10 seconds:"
  echo "$0 0/0 highfive.container.training 1935 1 10"
  exit 1
fi
RULE="OUTPUT -s $1 -d $2 -p tcp --dport $3 --match statistic --mode random --probability $4 -j DROP"
echo "Adding iptables rule..."
sudo iptables -I $RULE
echo "Waiting $5 seconds..."
echo "To interrupt, hit Ctrl-C then run:"
echo "sudo iptables -D $RULE"
sleep $5
echo "Checking itpables counters:"
sudo iptables -nxvL OUTPUT
echo "Removing iptables rule..."
sudo iptables -D $RULE
echo "Done."

