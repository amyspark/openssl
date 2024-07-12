#! /usr/bin/env perl -w
use 5.10.0;
use strict;
use FindBin;
use lib "$FindBin::Bin/../../../";
use lib "$FindBin::Bin/../../../util/perl";
use lib "$FindBin::Bin/../../../util/perl/OpenSSL";
use File::Basename;
use File::Spec::Functions qw/:DEFAULT abs2rel rel2abs/;
use File::Copy;
use File::Path qw/make_path/;
#use with_fallback qw(Text::Template);
use fallback qw(Text::Template);

# Read configdata from <openssl root>/configdata.pm that is generated
# with <openssl root>/Configure options arch
use configdata;

my $asm = shift @ARGV;

unless ($asm eq "asm" or $asm eq "asm_avx2" or $asm eq "no-asm") {
  die "Error: $asm is invalid argument";
}
my $arch = shift @ARGV;

# nasm version check
my $nasm_banner = `nasm -v`;
die "Error: nasm is not installed." if (!$nasm_banner);

# gas/llvm-as version check
my $gas_banner = `gcc -Wa,-v -c -o /dev/null -x assembler /dev/null 2>&1`;
my ($gas_version) = ($gas_banner =~/GNU assembler version ([2-9]\.[0-9]+)/);
if ($gas_version ne "") {
  my $gas_version_min = 2.30;
  if ($gas_version < $gas_version_min) {
    die "Error: gas version $gas_version is too old. " .
      "$gas_version_min or higher is required.";
  }
} else {
  my $llvm_version_min = 9.0;
  my $llvm_banner = `clang -Wa,--version -c -o /dev/null -x assembler /dev/null 2>&1`;
  my ($llvm_as_version) = ($llvm_banner =~/clang version ([0-9]+\.[0-9]+)/);
  if ($llvm_as_version < $llvm_version_min) {
    die "Error: LLVM $llvm_as_version is too old. " .
      "$llvm_version_min or higher is required."
  }
}

# Set the compiler
my $compiler;
if ($gas_banner) {
  $compiler = 'cc';
} else {
  $compiler = 'clang';
}

our $cfg_dir = "$FindBin::Bin/../";
our $src_dir = "$cfg_dir/../..";
our $arch_dir = "$cfg_dir/archs/$arch";
our $base_dir = "$arch_dir/$asm";

my $is_win = ($arch =~/^VC-WIN/);
# VC-WIN32 and VC-WIN64A generate makefile but it can be available
# with only nmake. Use pre-created Makefile_VC_WIN32
# Makefile_VC-WIN64A instead.
my $makefile = $is_win ? "$cfg_dir/Makefile_$arch": "Makefile";
# Generate arch dependent header files with Makefile
my $buildinf = "crypto/buildinf.h";
my $progs = "apps/progs.h";
my $prov_headers = "providers/common/include/prov/der_dsa.h providers/common/include/prov/der_wrap.h providers/common/include/prov/der_rsa.h providers/common/include/prov/der_ecx.h providers/common/include/prov/der_sm2.h providers/common/include/prov/der_ec.h providers/common/include/prov/der_digests.h";
my $fips_ld = ($arch =~ m/linux/ ? "providers/fips.ld" : "");
my $cmd1 = "cd $src_dir && make -f $makefile clean build_generated $buildinf $progs $prov_headers $fips_ld;";
system($cmd1) == 0 or die "Error in system($cmd1)";

# Copy and move all arch dependent header files into config/archs
make_path("$base_dir/crypto/include/internal", "$base_dir/include/openssl",
	  "$base_dir/include/crypto", "$base_dir/providers/common/include/prov",
	  "$base_dir/apps",
          {
           error => \my $make_path_err});
if (@$make_path_err) {
  for my $diag (@$make_path_err) {
    my ($file, $message) = %$diag;
    die "make_path error: $file $message\n";
  }
}
copy("$src_dir/configdata.pm", "$base_dir/") or die "Copy failed: $!";

