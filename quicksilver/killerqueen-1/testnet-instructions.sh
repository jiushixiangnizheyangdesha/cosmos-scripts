# create wallet
quicksilverd keys add wallet

## console output:
#- name: wallet
#  type: local
#  address: quick159njc3xk0xv76x323936frgwxf9zn3wvlzrlf6
#  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"Auq9WzVEs5pCoZgr2WctjI7fU+lJCH0I3r6GC1oa0tc0"}'
#  mnemonic: ""

#!!! SAVE SEED PHRASE
reason crew zone unfold grain jungle shell before joke doll powder still aspect angle pepper nice canvas clinic one art rival lab wheat digital

#!!! SAVE PRIVATE VALIDATOR KEY
cat $HOME/.quicksilverd/config/priv_validator_key.json

# wait util the node is synced, should return FALSE
quicksilverd status 2>&1 | jq .SyncInfo.catching_up

# go to discord channel #qck-tap and paste
$request YOUR_WALLET_ADDRESS killerqueen

# verify the balance
quicksilverd q bank balances $(quicksilverd keys show wallet -a)

## console output:
#  balances:
#  - amount: "5000000"
#    denom: uqck

# create validator
quicksilverd tx staking create-validator \
--amount=4990000uqck \
--pubkey=$(quicksilverd tendermint show-validator) \
--moniker="YOUR_VALIDATOR_MONIKER" \
--chain-id=killerqueen-1 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--fees=2000uqck \
--gas=auto \
--from=wallet \
-y

# make sure you see the validator details
quicksilverd q staking validator $(quicksilverd keys show wallet --bech val -a)
