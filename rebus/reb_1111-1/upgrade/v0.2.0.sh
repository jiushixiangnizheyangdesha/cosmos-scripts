sudo systemctl stop rebusd

cd || return
rm -rf rebus.core
git clone https://github.com/rebuschain/rebus.core.git
cd rebus.core || return
git checkout v0.2.0
make install

sudo systemctl restart rebusd