#!/bin/bash

DICE_ADDR=kQArRoAHZmbddIj0fJ06GS6ep90LoCUXICPZu8Zvqrv22Cyx

PLAYER_NAME=Bob # enter your name

PLAYER_INIT_BALANCE=1000000 # one million Grams

PLAYER_COUNT_GAMES=3000

TON_DIR=$HOME/ton-blockchain/ton # edit your path to TON sources

TON_BUILD_DIR=$HOME/ton-blockchain/latest-build # edit your path to the builded TON

LITE_CLIENT_CONFIG=./ton-lite-client-test-local.config.json # config for connecting to a private node

MAIN_WALLET_PK_FILE_BASE=main-wallet # do not edit

SMC_PATH=$TON_DIR/crypto/smartcont # do not edit

PK_FILE_NAME=$(echo "$PLAYER_NAME" | tr '[:upper:]' '[:lower:]') # do not edit

echo "Creating a wallet for a player $PLAYER_NAME..."

rm -rf build
mkdir build && cd build

SUBWALLET_ID=1

${TON_BUILD_DIR}/crypto/func -SPA -o $SMC_PATH/auto/highload-wallet-v2-code.fif $SMC_PATH/stdlib.fc $SMC_PATH/highload-wallet-v2-code.fc
${TON_BUILD_DIR}/crypto/fift -s $SMC_PATH/new-highload-wallet-v2.fif 0 $SUBWALLET_ID $PK_FILE_NAME

NB_WALLET_ADDR=$(${TON_BUILD_DIR}/crypto/fift -s $SMC_PATH/show-addr.fif ${PK_FILE_NAME}${SUBWALLET_ID} | grep 'Non-bounceable address' |  awk '{print $6}')

cd ../

echo "Wallet created."
echo "Player $PLAYER_NAME subwallet with id $SUBWALLET_ID address: $NB_WALLET_ADDR"

SEQNO=$(${TON_BUILD_DIR}/lite-client/lite-client -C $LITE_CLIENT_CONFIG -c "runmethod kf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIue seqno" -v 0 | grep result: | awk '/\[ [0-9]* \]/{print $3}')

${TON_BUILD_DIR}/crypto/fift -s $SMC_PATH/wallet.fif $MAIN_WALLET_PK_FILE_BASE $NB_WALLET_ADDR $SEQNO $PLAYER_INIT_BALANCE

${TON_BUILD_DIR}/lite-client/lite-client -C $LITE_CLIENT_CONFIG -c "sendfile ./wallet-query.boc"

sleep 20

${TON_BUILD_DIR}/lite-client/lite-client -C $LITE_CLIENT_CONFIG -c "sendfile ./build/${PK_FILE_NAME}${SUBWALLET_ID}-query.boc"

sleep 20

for num in $(seq 1 $PLAYER_COUNT_GAMES);
do
echo "Game #${num}"

ROLLUNDER=$(( ( RANDOM % 96 ) + 1 ))  # $(jot -r 1 2 96)

# $(( ( RANDOM % 10 ) + 1 ))  # $(jot -r 1 0 9999)
PLAYER_BET_AMOUNT=1 # $((1 + $RANDOM % 10))

${TON_BUILD_DIR}/crypto/fift -s $SMC_PATH/highload-wallet-v2-one.fif ./build/${PK_FILE_NAME} $DICE_ADDR $SUBWALLET_ID $PLAYER_BET_AMOUNT -C $ROLLUNDER

${TON_BUILD_DIR}/lite-client/lite-client -C $LITE_CLIENT_CONFIG -c "sendfile ./wallet-query.boc"

sleep 1;
done