/*
 * iospatch.c
 * IOS patching to preserve AHBPROT through IOS reload
 *
 * Based on work by davebaol and tueidj
 * https://gbatemp.net/threads/how-to-fix-the-connection-issue-while-running-in-ahbprot-mode.301061/
 * https://github.com/FIX94/Some-YAWMM-Mod/blob/master/source/iospatch.c
 */

#include <stdio.h>
#include <string.h>
#include <ogcsys.h>
#include <gccore.h>
#include <ogc/machine/processor.h>
#include "iospatch.h"

// Memory protection register
#define MEM_PROT 0x0D8B420A

// ES set_ahbprot pattern - searches for the code that checks TMD access rights
static const u8 es_set_ahbprot_pattern[] = {
    0x68, 0x5B, 0x22, 0xEC, 0x00, 0x52, 0x18, 0x9B,
    0x68, 0x1B, 0x46, 0x98, 0x07, 0xDB
};

// Patch byte - forces AHBPROT to be enabled
static const u8 es_set_ahbprot_patch[] = { 0x01 };

// ISFS permissions pattern
static const u8 isfs_perms_pattern[] = {
    0x42, 0x8B, 0xD0, 0x01, 0x25, 0x66
};
static const u8 isfs_perms_patch[] = { 0xE0 };

// Helper to disable memory protection
static void disable_memory_protection(void) {
    write32(MEM_PROT, read32(MEM_PROT) & 0x0000FFFF);
}

// Search IOS memory and apply patch
static u32 apply_patch(const char* name, const u8* pattern, u32 pattern_size,
                       const u8* patch, u32 patch_size, u32 patch_offset) {
    u8* ptr_start = (u8*)*((u32*)0x80003134);
    u8* ptr_end = (u8*)0x94000000;
    u32 found = 0;

    while (ptr_start < (ptr_end - pattern_size)) {
        if (memcmp(ptr_start, pattern, pattern_size) == 0) {
            found++;
            u8* location = ptr_start + patch_offset;

            // Apply the patch
            for (u32 i = 0; i < patch_size; i++) {
                location[i] = patch[i];
            }

            // Flush cache
            DCFlushRange((u8*)(((u32)location) >> 5 << 5), (patch_size >> 5 << 5) + 64);
            ICInvalidateRange((u8*)(((u32)location) >> 5 << 5), (patch_size >> 5 << 5) + 64);
        }
        ptr_start++;
    }

    return found;
}

u32 iospatch_ahbprot(void) {
    if (AHBPROT_DISABLED) {
        disable_memory_protection();
        return apply_patch("es_set_ahbprot",
                          es_set_ahbprot_pattern, sizeof(es_set_ahbprot_pattern),
                          es_set_ahbprot_patch, sizeof(es_set_ahbprot_patch),
                          25);  // Patch offset is 25 bytes from pattern start
    }
    return 0;
}

u32 iospatch_isfs_permissions(void) {
    if (AHBPROT_DISABLED) {
        disable_memory_protection();
        return apply_patch("isfs_permissions",
                          isfs_perms_pattern, sizeof(isfs_perms_pattern),
                          isfs_perms_patch, sizeof(isfs_perms_patch),
                          0);
    }
    return 0;
}
