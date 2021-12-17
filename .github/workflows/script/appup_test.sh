#!/usr/bin/env bash
set -euo pipefail

#global
app=emqtt
supported_rel_vsns="1.4.5"

build_and_save_tar() {
    dest_dir="$1"
    #make clean
    rebar3 as emqtt_relup_test tar
    mv _build/emqtt_relup_test/rel/emqtt/emqtt-*.tar.gz "${dest_dir}"
}

build_legacy() {
    dest_dir="$1"
    for vsn in ${supported_rel_vsns};
    do
        echo "building rel tar for $vsn"
        git checkout "$vsn"
        rebar3 as emqtt tar
        mv _build/emqtt/rel/emqtt/emqtt-*.tar.gz "${dest_dir}"
        #build_and_save_tar "$dest_dir";
    done
}

untar_all_pkgs() {
    local dir="$1/"
    local appdir="$dir/$app"
    mkdir -p "$appdir"
    for f in ${dir}/*.tar.gz;
    do
        tar zxvf "$f" -C "$appdir";
    done
}

prepare_releases() {
    local dest_dir="$1"
    build_and_save_tar "$dest_dir"
    build_legacy "$dest_dir"
    untar_all_pkgs "$dest_dir"
}

test_relup_cleanup() {
    $appscript stop
}
test_relup() {
    local tar_dir="$1"
    local target_vsn="$2"
    local appdir="${tar_dir}/emqtt"
    mkdir -p "$appdir"
    rm --preserve-root -rf "${appdir}/*"

    trap test_relup_cleanup EXIT

    for vsn in ${supported_rel_vsns};
    do
        echo "unpack"
        tar zxvf "$tar_dir/$app-$vsn.tar.gz" -C "$appdir"
        echo "starting $vsn"
        export appscript="${appdir}/bin/emqtt"
        $appscript daemon
        $appscript ping
        $appscript versions
        echo "deploy $target_vsn"
        cp "$tar_dir/$app-$target_vsn.tar.gz" "$appdir/releases/"
        $appscript install "$target_vsn"
        $appscript versions
        $appscript upgrade --no-permenant "emqx-$target_vsn"
        $appscript ping
        $appscript versions

    done;
}

main() {
    tmpdir=$(mktemp -d -p .  --suffix '.relup_test')
    current_vsn=$(git describe --tags --always)
    echo "Using temp dir: $tmpdir"
    prepare_releases "$tmpdir" "$current_vsn"
    test_relup "$tmpdir" "$current_vsn"
}


cmd=${1:-"main"}

if [[ "main" == $cmd ]]; then
    main
else
    shift 1
    $cmd $@
fi
