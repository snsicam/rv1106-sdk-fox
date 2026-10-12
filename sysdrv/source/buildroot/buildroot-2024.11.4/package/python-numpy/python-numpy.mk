################################################################################
#
# python-numpy
#
################################################################################

PYTHON_NUMPY_VERSION = 1.26.4
PYTHON_NUMPY_SOURCE = numpy-$(PYTHON_NUMPY_VERSION).tar.gz
PYTHON_NUMPY_SITE = https://github.com/numpy/numpy/releases/download/v$(PYTHON_NUMPY_VERSION)
PYTHON_NUMPY_LICENSE = BSD-3-Clause, MIT, Zlib
PYTHON_NUMPY_LICENSE_FILES = \
	LICENSE.txt \
	numpy/core/src/multiarray/dragon4.c \
	numpy/core/include/numpy/libdivide/LICENSE.txt \
	numpy/linalg/lapack_lite/LICENSE.txt \
	tools/npy_tempita/license.txt
PYTHON_NUMPY_CPE_ID_VENDOR = numpy
PYTHON_NUMPY_CPE_ID_PRODUCT = numpy

# numpy 1.26 的构建后端是 meson-python，且 numpy 在 sdist 中自带一份
# vendored-meson（基于 meson 1.2.99，带有 mainline meson 没有的 'features' 模块，
# 用于 CPU dispatcher）。buildroot 的 host-meson(1.6.0) 没有该模块，直接用它构建会
# 报 "Module features does not exist"。因此这里覆盖 CONFIGURE_CMDS，改用 numpy 自带的
# vendored meson 来 setup，编译/安装仍走标准 ninja。
PYTHON_NUMPY_DEPENDENCIES = host-python-cython python3

PYTHON_NUMPY_CONF_ENV += \
	PYTHONNOUSERSITE=y \
	_PYTHON_SYSCONFIGDATA_NAME=$(PKG_PYTHON_SYSCONFIGDATA_NAME) \
	PYTHONPATH=$(PYTHON3_PATH)

ifeq ($(BR2_PACKAGE_LAPACK),y)
PYTHON_NUMPY_DEPENDENCIES += lapack
PYTHON_NUMPY_CONF_OPTS += -Dlapack=lapack
else
PYTHON_NUMPY_CONF_OPTS += -Dlapack=""
endif

ifeq ($(BR2_PACKAGE_OPENBLAS),y)
PYTHON_NUMPY_DEPENDENCIES += openblas
PYTHON_NUMPY_CONF_OPTS += -Dblas=openblas
else
PYTHON_NUMPY_CONF_OPTS += -Dblas=""
endif

# 不引入 host-blas/host-lapack，使用 numpy 内置的未优化实现。
HOST_PYTHON_NUMPY_CONF_OPTS = -Dblas="" -Dlapack=""
HOST_PYTHON_NUMPY_DEPENDENCIES = host-python-cython
# buildroot 装到 host/lib/pkgconfig 的 python-3.12.pc 是给交叉编译用的（Cflags/Libs
# 被 sysroot 重映射成一串坏路径），native 构建若让它走 pkg-config 会找不到 Python.h。
# 这里直接用 CPATH/LIBRARY_PATH 指向 host python3 真实头文件/库目录绕过它。
HOST_PYTHON_NUMPY_CONF_ENV = PYTHONNOUSERSITE=y \
	CPATH=$(HOST_DIR)/include/python$(PYTHON3_VERSION_MAJOR)
HOST_PYTHON_NUMPY_NINJA_ENV = \
	CPATH=$(HOST_DIR)/include/python$(PYTHON3_VERSION_MAJOR) \
	LIBRARY_PATH=$(HOST_DIR)/lib

# 本 SDK 的交叉工具链为 gcc 8.3.0，而 numpy 1.26 要求 gcc >= 8.4（该下限主要针对
# x86 AVX512 的 gcc 8.3 缺陷，ARM cortex-a7 不触发），放宽为 >= 8.0 以通过版本检查。
# 另外本 uClibc 整体未开启 complex 支持，libm 既无 csin 等复数函数、也无 creal/cimag/
# conj 宏，而 numpy 把它们全列为 mandatory 导致硬失败；这些 numpy 自身在 npy_math 里
# 有内置实现，故把整组从 mandatory 列表移除（留下空数组即可）。
define PYTHON_NUMPY_RELAX_GCC_VERSION
	$(SED) "s/>=8.4/>=8.0/g" $(@D)/meson.build
	$(SED) "s/'csin', 'csinh', 'ccos', 'ccosh', 'ctan', 'ctanh', //g" $(@D)/numpy/core/meson.build
	$(SED) "s/'creal', 'cimag', 'conj'//g" $(@D)/numpy/core/meson.build
endef
PYTHON_NUMPY_POST_PATCH_HOOKS += PYTHON_NUMPY_RELAX_GCC_VERSION

