ifneq ($(KERNELRELEASE),)
	obj-m := mem.o

else
	KERNELDIR := /lib/modules/$(shell uname -r)/build
	PWD := $(shell pwd)

default:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules
clean:
	rm -rf ./.mem* .tmp_versions Module.markers Module.symvers Modules.symvers modules.order mem.ko mem.mod.c mem.mod.o mem.o
endif
