/*
 * pi3's Linux kernel Runtime Guard
 *
 * Component:
 *  - Handle *_JUMP_LABEL self-modifying code.
 *    Hook 'arch_jump_label_transform' function.
 *
 * Notes:
 *  - Linux kernel is heavily consuming *_JUMP_LABEL (if enabled). Most of the
 *    Linux distributions provide kernel with these options compiled. It makes
 *    Linux kernel being self-modifying code. It is very troublesome for this
 *    project. We are relying on comparing hashes from the specific memory
 *    regions and by design self-modifications break this functionality.
 *  - We are hooking into low-level *_JUMP_LABEL functions to be able to
 *    monitor whenever new modification is on the way.
 *
 * Caveats:
 *  - None
 *
 * Timeline:
 *  - Created: 28.I.2019
 *
 * Author:
 *  - Adam 'pi3' Zabrocki (http://pi3.com.pl)
 *
 */

#include "../../../../p_lkrg_main.h"
#include "../../../exploit_detection/syscalls/p_install.h"

p_lkrg_counter_lock p_jl_lock;


static notrace int p_arch_jump_label_transform_entry(struct kretprobe_instance *p_ri, struct pt_regs *p_regs) {

   struct jump_entry *p_tmp = (struct jump_entry *)p_regs_get_arg1(p_regs);
   unsigned long p_addr = p_jump_entry_code(p_tmp);
   struct module *p_module = NULL;

   p_debug_kprobe_log(
          "p_arch_jump_label_transform_entry: comm[%s] Pid:%d",current->comm,current->pid);

   do {
      p_lkrg_counter_lock_lock(&p_jl_lock);
      if (!p_lkrg_counter_lock_val_read(&p_jl_lock))
         break;
      p_lkrg_counter_lock_unlock(&p_jl_lock);
      cpu_relax();
   } while(1);
   p_lkrg_counter_lock_val_inc(&p_jl_lock);
   p_lkrg_counter_lock_unlock(&p_jl_lock);

   p_print_log(P_LOG_WATCH,
               "[JUMP_LABEL] New modification: type[%s] code[0x%lx] target[0x%lx] key[0x%lx]!",
               (p_regs_get_arg2(p_regs) == 1) ? "JUMP_LABEL_JMP" :
                                                (p_regs_get_arg2(p_regs) == 0) ? "JUMP_LABEL_NOP" :
                                                                                 "UNKNOWN",
               p_jump_entry_code(p_tmp),
               p_jump_entry_target(p_tmp),
               (unsigned long)p_jump_entry_key(p_tmp));

   if (P_SYM(p_core_kernel_text)(p_addr)) {
      /*
       * OK, *_JUMP_LABEL tries to modify kernel core .text section
       */
      p_db.p_jump_label.p_state = P_JUMP_LABEL_CORE_TEXT;
   } else if ( (p_module = LKRG_P_MODULE_TEXT_ADDRESS(p_addr)) != NULL) {
      /*
       * OK, *_JUMP_LABEL tries to modify some module's .text section
       */
      p_db.p_jump_label.p_state = P_JUMP_LABEL_MODULE_TEXT;
      p_db.p_jump_label.p_mod = p_module;
   } else {
      /*
       * FTRACE might generate dynamic trampoline which is not part of .text section.
       * This is not abnormal situation anymore.
       */
      p_print_log(P_LOG_WATCH,
                  "[JUMP_LABEL] Not a .text section! [0x%lx]",p_addr);
      p_db.p_jump_label.p_state = P_JUMP_LABEL_WTF_STATE;
   }

   /* A dump_stack() here will give a stack backtrace */
   return 0;
}


