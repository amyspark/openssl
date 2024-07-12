project(
  'openssl',
  'c',
  version: '3.0.8',
  license : 'Apache-2.0',
  meson_version: '>= 0.55',
  default_options: [
    'warning_level=1',
  ],
)

# Make sure to generate configs in case they are not already
fs = import('fs')
if not fs.exists('generated-config')
  message('Generating OpenSSL configs...')
  bash = find_program('bash')
  run_command(
    bash,
    'generator.sh',
    check: true,
  )
endif

include_directories = [
  'include',
  'crypto',
  'crypto/modes',
  'crypto/ec/curve448',
  'crypto/ec/curve448/arch_32',
  'providers/common/include',
  'providers/implementations/include',
]

compiler = meson.get_compiler('c')

dependencies = []
defines = [
  # Compile out hardware engines. Most are stubs that dynamically load
  # the real driver but that poses a security liability when an attacker
  # is able to create a malicious DLL in one of the default search paths.
  'OPENSSL_NO_HW',
]
if get_option('threads').allowed()
  dependencies += [dependency('threads')
  defines += ['OPENSSL_THREADS']
endif
c_args = []

asm_opt = get_option('asm')

if asm_opt.disabled()
  new_gas_or_nasm = false
  any_gas_or_nasm = false
else
  new_gas = find_program('as', required: false, version: '>=2.26')
  new_asm = find_program('nasm', required: false, version: '>=2.11.8')
  new_gas_or_nasm = (
    new_gas.found() or
    new_asm.found()
  )
  any_gas = find_program('as', required: false)
  any_nasm = find_program('nasm', required: false)
  any_gas_or_nasm = (
    new_gas_or_nasm or
    any_gas.found() or
    any_nasm.found()
  )
endif

is_msvc_like = ['msvc', 'clang-cl'].contains(compiler.get_id())
is_bsd = host_machine.system() in ['dragonfly', 'freebsd', 'netbsd', 'openbsd']
is_darwin = host_machine.system() in ['darwin', 'ios'] # Unofficial GStreamer
is_linux = host_machine.system() in ['linux', 'android']
is_sunos = host_machine.system() == 'sunos'
is_windows = host_machine.system() == 'windows'

is_x86 = host_machine.cpu_family() == 'x86'
is_x86_64 = host_machine.cpu_family() == 'x86_64'
is_aarch64 = host_machine.cpu_family() == 'aarch64'
is_mips64 = host_machine.cpu_family() == 'mips64'
is_s390x = host_machine.cpu_family() == 's390x'
is_arm = host_machine.cpu_family() == 'arm'
is_ppc = host_machine.cpu_family() == 'ppc'
is_ppc64 = host_machine.cpu_family() == 'ppc64'
is_riskv64 = host_machine.cpu_family() == 'riscv64'

if new_gas_or_nasm
  asm = 'asm'

  # Require AVX512IFMA supported. See
  # https://www.openssl.org/docs/man1.1.1/man3/OPENSSL_ia32cap.html
  # Currently crypto/poly1305/asm/poly1305-x86_64.pl requires AVX512IFMA.
  if is_x86 and is_bsd
    arch_subdir = 'BSD-x86'
  elif is_x86_64 and is_bsd
    arch_subdir = 'BSD-x86_64'
  elif is_aarch64 and is_darwin
    arch_subdir = 'darwin64-arm64-cc'
  elif is_x86_64 and is_darwin
    arch_subdir = 'darwin64-x86_64-cc'
  elif is_x86 and is_darwin
    arch_subdir = 'darwin-i386-cc'
  elif is_mips64 and is_linux
    arch_subdir = 'linux64-mips64'
  elif is_s390x and is_linux
    arch_subdir = 'linux64-s390x'
  elif is_aarch64 and is_linux
    arch_subdir = 'linux-aarch64'
  elif is_arm and is_linux
    arch_subdir = 'linux-armv4'
  elif is_ppc64 and is_linux and host_machine.endian() == 'little'
    arch_subdir = 'linux-ppc64le'
  elif is_ppc64 and is_linux
    arch_subdir = 'linux-ppc64'
  elif is_ppc and is_linux
    arch_subdir = 'linux-ppc'
  elif is_x86 and is_linux
    arch_subdir = 'linux-elf'
  elif is_x86_64 and is_linux
    arch_subdir = 'linux-x86_64'
  elif is_x86_64 and is_sunos
    arch_subdir = 'solaris64-x86_64-gcc'
  elif is_x86 and is_sunos
    arch_subdir = 'solaris-x86-gcc'
  elif is_x86 and is_windows and is_msvc_like and new_asm.found()
    arch_subdir = 'VC-WIN32'
  elif is_x86 and is_windows and not is_msvc_like
    arch_subdir = 'mingw'
  elif is_x86_64 and is_windows and is_msvc_like and new_asm.found()
    arch_subdir = 'VC-WIN64'
  elif is_x86_64 and is_windows and not is_msvc_like
    arch_subdir = 'mingw64'
  else
    asm = 'no-asm'
  endif
elif any_gas_or_nasm
  asm = 'asm_avx2'

  if is_x86 and is_bsd
    arch_subdir = 'BSD-x86'
  elif is_x86_64 and is_bsd
    arch_subdir = 'BSD-x86_64'
  elif is_aarch64 and is_darwin
    arch_subdir = 'darwin64-arm64-cc'
  elif is_x86_64 and is_darwin
    arch_subdir = 'darwin64-x86_64-cc'
  elif is_x86 and is_darwin
    arch_subdir = 'darwin-i386-cc'
  elif is_mips64 and is_linux
    arch_subdir = 'linux64-mips64'
  elif is_s390x and is_linux
    arch_subdir = 'linux64-s390x'
  elif is_aarch64 and is_linux
    arch_subdir = 'linux-aarch64'
  elif is_arm and is_linux
    arch_subdir = 'linux-armv4'
  elif is_ppc64 and is_linux and host_machine.endian() == 'little'
    arch_subdir = 'linux-ppc64le'
  elif is_ppc64 and is_linux
    arch_subdir = 'linux-ppc64'
  elif is_ppc and is_linux
    arch_subdir = 'linux-ppc'
  elif is_x86 and is_linux
    arch_subdir = 'linux-elf'
  elif is_x86_64 and is_linux
    arch_subdir = 'linux-x86_64'
  elif is_x86_64 and is_sunos
    arch_subdir = 'solaris64-x86_64-gcc'
  elif is_x86 and is_sunos
    arch_subdir = 'solaris-x86-gcc'
  elif is_x86 and is_windows and is_msvc_like and new_asm.found()
    arch_subdir = 'VC-WIN32'
  elif is_x86 and is_windows and not is_msvc_like
    arch_subdir = 'mingw'
  elif is_x86_64 and is_windows and is_msvc_like and new_asm.found()
    arch_subdir = 'VC-WIN64'
  elif is_x86_64 and is_windows and not is_msvc_like
    arch_subdir = 'mingw64'
  else
    asm = 'no-asm'
  endif
elif asm_opt.enabled()
  error('Neither GNU Assembler nor Netwide Assembler were found, cannot use use "asm=enabled" option')
else
  asm = 'no-asm'
endif

if asm == 'no-asm'
  defines += ['OPENSSL_NO_ASM']
  error_message = 'Unsupported arch+OS combo: ' + host_machine.cpu_family() + ' + ' + host_machine.system()

  if is_x86 and is_bsd
    arch_subdir = 'BSD-x86'
  elif is_x86_64 and is_bsd
    arch_subdir = 'BSD-x86_64'
  elif is_aarch64 and is_darwin
    arch_subdir = 'darwin64-arm64-cc'
  elif is_x86_64 and is_darwin
    arch_subdir = 'darwin64-x86_64-cc'
  elif is_x86 and is_darwin
    arch_subdir = 'darwin-i386-cc'
  elif is_mips64 and is_linux
    arch_subdir = 'linux64-mips64'
  elif is_riskv64 and is_linux
    arch_subdir = 'linux64-riscv64'
  elif is_s390x and is_linux
    arch_subdir = 'linux64-s390x'
  elif is_aarch64 and is_linux
    arch_subdir = 'linux-aarch64'
  elif is_arm and is_linux
    arch_subdir = 'linux-armv4'
  elif is_ppc64 and is_linux and host_machine.endian() == 'little'
    arch_subdir = 'linux-ppc64le'
  elif is_ppc64 and is_linux
    arch_subdir = 'linux-ppc64'
  elif is_ppc and is_linux
    arch_subdir = 'linux-ppc'
  elif is_x86 and is_linux
    arch_subdir = 'linux-elf'
  elif is_x86_64 and is_linux
    arch_subdir = 'linux-x86_64'
  elif is_x86_64 and is_sunos
    arch_subdir = 'solaris64-x86_64-gcc'
  elif is_x86 and is_sunos
    arch_subdir = 'solaris-x86-gcc'
  elif is_x86 and is_windows and is_msvc_like
      arch_subdir = 'VC-WIN32'
  elif is_x86 and is_windows and not is_msvc_like
    arch_subdir = 'mingw'
  elif is_aarch64 and is_windows
    arch_subdir = 'VC-WIN64-ARM'
  elif is_x86_64 and is_windows and is_msvc_like
    arch_subdir = 'VC-WIN64A'
  elif is_x86_64 and is_windows and not is_msvc_like
    arch_subdir = 'mingw64'
  else
    error(error_message)
  endif

  message('OpenSSL is configured without ASM support')
else
  message('OpenSSL is configured with ASM support')
endif

subdir('include/openssl')

subdir('generated-config/archs' / arch_subdir / asm)

if meson.version().version_compare('>= 0.64')
  if asm != 'no-asm'
    if is_msvc_like
      add_languages('nasm', native: false)
    endif
    libcrypto_sources += libcrypto_asm
  endif
elif asm != 'no-asm'
  if is_msvc_like
    if is_x86_64
      asm_format = 'win64'
    else
      asm_format = 'win32'
    endif
    nasm_generator = generator(
      new_asm,
      output  : '@BASENAME@.obj',
      arguments : ['-f', asm_format, '@INPUT@', '-o', '@OUTPUT@']
    )
    libcrypto_sources += nasm_generator.process(libcrypto_asm)
  else
    libcrypto_sources += libcrypto_asm
  endif
endif

windows = import('windows')

if is_windows
  if libcrypto_rc != ''
    libcrypto_sources += windows.compile_resources(libcrypto_rc)
  endif
  if libssl_rc != ''
    libssl_sources += windows.compile_resources(libssl_rc)
  endif
endif

# Build options specific to OS, engines are disabled on purpose for the same reasons as `OPENSSL_NO_HW` above
if is_windows
  defines += [
    ## default of Win. See INSTALL in openssl repo.
    'OPENSSLDIR="C:\\Program Files\\Common Files\\SSL"',
    'ENGINESDIR="NUL"',
    'OPENSSL_SYS_WIN32', 'WIN32_LEAN_AND_MEAN', 'L_ENDIAN',
    '_CRT_SECURE_NO_DEPRECATE', 'UNICODE', '_UNICODE',
  ]
  if is_msvc_like
    c_args += [
      '-wd4090', '-Gs0', '-GF', '-Gy', '-nologo',
    ]
  elif compiler.get_id() == 'clang'
    c_args += [
      # Silence the defines coming from the architecture folders.
      '-Wno-unused-command-line-argument',
    ]
  endif
elif is_darwin
  defines += [
    'OPENSSLDIR="/System/Library/OpenSSL/"',
    'ENGINESDIR="/dev/null"',
    'MODULESDIR="/dev/null"',
  ]
  c_args += [
    '-Wno-missing-field-initializers',
    '-Wno-unused-command-line-argument'
  ]
elif is_sunos
  defines += [
   'OPENSSLDIR="/etc/ssl"',
   'ENGINESDIR="/dev/null"',
    'MODULESDIR="/dev/null"',
   '__EXTENSIONS__'
 ]
else
  # Linux and others
  defines += [
    'OPENSSLDIR="/etc/ssl"',
    'ENGINESDIR="/dev/null"',
    'MODULESDIR="/dev/null"',
  ]
  c_args += [
    '-Wno-missing-field-initializers',
  ]
  if compiler.get_id() != 'clang'
    c_args += [
      '-Wno-old-style-declaration',
    ]
  else
    c_args += [
      '-Wno-unused-command-line-argument',
    ]
  endif
endif

foreach library: openssl_libraries
  # MSVC fails with "ERROR: C static library 'ws2_32' not found" when `static` is specified at all
  if is_msvc_like
    dependencies += [
      compiler.find_library(library),
    ]
  else
    dependencies += [
      compiler.find_library(
        library,
        static: get_option('default_library') == 'static',
      ),
    ]
  endif
endforeach

# We may need to add some defines for static builds
if get_option('default_library') == 'static'
  defines += [
    'OSSL_CRYPTO_DSO_CONF_H',
    'DSO_NONE',
    'DSO_EXTENSION=".so"',
    'OPENSSL_NO_DSO',
  ]
endif

foreach define : defines + openssl_defines
  c_args += ['-D@0@'.format(define)]
endforeach

c_args += openssl_cflags

include_directories += openssl_include_directories

openssl_library_version = meson.project_version().substring(0, -1)

version_components = openssl_library_version.split('.')

openssl_so_version = '.'.join([version_components[0], version_components[1]])

if is_msvc_like
  openssl_library_prefix = 'lib'
else
  openssl_library_prefix = []
endif

if is_msvc_like
  msvc_version = compiler.get_define('_MSC_VER')
  # Block build if the linker gets a renaming directive.
  if msvc_version.version_compare('>=1930')
    link_args = ['/WX:4070']
  else
    link_args = ['/WX']
  endif
else
  link_args = []
endif

if libcrypto_def != ''
  libcrypto_lib = library(
    'crypto',
    dependencies: dependencies,
    sources: libcrypto_sources,
    include_directories: include_directories,
    vs_module_defs: libcrypto_def,
    c_args: c_args,
    link_args: link_args,
    name_prefix: openssl_library_prefix,
    version: openssl_library_version,
    soversion: openssl_so_version,
    install: true,
  )
else
  libcrypto_lib = library(
    'crypto',
    dependencies: dependencies,
    sources: libcrypto_sources,
    include_directories: include_directories,
    c_args: c_args,
    link_args: link_args,
    name_prefix: openssl_library_prefix,
    version: openssl_library_version,
    soversion: openssl_so_version,
    install: true,
  )
endif

libcrypto_dep = declare_dependency(
  include_directories: include_directories,
  dependencies: dependencies,
  link_with: libcrypto_lib,
)

if libcrypto_def != ''
  libssl_lib = library(
    'ssl',
    dependencies: dependencies + [libcrypto_dep],
    sources: libssl_sources,
    include_directories: include_directories,
    vs_module_defs: libssl_def,
    c_args: c_args,
    link_args: link_args,
    name_prefix: openssl_library_prefix,
    version: openssl_library_version,
    soversion: openssl_so_version,
    install: true,
  )
else
  libssl_lib = library(
    'ssl',
    dependencies: dependencies + [libcrypto_dep],
    sources: libssl_sources,
    include_directories: include_directories,
    c_args: c_args,
    link_args: link_args,
    name_prefix: openssl_library_prefix,
    version: openssl_library_version,
    soversion: openssl_so_version,
    install: true,
  )
endif

libssl_dep = declare_dependency(
  include_directories: include_directories,
  dependencies: dependencies + [libcrypto_dep],
  link_with: libssl_lib,
)

openssl_dep = declare_dependency(
  dependencies: [libcrypto_dep, libssl_dep],
)

openssl_cli_directories = include_directories + [
  'apps/include'
]

cli_opt = get_option('build_cli')

openssl_cli = executable(
  'openssl',
  build_by_default: cli_opt,
  dependencies: dependencies + [openssl_dep],
  sources: openssl_cli_sources,
  include_directories: openssl_cli_directories,
  c_args: c_args,
  install: cli_opt,
)

install_headers(
  openssl_headers + openssl_arch_headers,
  subdir: 'openssl'
)

pkg = import('pkgconfig')
openssl_pc = pkg.generate(
  name: 'OpenSSL',
  description: 'Secure Sockets Layer and cryptography libraries and tools',
  libraries: [libssl_lib, libcrypto_lib]
)
