#!/bin/sh
# shellcheck disable=SC2086,SC3043,SC2164,SC2103,SC2046,SC2155
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi


get_sources() {
  # the checkout actions will set $HOME to other directory,
  # we need to reset some necessary git configs again.
  git config --global user.name "OpenWrt Builder"
  git config --global user.email "buster-openwrt@ovvo.uk"

  git clone $BUILD_REPO --single-branch -b $GITHUB_REF_NAME openwrt

  cd openwrt
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  cd -
}

echo_version() {
  echo "[=============== openwrt version ===============]"
  cd openwrt && git log -1 && cd -
  echo
  echo "[=============== configs version ===============]"
  cd configs && git log -1 && cd -
}

apply_patches() {
  [ -d patches ] || return 0

  dirname $(find patches -type f -name "*.patch") | sort -u | while read -r dir; do
    local patch_dir="$(realpath $dir)"
    cd "$(echo $dir | sed 's|^patches/|openwrt/|')"
    find $patch_dir -type f -name "*.patch" | while read -r patch; do
      git am $patch
    done
    cd -
  done
}

build_firmware() {
  cd openwrt

  cp ${GITHUB_WORKSPACE}/configs/${BUILD_PROFILE} .config
  make -j$(($(nproc) + 1)) V=e || make -j1 V=sc || exit 1

  cd -
}

package_binaries() {
  local bin_dir="openwrt/bin"
  local tarball="${BUILD_PROFILE}.tar.gz"
  tar -zcvf $tarball -C $bin_dir $(ls $bin_dir -1)
}

package_dl_src() {
  [ -n "$BACKUP_DL_SRC" ] || return 0
  [ $BACKUP_DL_SRC = 1 ] || return 0

  local dl_dir="openwrt/dl"
  local tarball="${BUILD_PROFILE}_dl-src.tar.gz"
  tar -zcvf $tarball -C $dl_dir $(ls $dl_dir -1)
}

get_sources
echo_version
apply_patches
build_firmware
package_binaries
package_dl_src
