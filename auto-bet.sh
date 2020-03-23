#!/bin/bash
# Usage: ./auto-bet.sh <pk_file_base> <wallet-addr> <dice-addr> <bet-amount> <num_games>

if [ $# -lt 5 ]
then
echo "Usage: ${0} <pk_file_base> <wallet_addr> <dice_addr> <bet-amount> <num_games>"
exit 0
fi

file_base=$1
wallet_addr=$2
dice_addr=$3
bet_amount=$4
num_games=$5

for num in $(seq 1 $num_games);
do
roll_under=$(jot -r 1 2 96)

cmd="runmethod ${wallet_addr} seqno"
seq=$(./lite-client -C ton-lite-client-test-local.config.json -c "$cmd" -v 0 | grep result: | awk '/\[ [0-9]* \]/{print $3}')
echo "seq: ${seq}, roll_under: ${roll_under}"

cmd="sendfile ${file_base}.boc"
./fift -s ./bet-query.fif ${seq} ${file_base} ${wallet_addr} ${dice_addr} ${bet_amount} ${roll_under} ${num} ${file_base} && ./lite-client -C ton-lite-client-test-local.config.json -c "$cmd";
sleep 5;
done