my @openssl_dir_headers = shift @ARGV;
copy_headers(@openssl_dir_headers, 'openssl');

my @crypto_dir_headers = shift @ARGV;
copy_headers(@crypto_dir_headers, 'crypto');

move("$src_dir/include/crypto/bn_conf.h",
     "$base_dir/include/crypto/bn_conf.h") or die "Move failed: $!";
move("$src_dir/include/crypto/dso_conf.h",
     "$base_dir/include/crypto/dso_conf.h") or die "Move failed: $!";

copy("$src_dir/$buildinf",
     "$base_dir/crypto/") or die "Copy failed: $!";
move("$src_dir/$progs",
     "$base_dir/include") or die "Copy failed: $!";
copy("$src_dir/apps/progs.c",
     "$base_dir/apps") or die "Copy failed: $!";

copy("$src_dir/providers/common/include/prov/der_dsa.h",
     "$base_dir/providers/common/include/prov/") or die "Copy failed: $!";
copy("$src_dir/providers/common/include/prov/der_wrap.h",
     "$base_dir/providers/common/include/prov/") or die "Copy failed: $!";
copy("$src_dir/providers/common/include/prov/der_rsa.h",
     "$base_dir/providers/common/include/prov/") or die "Copy failed: $!";
copy("$src_dir/providers/common/include/prov/der_ecx.h",
     "$base_dir/providers/common/include/prov/") or die "Copy failed: $!";
copy("$src_dir/providers/common/include/prov/der_sm2.h",
     "$base_dir/providers/common/include/prov/") or die "Copy failed: $!";
copy("$src_dir/providers/common/include/prov/der_ec.h",
     "$base_dir/providers/common/include/prov/") or die "Copy failed: $!";
copy("$src_dir/providers/common/include/prov/der_digests.h",
     "$base_dir/providers/common/include/prov/") or die "Copy failed: $!";

my $linker_script_dir = "<(PRODUCT_DIR)/../../deps/openssl/config/archs/$arch/$asm/providers";
my $fips_linker_script = "";
if ($fips_ld ne "" and not $is_win) {
  $fips_linker_script = "$linker_script_dir/fips.ld";
  copy("$src_dir/providers/fips.ld",
       "$base_dir/providers/fips.ld") or die "Copy failed: $!";
}


# list headers following the Makefile glob
my @openssl_arch_headers = ();
foreach my $obj (glob("$base_dir/include/openssl/*.{h,H}")) {
  push(@openssl_arch_headers, substr($obj, length($base_dir) + 1));
}

# read openssl source lists from configdata.pm
my @libapps_srcs = ();
foreach my $obj (@{$unified_info{sources}->{'apps/libapps.a'}}) {
    #print("libapps ${$unified_info{sources}->{$obj}}[0]\n");
    push(@libapps_srcs, ${$unified_info{sources}->{$obj}}[0]);
}

my @libssl_srcs = ();
foreach my $obj (@{$unified_info{sources}->{libssl}}) {
  push(@libssl_srcs, ${$unified_info{sources}->{$obj}}[0]);
}

my @libcrypto_srcs = ();
my @generated_srcs = ();
foreach my $obj (@{$unified_info{sources}->{'libcrypto'}}) {
  my $src = ${$unified_info{sources}->{$obj}}[0];
  #print("libcrypto src: $src \n");
  # .S files should be preprocessed into .s
  if ($unified_info{generate}->{$src}) {
    # .S or .s files should be preprocessed into .asm for WIN
    $src =~ s\.[sS]$\.asm\ if ($is_win);
    push(@generated_srcs, $src);
  } else {
    if ($src =~ m/\.c$/) { 
      push(@libcrypto_srcs, $src);
    }
  }
}

if ($arch eq 'linux32-s390x' || $arch eq  'linux64-s390x') {
  push(@libcrypto_srcs, 'crypto/bn/asm/s390x.S');
}

