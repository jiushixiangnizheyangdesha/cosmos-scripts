# create wallet
teritorid keys add wallet

## console output:
#- name: wallet
#  type: local
#  address: tori1wpkxhzufzrmz6glt4sjp54k3umgvx5hv3rx6y7
#  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"Auq9WzVEs5pCoZgr2WctjI7fU+lJCH0I3r6GC1oa0tc0"}'
#  mnemonic: ""

#!!! SAVE SEED PHRASE
kite upset hip dirt pet winter thunder slice parent flag sand express suffer chest custom pencil mother bargain remember patient other curve cancel sweet

#!!! SAVE PRIVATE VALIDATOR KEY
cat $HOME/.teritorid/config/priv_validator_key.json

# wait util the node is synced, should return FALSE
teritorid status 2>&1 | jq .SyncInfo.catching_up

# go to discord channel #faucet and paste
$request YOUR_WALLET_ADDRESS

# verify the balance
teritorid q bank balances $(teritorid keys show wallet -a)

## console output:
#  balances:
#  - amount: "1000000"
#    denom: utori

# create validator
teritorid tx staking create-validator \
--amount=1000000utori \
--pubkey=$(teritorid tendermint show-validator) \
--moniker="YOUR_VALIDATOR_MONIKER" \
--chain-id=teritori-testnet-v3 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--from=wallet \
-y

# make sure you see the validator details
teritorid q staking validator $(teritorid keys show wallet --bech val -a)
