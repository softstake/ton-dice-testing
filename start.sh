#!/bin/bash

WALLET_CONTRACT=./contracts/new-wallet.fif
DICE_CONTRACT=./contracts/dice-envelope.fif
DICE_PK_BASE=dice

DICE_BANK=10000 # Grams

NUMBER_OF_PLAYERS=3
PLAYERS_INIT_BALANCE=1000 # Grams

PLAYER_BET_AMOUNT=2 # Grams
PLAYER_COUNT_GAMES=10

# Clean state
./clean.sh

# mkdir ./lib

# Starting private TON node
docker volume create ton-db
docker run -d --name ton-node --mount source=ton-db,target=/var/ton-work/db -e "PUBLIC_IP=127.0.0.1" -e "PUBLIC_PORT=9995" -e "CONSOLE_PORT=9994" -e "LITESERVER=true" -e "LITE_PORT=9993" -it -p 9993:9993 -p 9994:9994 -p 9995:9995 kaemel/ton-private-net:0.4.20

sleep 60

docker cp ton-node:/var/ton-work/contracts/zerostate.fhash .
docker cp ton-node:/var/ton-work/contracts/zerostate.rhash .
docker cp ton-node:/var/ton-work/contracts/main-wallet.pk docker.pk
docker cp ton-node:/var/ton-work/contracts/main-wallet.addr docker.addr
docker cp ton-node:/var/ton-work/db/liteserver .
docker cp ton-node:/usr/local/bin/generate-random-id .
docker cp ton-node:/usr/local/bin/lite-client .
docker cp ton-node:/usr/local/bin/fift .
#docker cp ton-node:/usr/local/lib/fift/ ./lib/

#export FIFTPATH="./lib/fift/"
export FIFTPATH="/home/me/ton/crypto/fift/lib/"


LITE_SERVER_KEY=$(./generate-random-id -m id -k liteserver | jq 'select(.["@type"] == "pub.ed25519") | .["key"]')
sed -e "s#LITE_SERVER_KEY#${LITE_SERVER_KEY}#g" -e "s#ROOT_HASH#$(cat ./zerostate.rhash | base64)#g" -e "s#FILE_HASH#$(cat ./zerostate.fhash | base64)#g" ton-private-testnet-local.config.json.template > ton-lite-client-test-local.config.json

sleep 120

# Creating wallets for players
for n in $(seq 1 $NUMBER_OF_PLAYERS);
do
echo "Creating a wallet for a player $n..."

./fift -s $WALLET_CONTRACT -1 player-wallet${n}
NB_WALLET_ADDR=$(./fift -s ./contracts/show-addr.fif player-wallet${n} | grep 'Non-bounceable address' |  awk '{print $6}')

SEQNO=$(./lite-client -C ton-lite-client-test-local.config.json -c "runmethod kf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIue seqno" -v 0 | grep result: | awk '/\[ [0-9]* \]/{print $3}')
./fift -s ./contracts/wallet.fif docker $NB_WALLET_ADDR $SEQNO $PLAYERS_INIT_BALANCE wallet-query

./lite-client -C ton-lite-client-test-local.config.json -c "sendfile ./wallet-query.boc"
sleep 10

./lite-client -C ton-lite-client-test-local.config.json -c "sendfile ./player-wallet${n}-query.boc"
done

# Deploy dice contract
./fift -s $DICE_CONTRACT $DICE_PK_BASE
DICE_ADDR=$(./fift -s ./contracts/show-addr.fif $DICE_PK_BASE | grep 'Non-bounceable address' |  awk '{print $6}')

SEQNO=$(./lite-client -C ton-lite-client-test-local.config.json -c "runmethod kf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIue seqno" -v 0 | grep result: | awk '/\[ [0-9]* \]/{print $3}')
./fift -s ./contracts/wallet.fif docker $DICE_ADDR $SEQNO $DICE_BANK

./lite-client -C ton-lite-client-test-local.config.json -c "sendfile ./wallet-query.boc"
sleep 10

./lite-client -C ton-lite-client-test-local.config.json -c "sendfile ./dice.boc"

# Starting bets
for n in $(seq 1 $NUMBER_OF_PLAYERS);
do
echo "Starting bets by player $n..."
WALLET_ADDR=$(./fift -s ./contracts/show-addr.fif player-wallet${n} | grep 'Bounceable address' |  awk '{print $6}')
./auto-bet.sh player-wallet${n} $WALLET_ADDR $DICE_ADDR $PLAYER_BET_AMOUNT $PLAYER_COUNT_GAMES &
done