static notrace int p_arch_jump_label_transform_ret(struct kretprobe_instance *ri, struct pt_regs *p_regs) {

   unsigned int p_tmp,p_tmp2;
   unsigned char p_flag = 0;

   switch (p_db.p_jump_label.p_state) {

      case P_JUMP_LABEL_CORE_TEXT:

         /*
          * We do not require to take any locks neither to copy entire .text section to temporary memory
          * since at this state it is static. Just recompute the hash.
          */
         p_db.kernel_stext.p_hash = p_lkrg_fast_hash((unsigned char *)p_db.kernel_stext.p_addr,
                                                     (unsigned int)p_db.kernel_stext.p_size);

#if defined(P_LKRG_JUMP_LABEL_STEXT_DEBUG)
         memcpy(p_db.kernel_stext_copy,p_db.kernel_stext.p_addr,p_db.kernel_stext.p_size);
         p_db.kernel_stext_copy[p_db.kernel_stext.p_size] = 0;
#endif

         p_print_log(P_LOG_WATCH,
                     "[JUMP_LABEL] Updating kernel core .text section hash!");

         break;

      case P_JUMP_LABEL_MODULE_TEXT:

         for (p_tmp = 0; p_tmp < p_db.p_module_list_nr; p_tmp++) {
            if (p_db.p_module_list_array[p_tmp].p_mod == p_db.p_jump_label.p_mod) {
               /*
                * OK, we found this module on our internal tracking list.
                * Update it's hash
                */

               p_print_log(P_LOG_WATCH,
                      "[JUMP_LABEL] Updating module's core .text section hash module[%s : 0x%lx]!",
                      p_db.p_module_list_array[p_tmp].p_name,
                      (unsigned long)p_db.p_module_list_array[p_tmp].p_mod);

               p_db.p_module_list_array[p_tmp].p_mod_core_text_hash =
                    p_lkrg_fast_hash((unsigned char *)p_db.p_module_list_array[p_tmp].p_module_core,
                                     (unsigned int)p_db.p_module_list_array[p_tmp].p_core_text_size);
               /*
                * Because we have modified individual module's hash, we need to update
                * 'global' module's list hash as well
                */
               p_db.p_module_list_hash = p_lkrg_fast_hash((unsigned char *)p_db.p_module_list_array,
                                                          (unsigned int)p_db.p_module_list_nr * sizeof(p_module_list_mem));

               /*
                * Because we update module's .text section hash we need to update KOBJs as well.
                */
               p_flag = 0;
               for (p_tmp2 = 0; p_tmp2 < p_db.p_module_kobj_nr; p_tmp2++) {
                  if (p_db.p_module_kobj_array[p_tmp2].p_mod == p_db.p_jump_label.p_mod) {
                     p_db.p_module_kobj_array[p_tmp2].p_mod_core_text_hash =
                                      p_db.p_module_list_array[p_tmp].p_mod_core_text_hash;
                     p_flag = 1;
                     break;
                  }
               }

               if (!p_flag) {
                  p_print_log(P_LOG_FAULT,
                              "[JUMP_LABEL] Updated module's list hash for module[%s] but can't find the same module in KOBJs list!",
                              p_db.p_module_list_array[p_tmp].p_name);
                  p_print_log(P_LOG_WATCH,"module[%s : 0x%lx]!",
                              p_db.p_module_list_array[p_tmp].p_name,
                              (unsigned long)p_db.p_module_list_array[p_tmp].p_mod);
               } else {

                  /*
                   * Because we have modified individual module's hash, we need to update
                   * 'global' module's list hash as well
                   */
                  p_db.p_module_kobj_hash = p_lkrg_fast_hash((unsigned char *)p_db.p_module_kobj_array,
                                                             (unsigned int)p_db.p_module_kobj_nr * sizeof(p_module_kobj_mem));
               }
               break;
            }
         }
         break;

      case P_JUMP_LABEL_WTF_STATE:
      default:
         /*
          * FTRACE might generate dynamic trampoline which is not part of .text section.
          * This is not abnormal situation anymore.
          */
         break;
   }

   p_db.p_jump_label.p_state = P_JUMP_LABEL_NONE;

   p_lkrg_counter_lock_val_dec(&p_jl_lock);

   return 0;
}

static struct lkrg_probe p_arch_jump_label_transform_probe = {
  .type = LKRG_KRETPROBE,
  .krp = {
#if defined(CONFIG_ARM64) && defined(HAVE_JUMP_LABEL_BATCH)
    .kp.symbol_name = "arch_jump_label_transform_queue",
#else
    .kp.symbol_name = "arch_jump_label_transform",
#endif
    .handler = p_arch_jump_label_transform_ret,
    .entry_handler = p_arch_jump_label_transform_entry,
  }
};

GENERATE_INSTALL_FUNC(arch_jump_label_transform)
