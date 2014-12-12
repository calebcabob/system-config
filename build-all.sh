#!/bin/bash
cd $(dirname $(readlink -f $0))
export DOING_T1WRENCH_RELEASE=true
export ReleaseVersion="$1"

set -e

function die() {
    echo Error: "$@"
    exit -1
}

. .gitx

if git st -s | grep . -q; then
    git st -s
    die "Can't do release build when git not clean: see output above"
fi

if is-tty-io; then
    src_version=$(cd ~/src/github/T1Wrench-linux; cat .src-version.txt)
    git log $src_version..HEAD
    yes-or-no-p -y "Continue?"
fi

git clean -xfd
git submodule foreach 'git clean -xfd'

(
    rm ~/tmp/build-t1-windows -rf
    ./build-wine.sh
    touch ~/tmp/build-t1-windows/build-ok
)&

(
    rm ~/tmp/build-t1 -rf
    ./build-linux.sh
    touch ~/tmp/build-t1/build-ok
)&

(
    ssh bhj-mac rm $(up) -rf
    rm ~/tmp/build-t1-mac -rf
    mkdir ~/tmp/build-t1-mac -p
    ./build-mac.sh
    touch ~/tmp/build-t1-mac/build-ok
)&

wait

if test ! -e ~/tmp/build-t1-windows/build-ok; then
    die "Windows build failed"
fi

if test ! -e ~/tmp/build-t1/build-ok; then
    die "Linux build failed"
fi

if test ! -e ~/tmp/build-t1-mac/build-ok; then
    die "Mac build failed"
fi

for x in ~/src/github/T1Wrench-linux ~/src/github/T1Wrench-macos/T1Wrench.app/Contents/MacOS/ ~/src/github/T1Wrench-windows; do
    (
        cd $x
        if test -e last-pic-notes.png; then
            rm -f last-pic-notes.png
        fi
        ./update-md5s.sh
        cd $(dirname $(lookup-file -e .git))
        dir=$(basename $PWD)
        cd ..

        file=~/tmp/$dir.zip
        if test "$dir" = T1Wrench-linux; then
            file=~/tmp/$dir.tgz
            tar czfv $file $dir --exclude-vcs
        else
            zip -r $file $dir -x '*/.git/*'
        fi
        smb-push $file ~/smb/share.smartisan.cn/share/baohaojun/T1Wrench
        rsync $file rem:/var/www/html/baohaojun/ -v
    )
done

echo all done