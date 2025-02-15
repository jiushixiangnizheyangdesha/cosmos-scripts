# create wallet
strided keys add wallet

## console output:
#- name: wallet
#  type: local
#  address: stride11lfpde6scf7ulzvuq2suavav6cpmpy0rzxne0pw
#  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"Auq9WzVEs5pCoZgr2WctjI7fU+lJCH0I3r6GC1oa0tc0"}'
#  mnemonic: ""

#!!! SAVE SEED PHRASE
kite upset hip dirt pet winter thunder slice parent flag sand express suffer chest custom pencil mother bargain remember patient other curve cancel sweet

# wait util the node is synced, should return FALSE
strided status 2>&1 | jq .SyncInfo.catching_up

# go to discord channel #token-faucet and paste
$faucet-stride:YOUR_WALLET_ADDRESS

# verify the balance
strided q bank balances $(strided keys show wallet -a)

## console output:
#  balances:
#  - amount: "10000000"
#    denom: ustrd

# create validator
strided tx staking create-validator \
--amount=9000000ustrd \
--pubkey=$(strided tendermint show-validator) \
--moniker="YOUR_VALIDATOR_MONIKER" \
--chain-id=STRIDE-TESTNET-4 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--fees=2000ustrd \
--gas=auto \
--from=wallet \
-y

# make sure you see the validator details
strided q staking validator $(strided keys show wallet --bech val -a)
