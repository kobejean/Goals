/*
 * iospatch.h
 * IOS patching to preserve AHBPROT through IOS reload
 *
 * Based on work by davebaol and FIX94
 * https://gbatemp.net/threads/how-to-fix-the-connection-issue-while-running-in-ahbprot-mode.301061/
 */

#ifndef IOSPATCH_H
#define IOSPATCH_H

#include <gctypes.h>

// Check if AHBPROT is enabled (full hardware access)
#define AHBPROT_DISABLED (*(vu32*)0xcd800064 == 0xFFFFFFFF)

/**
 * Patch ES module to preserve AHBPROT through IOS reload.
 * Must be called BEFORE IOS_ReloadIOS().
 *
 * @return Number of patches applied (1 on success, 0 on failure)
 */
u32 iospatch_ahbprot(void);

/**
 * Apply IOS patches for ISFS permissions.
 * Allows NAND access from userspace.
 *
 * @return Number of patches applied
 */
u32 iospatch_isfs_permissions(void);

#endif // IOSPATCH_H