# 本 uClibc 工具链没有 <fenv.h>，numpy 的浮点状态/舍入代码（ieee754.c.src、
# float_status.hpp）无条件 #include <fenv.h> 会编译失败。提供桩 fenv.h 放到 numpy
# 内部 include 目录（所有 numpy 目标都带 -Inumpy/core/include，且系统无 fenv.h，
# 故 <fenv.h> 必然解析到本桩），浮点异常/舍入控制变为 no-op，对 klipper 无影响。
define PYTHON_NUMPY_ADD_FENV_STUB
	$(INSTALL) -D -m 0644 $(PYTHON_NUMPY_PKGDIR)/fenv_stub.h \
		$(@D)/numpy/core/include/fenv.h
endef
PYTHON_NUMPY_POST_PATCH_HOOKS += PYTHON_NUMPY_ADD_FENV_STUB

# 覆盖 configure：用 numpy 自带的 vendored meson 替代 host-meson。
define PYTHON_NUMPY_CONFIGURE_CMDS
	rm -rf $(@D)/build
	mkdir -p $(@D)/build
	sed -e "/^\[binaries\]$$/s:$$:$(foreach x,$(PYTHON_NUMPY_MESON_EXTRA_BINARIES),\n$(x)):" \
	    -e "/^\[properties\]$$/s:$$:$(foreach x,$(PYTHON_NUMPY_MESON_EXTRA_PROPERTIES),\n$(x)):" \
	    -e "/^\[properties\]$$/a longdouble_format = 'IEEE_DOUBLE_LE'" \
	    $(call PKG_MESON_CROSSCONFIG_SED,TARGET_CFLAGS,TARGET_CXXFLAGS,TARGET_LDFLAGS,TARGET_FCFLAGS) \
	    > $(@D)/build/cross-compilation.conf
	PATH=$(BR_PATH) \
	CC_FOR_BUILD="$(HOSTCC)" \
	CXX_FOR_BUILD="$(HOSTCXX)" \
	$(PYTHON_NUMPY_CONF_ENV) \
	$(HOST_DIR)/bin/python3 $(@D)/vendored-meson/meson/meson.py setup \
		--prefix=/usr \
		--libdir=lib \
		--default-library=$(PKG_MESON_DEFAULT_LIBRARY) \
		--buildtype=$(if $(BR2_ENABLE_RUNTIME_DEBUG),debug,release) \
		--cross-file=$(@D)/build/cross-compilation.conf \
		-Db_pie=false \
		-Db_staticpic=$(if $(BR2_m68k_cf),false,true) \
		-Dstrip=false \
		-Dbuild.pkg_config_path=$(HOST_DIR)/lib/pkgconfig \
		-Dbuild.cmake_prefix_path=$(HOST_DIR)/lib/cmake \
		$(PYTHON_NUMPY_CONF_OPTS) \
		$(@D) $(@D)/build
endef

# host 版同样要避开 host-meson(1.6.0) 缺 features 模块的问题：用 numpy 自带
# vendored meson 做 native 构建（无 cross-file）。host 有真正的 <fenv.h> 与复数支持，
# 故上文的 fenv 桩 / 复数移除对 host 无害；long double 交给 numpy 自行 cc.run() 探测，
# 不要注入 IEEE_DOUBLE_LE（那是 ARM 小端的特例，x86_64 host 是 80-bit 扩展精度）。
define HOST_PYTHON_NUMPY_CONFIGURE_CMDS
	rm -rf $(@D)/build
	mkdir -p $(@D)/build
	PATH=$(BR_PATH) \
	$(HOST_PYTHON_NUMPY_CONF_ENV) \
	$(HOST_DIR)/bin/python3 $(@D)/vendored-meson/meson/meson.py setup \
		--prefix=$(HOST_DIR) \
		--libdir=lib \
		--default-library=shared \
		--buildtype=release \
		-Db_pie=false \
		-Db_staticpic=true \
		-Dstrip=false \
		$(HOST_PYTHON_NUMPY_CONF_OPTS) \
		$(@D) $(@D)/build
endef

# 修正 npymath.ini 的 prefix 路径，指向真正构建 numpy core 的 staging 目录，
# 否则依赖 numpy distutils 扩展（scipy 等）会因找不到 -lnpymath 而失败。
define PYTHON_NUMPY_FIXUP_NPY_PKG_CONFIG_FILES
	$(SED) '/^pkgdir=/d;/^prefix=/i pkgdir=$(PYTHON3_PATH)/site-packages/numpy/core' \
		$(PYTHON3_PATH)/site-packages/numpy/core/lib/npy-pkg-config/npymath.ini
endef
PYTHON_NUMPY_POST_INSTALL_STAGING_HOOKS += PYTHON_NUMPY_FIXUP_NPY_PKG_CONFIG_FILES

# 有些包会包含 NumPy 的头文件，安装到 staging 区。
PYTHON_NUMPY_INSTALL_STAGING = YES

# target 与 host 都要构建：matplotlib 的 meson 配置阶段会 import numpy 生成代码，
# 依赖 host-python-numpy；恢复 host 变体并用 vendored meson 规避 features 缺失。
$(eval $(meson-package))
$(eval $(host-meson-package))
