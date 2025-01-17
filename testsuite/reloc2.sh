#!/bin/bash
. `dirname $0`/functions.sh
SHFLAGS=
case "`$RUN uname -m`" in
  ia64|ppc*|x86_64|mips*|arm*|aarch64) SHFLAGS=-fpic;; # Does not support non-pic shared libs
  s390*) if file reloc1lib1.so | grep -q 64-bit; then SHFLAGS=-fpic; fi;;
esac
# Disable this test under SELinux if textrel
if test -z "$SHFLAGS" -a -x /usr/sbin/getenforce; then
  case "`/usr/sbin/getenforce 2>/dev/null`" in
    Permissive|Disabled) ;;
    *) exit 77 ;;
  esac
fi
rm -f reloc2 reloc2lib*.so reloc2.log
$RUN_HOST $CC -shared $SHFLAGS -O2 -o reloc2lib1.so $srcdir/reloc2lib1.c
$RUN_HOST $CC -shared $SHFLAGS -O2 -o reloc2lib2.so $srcdir/reloc2lib2.c \
  reloc2lib1.so 2>/dev/null
BINS="reloc2"
LIBS="reloc2lib1.so reloc2lib2.so"
$RUN_HOST $CCLINK -o reloc2 $srcdir/reloc2.c -Wl,--rpath-link,. reloc2lib2.so
$RUN_HOST $STRIP -R .comment $BINS $LIBS
savelibs
echo $PRELINK ${PRELINK_OPTS--vm} ./reloc2 > reloc2.log
$RUN_HOST $PRELINK ${PRELINK_OPTS--vm} ./reloc2 >> reloc2.log 2>&1 || exit 1
grep -q ^`echo $PRELINK | sed 's/ .*$/: /'` reloc2.log && exit 2
if [ "x$CROSS" = "x" ]; then
 $RUN LD_LIBRARY_PATH=. ./reloc2 || exit 3
fi
$RUN_HOST $READELF -a ./reloc2 >> reloc2.log 2>&1 || exit 4
# So that it is not prelinked again
chmod -x ./reloc2
comparelibs >> reloc2.log 2>&1 || exit 5