my @lib_defines = ();
foreach my $df (@{$unified_info{defines}->{libcrypto}}) {
  #print("libcrypto defines: $df\n");
  push(@lib_defines, $df);
}


foreach my $obj (@{$unified_info{sources}->{'providers/libdefault.a'}}) {
  my $src = ${$unified_info{sources}->{$obj}}[0];
  #print("libdefault src: $src \n");
  # .S files should be preprocessed into .s
  if ($unified_info{generate}->{$src}) {
    # .S or .s files should be preprocessed into .asm for WIN
    $src =~ s\.[sS]$\.asm\ if ($is_win);
    push(@generated_srcs, $src);
  } else {
    if ($src =~ m/\.c$/) { 
      push(@libcrypto_srcs, $src);
    }
  }
}

foreach my $obj (@{$unified_info{sources}->{'providers/libcommon.a'}}) {
  my $src = ${$unified_info{sources}->{$obj}}[0];
  #print("libimplementations src: $src \n");
  # .S files should be preprocessed into .s
  if ($unified_info{generate}->{$src}) {
    # .S or .s files should be preprocessed into .asm for WIN
    $src =~ s\.[sS]$\.asm\ if ($is_win);
    push(@generated_srcs, $src);
  } else {
    if ($src =~ m/\.c$/) { 
      push(@libcrypto_srcs, $src);
    }
  }
}

foreach my $obj (@{$unified_info{sources}->{'providers/liblegacy.a'}}) {
  my $src = ${$unified_info{sources}->{$obj}}[0];
  #print("liblegacy src: $src \n");
  # .S files should be preprocessed into .s
  if ($unified_info{generate}->{$src}) {
    # .S or .s files should be preprocessed into .asm for WIN
    $src =~ s\.[sS]$\.asm\ if ($is_win);
    push(@generated_srcs, $src);
  } else {
    if ($src =~ m/\.c$/) { 
      push(@libcrypto_srcs, $src);
    }
  }
}

foreach my $obj (@{$unified_info{sources}->{'providers/legacy'}}) {
  if ($obj eq 'providers/legacy.ld' and not $is_win) {
    push(@generated_srcs, $obj);
  } else {
    my $src = ${$unified_info{sources}->{$obj}}[0];
    #print("providers/fips obj: $obj, src: $src\n");
    if ($src =~ m/\.c$/) {
      push(@libcrypto_srcs, $src);
    }
  }
}

my @libfips_srcs = ();
foreach my $obj (@{$unified_info{sources}->{'providers/libfips.a'}}) {
  my $src = ${$unified_info{sources}->{$obj}}[0];
  #print("providers/libfips.a obj: $obj src: $src \n");
  # .S files should be preprocessed into .s
  if ($unified_info{generate}->{$src}) {
    # .S or .s files should be preprocessed into .asm for WIN
    #$src =~ s\.[sS]$\.asm\ if ($is_win);
    #push(@generated_srcs, $src);
  } else {
    if ($src =~ m/\.c$/) {
      push(@libfips_srcs, $src);
    }
  }
}

foreach my $obj (@{$unified_info{sources}->{'providers/libcommon.a'}}) {
  my $src = ${$unified_info{sources}->{$obj}}[0];
  #print("providers/libfips.a obj: $obj src: $src \n");
  # .S files should be preprocessed into .s
  if ($unified_info{generate}->{$src}) {
    # .S or .s files should be preprocessed into .asm for WIN
    #$src =~ s\.[sS]$\.asm\ if ($is_win);
    #push(@generated_srcs, $src);
  } else {
    if ($src =~ m/\.c$/) {
      push(@libfips_srcs, $src);
    }
  }
}

foreach my $obj (@{$unified_info{sources}->{'providers/fips'}}) {
  if ($obj eq 'providers/fips.ld' and not $is_win) {
    push(@generated_srcs, $obj);
  } else {
    my $src = ${$unified_info{sources}->{$obj}}[0];
    #print("providers/fips obj: $obj, src: $src\n");
    if ($src =~ m/\.c$/) {
      push(@libfips_srcs, $src);
    }
  }
}

