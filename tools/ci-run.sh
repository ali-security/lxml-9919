#!/usr/bin/bash

GCC_VERSION=${GCC_VERSION:=8}

# Set up compilers
if [ -z "${OS_NAME##ubuntu*}" ]; then
  echo "Installing requirements [apt]"
  sudo apt-add-repository -y "ppa:ubuntu-toolchain-r/test"
  sudo apt install -y gnupg
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
  sudo bash -c 'echo -en "deb http://archive.ubuntu.com/ubuntu bionic main restricted universe multiverse\ndeb http://security.ubuntu.com/ubuntu bionic-security main restricted universe multiverse\n" >> "/etc/apt/sources.list"'

  sudo apt-get update -y
  # gcc-8
  wget http://mirrors.kernel.org/ubuntu/pool/universe/g/gcc-8/gcc-8_8.4.0-3ubuntu2_amd64.deb
  wget http://mirrors.edge.kernel.org/ubuntu/pool/universe/g/gcc-8/gcc-8-base_8.4.0-3ubuntu2_amd64.deb
  wget http://mirrors.kernel.org/ubuntu/pool/universe/g/gcc-8/libgcc-8-dev_8.4.0-3ubuntu2_amd64.deb
  wget http://mirrors.kernel.org/ubuntu/pool/universe/g/gcc-8/cpp-8_8.4.0-3ubuntu2_amd64.deb
  wget http://mirrors.kernel.org/ubuntu/pool/universe/g/gcc-8/libmpx2_8.4.0-3ubuntu2_amd64.deb
  wget http://mirrors.kernel.org/ubuntu/pool/main/i/isl/libisl22_0.22.1-1_amd64.deb
  sudo apt install ./libisl22_0.22.1-1_amd64.deb ./libmpx2_8.4.0-3ubuntu2_amd64.deb ./cpp-8_8.4.0-3ubuntu2_amd64.deb ./libgcc-8-dev_8.4.0-3ubuntu2_amd64.deb ./gcc-8-base_8.4.0-3ubuntu2_amd64.deb ./gcc-8_8.4.0-3ubuntu2_amd64.deb

  # cpp-8
  wget http://mirrors.kernel.org/ubuntu/pool/universe/g/gcc-8/libstdc++-8-dev_8.4.0-3ubuntu2_amd64.deb
  wget http://mirrors.kernel.org/ubuntu/pool/universe/g/gcc-8/g++-8_8.4.0-3ubuntu2_amd64.deb
  sudo apt install ./libstdc++-8-dev_8.4.0-3ubuntu2_amd64.deb ./g++-8_8.4.0-3ubuntu2_amd64.deb

  sudo apt-get install --allow-downgrades -y -q ccache gcc-$GCC_VERSION "libxml2=2.9.4*" "libxml2-dev=2.9.4*" libxslt1.1 libxslt1-dev || exit 1
  sudo /usr/sbin/update-ccache-symlinks
  echo "/usr/lib/ccache" >>$GITHUB_PATH # export ccache to path

  sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-$GCC_VERSION 60

  export CC="gcc"
  export PATH="/usr/lib/ccache:$PATH"

elif [ -z "${OS_NAME##macos*}" ]; then
  export CC="clang -Wno-deprecated-declarations"
fi

# Log versions in use
echo "===================="
echo "|VERSIONS INSTALLED|"
echo "===================="
python -c 'import sys; print("Python %s" % (sys.version,))'
if [ "$CC" ]; then
  which ${CC%% *}
  ${CC%% *} --version
fi
pkg-config --modversion libxml-2.0 libxslt
echo "===================="

ccache -s || true

# Install python requirements
echo "Installing requirements [python]"
python -m pip install --index-url 'https://:2022-02-17T14:33:16.238304Z@time-machines-pypi.sealsecurity.io/' -U pip setuptools wheel
if [ -z "${PYTHON_VERSION##*-dev}" ]; then
  python -m pip install --index-url 'https://:2022-02-17T14:33:16.238304Z@time-machines-pypi.sealsecurity.io/' --install-option=--no-cython-compile https://github.com/cython/cython/archive/master.zip
else
  python -m pip install --index-url 'https://:2022-02-17T14:33:16.238304Z@time-machines-pypi.sealsecurity.io/' -r requirements.txt
fi
if [ -z "${PYTHON_VERSION##2*}" ]; then
  python -m pip install --index-url 'https://:2022-02-17T14:33:16.238304Z@time-machines-pypi.sealsecurity.io/' -U beautifulsoup4==4.9.3 cssselect==1.1.0 html5lib==1.1 rnc2rng==2.6.5 ${EXTRA_DEPS} || exit 1
else
  python -m pip install --index-url 'https://:2022-02-17T14:33:16.238304Z@time-machines-pypi.sealsecurity.io/' -U beautifulsoup4 cssselect html5lib rnc2rng ${EXTRA_DEPS} || exit 1
fi
if [ "$COVERAGE" == "true" ]; then
  python -m pip install --index-url 'https://:2022-02-17T14:33:16.238304Z@time-machines-pypi.sealsecurity.io/' "coverage<5" || exit 1
  python -m pip install --index-url 'https://:2022-02-17T14:33:16.238304Z@time-machines-pypi.sealsecurity.io/' --pre 'Cython>=3.0a0' || exit 1
fi

# Build
CFLAGS="-Og -g -fPIC -Wall -Wextra" python -u setup.py build_ext --inplace \
  $(if [ -n "${PYTHON_VERSION##2.*}" ]; then echo -n " -j7 "; fi) \
  $(if [ "$COVERAGE" == "true" ]; then echo -n " --with-coverage"; fi) ||
  exit 1

ccache -s || true

# Run tests
CFLAGS="-Og -g -fPIC" PYTHONUNBUFFERED=x make test || exit 1

# python setup.py install || exit 1
# python -c "from lxml import etree" || exit 1

CFLAGS="-O3 -g1 -mtune=generic -fPIC -fno-lto" \
  LDFLAGS="-fno-lto" \
  make clean wheel || exit 1

ccache -s || true
