sudo systemctl stop sifnoded

cd || return
rm -rf sifnode
git clone https://github.com/Sifchain/sifnode.git
cd sifnode || return
git fetch --all
git checkout v1.0-beta.12
make install

sudo systemctl start sifnoded
