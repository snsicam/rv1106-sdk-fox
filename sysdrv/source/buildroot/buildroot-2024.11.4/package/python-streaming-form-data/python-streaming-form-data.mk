################################################################################
#
# python-streaming-form-data
#
################################################################################

PYTHON_STREAMING_FORM_DATA_VERSION = 1.11.0
PYTHON_STREAMING_FORM_DATA_SOURCE = streaming-form-data-$(PYTHON_STREAMING_FORM_DATA_VERSION).tar.gz
PYTHON_STREAMING_FORM_DATA_SITE = https://files.pythonhosted.org/packages/2c/6c/a6666cadf14b7bcb27f214a2325b9c72a35a0f3f3f4fbcda3890e53488468
PYTHON_STREAMING_FORM_DATA_SETUP_TYPE = setuptools
PYTHON_STREAMING_FORM_DATA_LICENSE = MIT
PYTHON_STREAMING_FORM_DATA_LICENSE_FILES = LICENSE

# 1.11.0 自带的 _parser.c 由旧版 Cython 生成，使用了 Python 3.12 已移除的
# C API（PyLongObject.ob_digit、PyThreadState.curexc_traceback 等），无法在
# buildroot 2024.11 默认的 Python 3.12 目标上编译。用 2.1.0 由 Cython 3 重新
# 生成、兼容 Python 3.12 的 _parser.c 覆盖它（Python 层接口保持 1.11.0 不变，
# 不引入 2.x 新增的 smart_open/aiofiles 运行依赖）。
define PYTHON_STREAMING_FORM_DATA_FIX_PY312_CEXT
	cp -f $(PYTHON_STREAMING_FORM_DATA_PKGDIR)/_parser_py312.c \
		$(@D)/streaming_form_data/_parser.c
endef
PYTHON_STREAMING_FORM_DATA_POST_EXTRACT_HOOKS += PYTHON_STREAMING_FORM_DATA_FIX_PY312_CEXT

$(eval $(python-package))
