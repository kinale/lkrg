##
# Makefile for LKRG (main branch)
#
# Author:
#  - Adam 'pi3' Zabrocki (http://pi3.com.pl)
##

P_OUTPUT = output
P_PWD ?= $(shell pwd)
P_KVER ?= $(shell uname -r)
P_BOOTUP_SCRIPT ?= scripts/bootup/lkrg-bootup.sh
TARGET := lkrg
ifneq ($(KERNELRELEASE),)
    KERNEL := /lib/modules/$(KERNELRELEASE)/build
else
    ## KERNELRELEASE not set.
    KERNEL := /lib/modules/$(P_KVER)/build
endif

#
# Use DEBUG=on for debug build.
#
ifeq ($(DEBUG), on)
ccflags-m := -ggdb -DP_LKRG_DEBUG_BUILD -finstrument-functions
ccflags-y := ${ccflags-m}
$(TARGET)-objs += src/modules/print_log/p_lkrg_debug_log.o
endif

obj-m += $(TARGET).o
$(TARGET)-objs += src/modules/ksyms/p_resolve_ksym.o \
                  src/modules/hashing/p_lkrg_fast_hash.o \
                  src/modules/comm_channel/p_comm_channel.o \
                  src/modules/integrity_timer/p_integrity_timer.o \
                  src/modules/integrity_timer/verify_kprobes/p_verify_kprobes.o \
                  src/modules/kmod/p_kmod.o \
                  src/modules/net/net.o \
                  src/modules/database/CPU.o \
                  src/modules/database/arch/x86/p_x86_metadata.o \
                  src/modules/database/arch/x86/p_switch_idt/p_switch_idt.o \
                  src/modules/database/arch/arm64/p_arm64_metadata.o \
                  src/modules/database/arch/arm/p_arm_metadata.o \
                  src/modules/database/arch/p_arch_metadata.o \
                  src/modules/database/JUMP_LABEL/p_arch_jump_label_transform/p_arch_jump_label_transform.o \
                  src/modules/database/JUMP_LABEL/p_arch_jump_label_transform_apply/p_arch_jump_label_transform_apply.o \
                  src/modules/database/FTRACE/p_ftrace_modify_all_code/p_ftrace_modify_all_code.o \
                  src/modules/database/FTRACE/p_ftrace_enable_sysctl/p_ftrace_enable_sysctl.o \
                  src/modules/database/TRACEPOINT/p_arch_static_call_transform/p_arch_static_call_transform.o \
                  src/modules/database/p_database.o \
                  src/modules/notifiers/p_notifiers.o \
                  src/modules/self-defense/hiding/p_hiding.o \
                  src/modules/exploit_detection/ed_task_tree.o \
                  src/modules/exploit_detection/syscalls/p_install.o \
                  src/modules/exploit_detection/syscalls/exec/p_security_bprm_committing_creds/p_security_bprm_committing_creds.o \
                  src/modules/exploit_detection/syscalls/exec/p_security_bprm_committed_creds/p_security_bprm_committed_creds.o \
                  src/modules/exploit_detection/syscalls/p_call_usermodehelper/p_call_usermodehelper.o \
                  src/modules/exploit_detection/syscalls/p_call_usermodehelper_exec/p_call_usermodehelper_exec.o \
                  src/modules/exploit_detection/syscalls/p_do_exit/p_do_exit.o \
                  src/modules/exploit_detection/syscalls/p_wake_up_new_task/p_wake_up_new_task.o \
                  src/modules/exploit_detection/syscalls/p_sys_setuid/p_sys_setuid.o \
                  src/modules/exploit_detection/syscalls/p_sys_setreuid/p_sys_setreuid.o \
                  src/modules/exploit_detection/syscalls/p_sys_setresuid/p_sys_setresuid.o \
                  src/modules/exploit_detection/syscalls/p_sys_setfsuid/p_sys_setfsuid.o \
                  src/modules/exploit_detection/syscalls/p_sys_setgid/p_sys_setgid.o \
                  src/modules/exploit_detection/syscalls/p_sys_setregid/p_sys_setregid.o \
                  src/modules/exploit_detection/syscalls/p_sys_setresgid/p_sys_setresgid.o \
                  src/modules/exploit_detection/syscalls/p_sys_setfsgid/p_sys_setfsgid.o \
                  src/modules/exploit_detection/syscalls/p_set_current_groups/p_set_current_groups.o \
                  src/modules/exploit_detection/syscalls/p_generic_permission/p_generic_permission.o \
                  src/modules/exploit_detection/syscalls/p_sel_write_enforce/p_sel_write_enforce.o \
                  src/modules/exploit_detection/syscalls/p_seccomp/p_seccomp.o \
                  src/modules/exploit_detection/syscalls/p_sys_unshare/p_sys_unshare.o \
                  src/modules/exploit_detection/syscalls/p_sys_setns/p_sys_setns.o \
                  src/modules/exploit_detection/syscalls/caps/p_sys_capset/p_sys_capset.o \
                  src/modules/exploit_detection/syscalls/caps/p_cap_task_prctl/p_cap_task_prctl.o \
                  src/modules/exploit_detection/syscalls/keyring/p_key_change_session_keyring/p_key_change_session_keyring.o \
                  src/modules/exploit_detection/syscalls/keyring/p_sys_add_key/p_sys_add_key.o \
                  src/modules/exploit_detection/syscalls/keyring/p_sys_request_key/p_sys_request_key.o \
                  src/modules/exploit_detection/syscalls/keyring/p_sys_keyctl/p_sys_keyctl.o \
                  src/modules/exploit_detection/syscalls/p_security_ptrace_access/p_security_ptrace_access.o \
                  src/modules/exploit_detection/syscalls/compat/p_compat_sys_keyctl/p_compat_sys_keyctl.o \
                  src/modules/exploit_detection/syscalls/compat/p_compat_sys_capset/p_compat_sys_capset.o \
                  src/modules/exploit_detection/syscalls/compat/p_compat_sys_add_key/p_compat_sys_add_key.o \
                  src/modules/exploit_detection/syscalls/compat/p_compat_sys_request_key/p_compat_sys_request_key.o \
                  src/modules/exploit_detection/syscalls/__x32/p_x32_sys_keyctl/p_x32_sys_keyctl.o \
                  src/modules/exploit_detection/syscalls/override/p_override_creds/p_override_creds.o \
                  src/modules/exploit_detection/syscalls/override/p_revert_creds/p_revert_creds.o \
                  src/modules/exploit_detection/syscalls/override/overlayfs/p_ovl_override_sync/p_ovl_override_sync.o \
                  src/modules/exploit_detection/syscalls/pCFI/p_mark_inode_dirty/p_mark_inode_dirty.o \
                  src/modules/exploit_detection/syscalls/pCFI/p_schedule/p_schedule.o \
                  src/modules/exploit_detection/syscalls/pCFI/p___queue_work/p___queue_work.o \
                  src/modules/exploit_detection/syscalls/pCFI/p_lookup_fast/p_lookup_fast.o \
                  src/modules/exploit_detection/syscalls/p_capable/p_capable.o \
                  src/modules/exploit_detection/syscalls/p_scm_send/p_scm_send.o \
                  src/modules/exploit_detection/p_selinux_state.o \
                  src/modules/exploit_detection/p_exploit_detection.o \
                  src/p_lkrg_main.o


all:
#	$(MAKE) -C $(KERNEL) M=$(P_PWD) modules CONFIG_DEBUG_SECTION_MISMATCH=y
	$(MAKE) -C $(KERNEL) M=$(P_PWD) modules
	mkdir -p $(P_OUTPUT)
	cp $(P_PWD)/$(TARGET).ko $(P_OUTPUT)

install-module: all
	$(MAKE) -C $(KERNEL) M=$(P_PWD) modules_install

install: install-module
	depmod $(KERNELRELEASE)
	$(P_PWD)/$(P_BOOTUP_SCRIPT) install

uninstall:
	$(P_PWD)/$(P_BOOTUP_SCRIPT) uninstall

clean:
	$(MAKE) -C $(KERNEL) M=$(P_PWD) clean
	$(RM) Module.markers modules.order
	$(RM) $(P_PWD)/src/modules/kmod/client/kmod/Module.markers
	$(RM) $(P_PWD)/src/modules/kmod/client/kmod/modules.order
	$(RM) -rf $(P_OUTPUT)

.PHONY: clean uninstall install install-module all
