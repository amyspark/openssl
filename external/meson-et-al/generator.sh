#!/bin/bash
set -e
set -x

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -rf generated-config

rm -rf config/archs

# Generate manifest for ms/applink.c
mkdir -p ms
cat <<EOF > ms/meson.build
install_headers(
    'applink.c'
    subdir: 'openssl',
)
EOF

# Generate manifest for architecture-agnostic headers
headers=$(find ../../include/openssl -name *.h -o -name *.H -not -name '__DECC_*' | xargs -I % basename % | xargs -I % echo "    '%',")
mkdir -p include/openssl
cat <<EOF > include/openssl/meson.build
openssl_headers = files(
$headers
)
EOF

# Generate scaffold
LANG=C make -C config

# Copy generated files back into correct place
cmd='mkdir -p ../../../generated-$(dirname "$1"); cp "$1" ../../../generated-"$1"'
find config/archs -name 'meson.build' -exec sh -c "$cmd" _ignored {} \;
find config/archs -name '*.asm' -exec sh -c "$cmd" _ignored {} \;
find config/archs -name '*.c' -exec sh -c "$cmd" _ignored {} \;
find config/archs -name '*.h' -exec sh -c "$cmd" _ignored {} \;
find config/archs -iname '*.s' -exec sh -c "$cmd" _ignored {} \;
find config/archs -iname '*.rc' -exec sh -c "$cmd" _ignored {} \;
find config/archs -iname '*.def' -exec sh -c "$cmd" _ignored {} \;

# AIX is not supported by Meson
rm -rf ../../../generated-config/archs/aix*
# 32-bit s390x supported in Meson
rm -rf ../../../generated-config/archs/linux32-s390x
# Remove build info files, we use hardcoded deterministic one instead
rm -rf ../../../generated-config/archs/*/*/crypto/buildinf.h
