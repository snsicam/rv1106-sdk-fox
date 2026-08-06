################################################################################
#
# python-numpy
#
################################################################################

PYTHON_NUMPY_VERSION = 1.24.3
PYTHON_NUMPY_SOURCE = numpy-$(PYTHON_NUMPY_VERSION).tar.gz
PYTHON_NUMPY_SITE = https://files.pythonhosted.org/packages/source/n/numpy
PYTHON_NUMPY_SETUP_TYPE = setuptools
PYTHON_NUMPY_LICENSE = BSD-3-Clause
PYTHON_NUMPY_LICENSE_FILES = LICENSE.txt

# 不需要显式依赖 openblas（可选，如果系统中没有 openblas 可以删除）
PYTHON_NUMPY_DEPENDENCIES = 

# 删除自定义的 CONFIGURE_CMDS 部分（如果有）
# 让 Buildroot 自动执行 setup.py build

$(eval $(python-package))
$(eval $(host-python-package))
