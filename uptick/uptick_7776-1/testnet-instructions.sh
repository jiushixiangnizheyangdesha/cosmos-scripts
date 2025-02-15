# create wallet
uptickd keys add wallet

## console output:
#- name: wallet
#  type: local
#  address: uptick11lfpde6scf7ulzvuq2suavav6cpmpy0rzxne0pw
#  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"Auq9WzVEs5pCoZgr2WctjI7fU+lJCH0I3r6GC1oa0tc0"}'
#  mnemonic: ""

#!!! SAVE SEED PHRASE
kite upset hip dirt pet winter thunder slice parent flag sand express suffer chest custom pencil mother bargain remember patient other curve cancel sweet

#!!! SAVE PRIVATE VALIDATOR KEY
cat $HOME/.uptickd/config/priv_validator_key.json

# wait util the node is synced, should return FALSE
uptickd status 2>&1 | jq .SyncInfo.catching_up

# go to discord channel #faucet and paste
$faucet YOUR_WALLET_ADDRESS

# verify the balance
uptickd q bank balances $(uptickd keys show wallet -a)

## console output:
#  balances:
#  - amount: "5000000000000000000"
#    denom: auptick

# create validator
uptickd tx staking create-validator \
--amount=4900000000000000000auptick \
--pubkey=$(uptickd tendermint show-validator) \
--moniker="YOUR_VALIDATOR_MONIKER" \
--chain-id=uptick_7776-1 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--fees=20000auptick \
--gas=auto \
--from=wallet \
-y

# make sure you see the validator details
uptickd q staking validator $(uptickd keys show wallet --bech val -a)
