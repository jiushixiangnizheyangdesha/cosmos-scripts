# create wallet
nibid keys add wallet

## console output:
#- name: wallet
#  type: local
#  address: nibi1r9kmadqs9nsppn4wz5yp4rw8zn9545rc4zwvs7
#  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"Auq9WzVEs5pCoZgr2WctjI7fU+lJCH0I3r6GC1oa0tc0"}'
#  mnemonic: ""

#!!! SAVE SEED PHRASE
kite upset hip dirt pet winter thunder slice parent flag sand express suffer chest custom pencil mother bargain remember patient other curve cancel sweet

#!!! SAVE PRIVATE VALIDATOR KEY
cat $HOME/.nibid/config/priv_validator_key.json

# wait util the node is synced, should return FALSE
nibid status 2>&1 | jq .SyncInfo.catching_up

# go to https://discord.com/invite/zjkzZwrez5 channel #faucet and paste
$request YOUR_WALLET_ADDRESS

# verify the balance
nibid q bank balances $(nibid keys show wallet -a)

## console output:
#  balances:
#  - amount: "11000000"
#    denom: unibi

# create validator
nibid tx staking create-validator \
--amount=10000000unibi \
--pubkey=$(nibid tendermint show-validator) \
--moniker="YOUR_VALIDATOR_MONIKER" \
--chain-id=nibiru-testnet-2 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--fees=2000unibi \
--from=wallet \
-y

# make sure you see the validator details
nibid q staking validator $(nibid keys show wallet --bech val -a)