my @libfips_defines = ();
foreach my $df (@{$unified_info{defines}->{'providers/libfips.a'}}) {
  #print("libfips defines: $df\n");
  push(@libfips_defines, $df);
}

foreach my $df (@{$unified_info{defines}->{'providers/fips'}}) {
  #print("libfips defines: $df\n");
  push(@libfips_defines, $df);
}

my @apps_openssl_srcs = ();
foreach my $obj (@{$unified_info{sources}->{'apps/openssl'}}) {
  push(@apps_openssl_srcs, ${$unified_info{sources}->{$obj}}[0]);
}

# msvc and mingw require the .rc and .def, but none appear in
# sources; we need to pluck them out of generate
my @win_resources = grep {/(.rc$)|(.def$)/} (keys %{$unified_info{generate}});
foreach my $src (@win_resources) {
  # VC makefiles are intended for static files
  # Execute the rules straight out of configdata
  my $generation_cmd = join(" ", @{$unified_info{generate}->{$src}});
  my $cmd = "cd $src_dir && $generation_cmd > $src && " .
    "cp --parents $src $cfg_dir/archs/$arch/$asm && cd $cfg_dir";
  system("$cmd") == 0 or die "Error in system($cmd)";
}

my $libssl_def;
if (exists $unified_info{generate}->{'libssl.def'}) {
  $libssl_def = 'libssl.def';
} else {
  $libssl_def = '';
}
my $libssl_rc;
if (exists $unified_info{generate}->{'libssl.rc'}) {
  $libssl_rc = 'libssl.rc';
} else {
  $libssl_rc = '';
}
my $libcrypto_def;
if (exists $unified_info{generate}->{'libcrypto.def'}) {
  $libcrypto_def = 'libcrypto.def';
} else {
  $libcrypto_def = '';
}
my $libcrypto_rc;
if (exists $unified_info{generate}->{'libcrypto.rc'}) {
  $libcrypto_rc = 'libcrypto.rc';
} else {
  $libcrypto_rc = '';
}

# Generate all asm files and copy into config/archs
foreach my $src (@generated_srcs) {
  my $cmd = "cd $src_dir && CC=$compiler ASM=nasm make -f $makefile $src;" .
    "cp --parents $src $cfg_dir/archs/$arch/$asm; cd $cfg_dir";
  system("$cmd") == 0 or die "Error in system($cmd)";
}

$target{'lib_cppflags'} =~ s/-D//g;
my @lib_cppflags = split(/ /, $target{'lib_cppflags'});

my @cflags = ();
push(@cflags, @{$config{'cflags'}});
push(@cflags, @{$config{'CFLAGS'}});
push(@cflags, $target{'cflags'});
push(@cflags, $target{'CFLAGS'});

# AIX has own assembler not GNU as that does not support --noexecstack
if ($arch =~ /aix/) {
  @cflags = grep $_ ne '-Wa,--noexecstack', @cflags;
}

# Create openssl.gypi
my $template =
    Text::Template->new(TYPE => 'FILE',
                        SOURCE => 'openssl.gypi.tmpl',
                        DELIMITERS => [ "%%-", "-%%" ]
                        );
my $gypi = $template->fill_in(
    HASH => {
        libssl_srcs => \@libssl_srcs,
        libcrypto_srcs => \@libcrypto_srcs,
        lib_defines => \@lib_defines,
        generated_srcs => \@generated_srcs,
        config => \%config,
        target => \%target,
        cflags => \@cflags,
        asm => \$asm,
        arch => \$arch,
        lib_cppflags => \@lib_cppflags,
        is_win => \$is_win,
    });

my $gypi_path = "$FindBin::Bin/$arch/$asm/openssl.gypi";
make_path(dirname($gypi_path));
open(GYPI, ">", $gypi_path) or die "Couldn't open $gypi_path: $!";
print GYPI "$gypi";
close(GYPI);
#
# Create openssl-fips.gypi
my $fipstemplate =
    Text::Template->new(TYPE => 'FILE',
                        SOURCE => 'openssl-fips.gypi.tmpl',
                        DELIMITERS => [ "%%-", "-%%" ]
                        );
