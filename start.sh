#!/bin/bash

DICE_BANK=100000000 # 100 millions Gram

FILE_BASE=owner

PLAYER_NAME=Bob # enter your name

PLAYER_INIT_BALANCE=1000000 # one million Grams

PLAYER_COUNT_GAMES=1000

TON_DIR=$HOME/ton-blockchain/ton # edit your path to TON sources

TON_BUILD_DIR=$HOME/ton-blockchain/latest-build # edit your path to the builded TON

LITE_CLIENT_CONFIG=./ton-lite-client-test-local.config.json # config for connecting to a private node

MAIN_WALLET_PK_FILE_BASE=main-wallet # do not edit

SMC_PATH=$TON_DIR/crypto/smartcont # do not edit

PK_FILE_NAME=$(echo "$PLAYER_NAME" | tr '[:upper:]' '[:lower:]') # do not edit

#WALLET_CONTRACT=./contracts/new-wallet.fif
DICE_CONTRACT=./contracts/dice
#FILE_BASE=dice

# Clean state
./clean.sh

# Starting private TON node
docker volume create ton-db
#docker run -d --name ton-node --mount source=ton-db,target=/var/ton-work/db -e "PUBLIC_IP=127.0.0.1" -e "PUBLIC_PORT=9995" -e "CONSOLE_PORT=9994" -e "LITESERVER=true" -e "LITE_PORT=9993" -p 9993:9993 -p 9994:9994 -p 9995:9995 -it ton-node
#docker run -d --name ton-node --mount source=ton-db,target=/var/ton-work/db --network dice-network --ip 172.18.0.10 -e "PUBLIC_IP=172.18.0.10" -e "PUBLIC_PORT=9995" -e "CONSOLE_PORT=9994" -e "LITESERVER=true" -e "LITE_PORT=9993" -p 9993:9993 -p 9994:9994 -p 9995:9995 -it ton-node
docker run -d --name ton-node --mount source=ton-db,target=/var/ton-work/db --network dice-network --ip 172.18.0.10 -e "PUBLIC_IP=172.18.0.10" -e "PUBLIC_PORT=9995" -e "DHT_PORT=9996" -e "CONSOLE_PORT=9994" -e "LITESERVER=true" -e "LITE_PORT=9993" -e "GENESIS=1" -p 9993:9993 -p 9994:9994 -p 9995:9995 -it kaemel/general-ton-node:0.5.0

sleep 60

docker cp ton-node:/var/ton-work/contracts/zerostate.fhash .
docker cp ton-node:/var/ton-work/contracts/zerostate.rhash .
docker cp ton-node:/var/ton-work/contracts/main-wallet.pk .
docker cp ton-node:/var/ton-work/contracts/main-wallet.addr .
docker cp ton-node:/var/ton-work/db/liteserver .
docker cp ton-node:/var/ton-work/db/liteserver.pub .
#docker cp ton-node:/usr/local/bin/generate-random-id .
#docker cp ton-node:/usr/local/bin/lite-client .
#docker cp ton-node:/usr/local/bin/fift .
#docker cp ton-node:/usr/local/lib/fift/ ./lib/

LITE_SERVER_KEY=$(generate-random-id -m id -k liteserver | jq 'select(.["@type"] == "pub.ed25519") | .["key"]')
sed -e "s#LITE_SERVER_KEY#${LITE_SERVER_KEY}#g" -e "s#ROOT_HASH#$(cat ./zerostate.rhash | base64)#g" -e "s#FILE_HASH#$(cat ./zerostate.fhash | base64)#g" ton-private-testnet-local.config.json.template > ton-lite-client-test-local.config.json

sleep 120

# Creating wallets for players
#for n in $(seq 1 $NUMBER_OF_PLAYERS);
#do
#echo "Creating a wallet for a player $n..."
#
#fift -s $WALLET_CONTRACT 0 player-wallet${n}
#NB_WALLET_ADDR=$(fift -s ./contracts/show-addr.fif player-wallet${n} | grep 'Non-bounceable address' |  awk '{print $6}')
#
#SEQNO=$(lite-client -C ton-lite-client-test-local.config.json -c "runmethod kf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIue seqno" -v 0 | grep result: | awk '/\[ [0-9]* \]/{print $3}')
#fift -s ./contracts/wallet.fif docker $NB_WALLET_ADDR $SEQNO $PLAYERS_INIT_BALANCE wallet-query
#
#lite-client -C ton-lite-client-test-local.config.json -c "sendfile ./wallet-query.boc"
#sleep 10
#
#lite-client -C ton-lite-client-test-local.config.json -c "sendfile ./player-wallet${n}-query.boc"
#done

rm -rf $DICE_CONTRACT
git clone -b develop https://github.com/tonradar/ton-dice-web-contract.git $DICE_CONTRACT
CD=$(pwd)
cd $DICE_CONTRACT && ./build.sh 0 $FILE_BASE
#cp ./build/dice-binary.boc $CD
#cp ./addresses/$FILE_BASE $CD
cd $CD

#./fift -s $DICE_CONTRACT $FILE_BASE
DICE_ADDR=$(${TON_BUILD_DIR}/crypto/fift -s $SMC_PATH/show-addr.fif $DICE_CONTRACT/addresses/$FILE_BASE | grep 'Non-bounceable address' |  awk '{print $6}')

SEQNO=$(${TON_BUILD_DIR}/lite-client/lite-client -C $LITE_CLIENT_CONFIG -c "runmethod kf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIue seqno" -v 0 | grep result: | awk '/\[ [0-9]* \]/{print $3}')
${TON_BUILD_DIR}/crypto/fift -s $SMC_PATH/wallet.fif $MAIN_WALLET_PK_FILE_BASE $DICE_ADDR $SEQNO $DICE_BANK

${TON_BUILD_DIR}/lite-client/lite-client -C $LITE_CLIENT_CONFIG -c "sendfile ./wallet-query.boc"
sleep 10

cmd="sendfile ${DICE_CONTRACT}/build/dice-binary.boc"
${TON_BUILD_DIR}/lite-client/lite-client -C ton-lite-client-test-local.config.json -c "$cmd"



#
## Starting bets
#for n in $(seq 1 $NUMBER_OF_PLAYERS);
#do
#echo "Starting bets by player $n..."
#WALLET_ADDR=$(fift -s ./contracts/show-addr.fif player-wallet${n} | grep 'Bounceable address' |  awk '{print $6}')
#./auto-bet.sh player-wallet${n} $WALLET_ADDR $DICE_ADDR $PLAYER_BET_AMOUNT $PLAYER_COUNT_GAMES &
#done
