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

# 对于 ARM 架构，使用环境变量禁用 C 扩展
ifeq ($(BR2_arm)$(BR2_armeb),y)
#PYTHON_STREAMING_FORM_DATA_ENV = STREAMING_FORM_DATA_PURE_PYTHON=1
endif

$(eval $(python-package))
