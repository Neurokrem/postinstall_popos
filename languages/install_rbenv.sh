echo "[Ruby] Installing dependencies..."

sudo apt-get update
sudo apt-get -y install \
  build-essential \
  libyaml-dev \
  zlib1g-dev \
  libreadline-dev \
  libssl-dev \
  libcurl4-openssl-dev \
  libffi-dev \
  autoconf \
  bison

echo "[Ruby] Installing rbenv..."

if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

if ! grep -q 'rbenv init' ~/.profile; then
cat << 'EOF' >> ~/.profile

export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init -)"
EOF
fi

echo "[Ruby] Installing Ruby 3.3.0..."

export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init -)"

rbenv install -s 3.3.10
rbenv global 3.3.10
rbenv rehash

ruby -v

sleep 3
