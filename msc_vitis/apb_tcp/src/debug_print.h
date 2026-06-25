#ifndef DEBUG_PRINT_H
#define DEBUG_PRINT_H

#include "xil_printf.h"

// Includes defines to toggle printing for testing and debugging purposes. When disabled, the corresponding print macros compile to no-ops, so there is no overhead from formatting or printing when disabled. 
// When enabled, the macros use xil_printf to print messages, which is suitable for embedded environments like this one.

#define DBG_PRINT 0  /* Toggle debug printing (excludes initial IP message) */
#define ORDINARY_PRINT 1  /* Toggle ordinary printing (excludes initial IP message) */

#if DBG_PRINT
#define debug_print(fmt, ...) xil_printf(fmt, ##__VA_ARGS__) // Use xil_printf for debug printing when enabled
#else
#define debug_print(fmt, ...) do { } while (0) //no-op when debug printing is disabled
#endif


#if ORDINARY_PRINT
#define ordinary_print(fmt, ...) xil_printf(fmt, ##__VA_ARGS__) // Use xil_printf for ordinary printing when enabled
#else
#define ordinary_print(fmt, ...) do { } while (0) //no-op when ordinary printing is disabled
#endif


#endif /* DEBUG_PRINT_H */
