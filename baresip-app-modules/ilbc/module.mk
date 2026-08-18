#
# module.mk
#
# Copyright (C) 2026 Juha Heinanen
#

MOD		:= ilbc
$(MOD)_SRCS	+= ilbc.c

$(MOD)_LFLAGS	+= -lilbc

include mk/mod.mk
