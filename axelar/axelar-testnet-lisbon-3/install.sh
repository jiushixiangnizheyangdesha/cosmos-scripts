#!/bin/bash
# shellcheck disable=SC1090

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER
read -s -p "Enter your keyring password: " KEYRING_PASSWORD
printf "\n"
read -s -p "Enter your tofnd password: " TOFND_PASSWORD
printf "\n"

CHAIN_ID="axelar-testnet-lisbon-3"
CHAIN_HOME=".axelar_testnet"
CHAIN_DENOM="uaxl"
AXELARD_BINARY_NAME="axelard"
AXELARD_BINARY_VERSION="v0.29.1"
AXELARD_BINARY_PATH="$HOME/$CHAIN_HOME/bin/$AXELARD_BINARY"
TOFND_VERSION="v0.10.1"
CHEAT_SHEET="https://nodejumper.io/axelar-testnet/cheat-sheet"

printLine
echo -e "Node moniker:    ${CYAN}$NODE_MONIKER${NC}"
echo -e "Chain id:        ${CYAN}$CHAIN_ID${NC}"
echo -e "Chain home:      ${CYAN}$CHAIN_HOME${NC}"
echo -e "Chain demon:     ${CYAN}$CHAIN_DENOM${NC}"
echo -e "axelard version: ${CYAN}$AXELARD_BINARY_VERSION${NC}"
echo -e "tofnd version:   ${CYAN}$TOFND_VERSION${NC}"
printLine
sleep 1

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/dependencies_install.sh)

printCyan "4. Building binaries..." && sleep 1

# create required directories
mkdir -p "$HOME/$CHAIN_HOME/"{.vald,.tofnd,bin,logs}

# build axelard binary
cd || return
rm -rf axelar-core
git clone https://github.com/axelarnetwork/axelar-core.git
cd axelar-core || return
git checkout "$AXELARD_BINARY_VERSION"
make build
cp bin/axelard "$HOME/$CHAIN_HOME/bin/axelard"

# download tofnd binary
curl "https://axelar-releases.s3.us-east-2.amazonaws.com/tofnd/$TOFND_VERSION/tofnd-linux-amd64-$TOFND_VERSION" > "$HOME/$CHAIN_HOME/bin/tofnd"
chmod +x "$HOME/$CHAIN_HOME/bin/tofnd"

# save variables
# shellcheck disable=SC2129
echo "export PATH=$PATH:$HOME/$CHAIN_HOME/bin" >> "$HOME/.bash_profile"
echo "export AXELARD_HOME=$HOME/$CHAIN_HOME" >> "$HOME/.bash_profile"
echo "export AXELARD_CHAIN_ID=$AXELARD_CHAIN_ID" >> "$HOME/.bash_profile"
source "$HOME/.bash_profile"

# init chain
axelard init "$NODE_MONIKER" --chain-id $CHAIN_ID --home "$HOME/$CHAIN_HOME"

# override configs
curl https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/app.toml > "$HOME/$CHAIN_HOME/config/app.toml"
curl https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/config.toml > "$HOME/$CHAIN_HOME/config/config.toml"
curl https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/resources/testnet/seeds.toml > "$HOME/$CHAIN_HOME/config/seeds.toml"
curl https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/resources/testnet/genesis.json > "$HOME/$CHAIN_HOME/config/genesis.json"
curl https://snapshots.axelar-testnet.nodejumper.io/axelar-testnet/addrbook.json > "$HOME/$CHAIN_HOME/config/addrbook.json"
sed -i 's|^moniker *=.*|moniker = "'"$NODE_MONIKER"'"|g' "$HOME/$CHAIN_HOME/config/config.toml"
sed -i 's|^external_address *=.*|external_address = "'"$(curl -s eth0.me)"':26656"|g' "$HOME/$CHAIN_HOME/config/config.toml"

PRUNING_INTERVAL=$(shuf -n1 -e 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
sed -i 's|^pruning *=.*|pruning = "custom"|g' "$HOME/$CHAIN_HOME/config/app.toml"
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' "$HOME/$CHAIN_HOME/config/app.toml"
sed -i 's|^pruning-interval *=.*|pruning-interval = "'$PRUNING_INTERVAL'"|g' "$HOME/$CHAIN_HOME/config/app.toml"
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 2000|g' "$HOME/$CHAIN_HOME/config/app.toml"

printCyan "5. Starting services and synchronization..." && sleep 1

sudo tee /etc/systemd/system/axelard.service > /dev/null << EOF
[Unit]
Description=Axelard Cosmos daemon
After=network-online.target

[Service]
User=$USER
ExecStart="$AXELARD_BINARY_PATH" start --home "$HOME/$CHAIN_HOME" --moniker "$NODE_MONIKER"
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# ! set your TOFND_PASSWORD
sudo tee /etc/systemd/system/tofnd.service > /dev/null << EOF
[Unit]
Description=Tofnd daemon
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/bin/sh -c 'echo "$TOFND_PASSWORD" | "$HOME/$CHAIN_HOME/bin/tofnd" -m existing -d $HOME/$CHAIN_HOME/.tofnd'
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# ! set your KEYRING_PASSWORD
sudo tee /etc/systemd/system/vald.service > /dev/null << EOF
[Unit]
Description=Vald daemon
After=network-online.target
[Service]
User=$USER
ExecStart=/usr/bin/sh -c 'echo "$KEYRING_PASSWORD" | $AXELARD_BINARY_PATH vald-start --validator-addr \$(echo "$KEYRING_PASSWORD" | $AXELARD_BINARY_PATH keys show validator --home "$HOME/$CHAIN_HOME" --bech val -a) --log_level debug --chain-id $CHAIN_ID --from broadcaster --home "$HOME/$CHAIN_HOME"'
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# download fresh snapshot
axelard tendermint unsafe-reset-all --home "$HOME/$CHAIN_HOME"

SNAP_NAME=$(curl -s https://snapshots.axelar-testnet.nodejumper.io/axelar-testnet/ | egrep -o ">axelar-testnet-lisbon-3.*\.tar.lz4" | tr -d ">")
curl https://snapshots.axelar-testnet.nodejumper.io/axelar-testnet/${SNAP_NAME} | lz4 -dc - | tar -xf - -C $HOME/.axelar_testnet

sudo systemctl daemon-reload
sudo systemctl enable axelard
sudo systemctl enable tofnd
sudo systemctl enable vald
sudo systemctl start axelard
sudo systemctl start tofnd
sudo systemctl start vald

printLine
echo -e "Check $AXELARD_BINARY_NAME logs:    ${CYAN}sudo journalctl -u $AXELARD_BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$AXELARD_BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