my $fipsgypi = $fipstemplate->fill_in(
    HASH => {
        libfips_srcs => \@libfips_srcs,
        libfips_defines => \@libfips_defines,
        generated_srcs => \@generated_srcs,
        config => \%config,
        target => \%target,
        cflags => \@cflags,
        asm => \$asm,
        arch => \$arch,
        lib_cppflags => \@lib_cppflags,
        is_win => \$is_win,
	linker_script => $fips_linker_script,
    });

my $fips_path = "$FindBin::Bin/$arch/$asm/openssl-fips.gypi";
make_path(dirname($fips_path));
open(FIPSGYPI, ">", $fips_path) or die "Couldn't open $fips_path: $!";
print FIPSGYPI "$fipsgypi";
close(FIPSGYPI);

# Create openssl-cl.gypi
my $cltemplate =
    Text::Template->new(TYPE => 'FILE',
                        SOURCE => 'openssl-cl.gypi.tmpl',
                        DELIMITERS => [ "%%-", "-%%" ]
                        );

my $clgypi = $cltemplate->fill_in(
    HASH => {
        apps_openssl_srcs => \@apps_openssl_srcs,
        lib_defines => \@lib_defines,
        libapps_srcs => \@libapps_srcs,
        config => \%config,
        target => \%target,
        cflags => \@cflags,
        asm => \$asm,
        arch => \$arch,
        lib_cppflags => \@lib_cppflags,
        is_win => \$is_win,
    });

my $cl_path = "$FindBin::Bin/$arch/$asm/openssl-cl.gypi";
make_path(dirname($cl_path));
open(FIPSGYPI, ">", $cl_path) or die "Couldn't open $cl_path: $!";
print CLGYPI "$clgypi";
close(CLGYPI);

# Create meson.build
my $mtemplate =
    Text::Template->new(TYPE => 'FILE',
                        SOURCE => 'meson.build.tmpl',
                        DELIMITERS => [ "%%-", "-%%" ]
                        );

my $meson = $mtemplate->fill_in(
    HASH => {
        libssl_srcs => \@libssl_srcs,
        libssl_def => \$libssl_def,
        libssl_rc => \$libssl_rc,
        libcrypto_srcs => \@libcrypto_srcs,
        libcrypto_def => \$libcrypto_def,
        libcrypto_rc => \$libcrypto_rc,
        generated_srcs => \@generated_srcs,
        apps_openssl_srcs => \@apps_openssl_srcs,
        libapps_srcs => \@libapps_srcs,
        openssl_arch_headers => \@openssl_arch_headers,
        config => \%config,
        target => \%target,
        cflags => \@cflags,
        asm => \$asm,
        arch => \$arch,
        lib_cppflags => \@lib_cppflags,
        is_win => \$is_win,
    });

my $meson_path = "$FindBin::Bin/$arch/$asm/meson.build";
make_path(dirname($meson_path));
open(MESON, ">", $meson_path) or die "Couldn't open $meson_path: $!";
print MESON "$meson";
close(MESON);

# Clean Up
my $cmd2 ="cd $src_dir; make -f $makefile clean; make -f $makefile distclean;" .
    "git clean -f crypto";
system($cmd2) == 0 or die "Error in system($cmd2)";


sub copy_headers {
  my @headers = split / /, $_[0];
  my $inc_dir = $_[1];
  foreach my $header_name (@headers) {
    # Copy the header from OpenSSL source directory to the arch specific dir.
    #print("copy header $src_dir/include/$inc_dir/${header_name}.h to $base_dir/include/$inc_dir \n");
    copy("$src_dir/include/$inc_dir/${header_name}.h",
         "$base_dir/include/$inc_dir/") or die "Copy failed: $!";
   }
}
