#ifndef TEST_FRAMEWORK_H
#define TEST_FRAMEWORK_H

#import <Foundation/Foundation.h>
#import <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Terminal styling
#define ANSI_COLOR_RED     "\033[31m"
#define ANSI_COLOR_GREEN   "\033[32m"
#define ANSI_COLOR_YELLOW  "\033[33m"
#define ANSI_COLOR_BLUE    "\033[34m"
#define ANSI_COLOR_CYAN    "\033[36m"
#define ANSI_COLOR_BOLD    "\033[1m"
#define ANSI_COLOR_DIM     "\033[2m"
#define ANSI_COLOR_RESET   "\033[0m"

typedef struct {
    int tests_run;
    int tests_passed;
    int tests_failed;
    int current_test_failed;
} TestContext;

extern TestContext g_test_ctx;

static inline void test_framework_init(void) {
    g_test_ctx.tests_run = 0;
    g_test_ctx.tests_passed = 0;
    g_test_ctx.tests_failed = 0;
    g_test_ctx.current_test_failed = 0;
}

#define TEST_SUITE_BEGIN(name) \
    printf("\n" ANSI_COLOR_BOLD ANSI_COLOR_CYAN "▶ Running Test Suite: %s" ANSI_COLOR_RESET "\n", name);

#define TEST_SUITE_END()

#define TEST_CASE(name) \
    static void name(void); \
    static void __attribute__((constructor)) register_##name(void) {} \
    static void name(void)

#define RUN_TEST(func) do { \
    g_test_ctx.tests_run++; \
    g_test_ctx.current_test_failed = 0; \
    uint64_t start_time = mach_absolute_time(); \
    printf("  " ANSI_COLOR_DIM "•" ANSI_COLOR_RESET " Running %-45s ", #func); \
    fflush(stdout); \
    @autoreleasepool { \
        func(); \
    } \
    uint64_t end_time = mach_absolute_time(); \
    mach_timebase_info_data_t timebase; \
    mach_timebase_info(&timebase); \
    double elapsed_ms = (double)(end_time - start_time) * (double)timebase.numer / (double)timebase.denom / 1000000.0; \
    if (!g_test_ctx.current_test_failed) { \
        g_test_ctx.tests_passed++; \
        printf(ANSI_COLOR_GREEN "✓ PASS" ANSI_COLOR_RESET " " ANSI_COLOR_DIM "(%.2f ms)" ANSI_COLOR_RESET "\n", elapsed_ms); \
    } else { \
        g_test_ctx.tests_failed++; \
        printf(ANSI_COLOR_RED "✗ FAIL" ANSI_COLOR_RESET " " ANSI_COLOR_DIM "(%.2f ms)" ANSI_COLOR_RESET "\n", elapsed_ms); \
    } \
} while(0)

#define ASSERT_TRUE(condition) do { \
    if (!(condition)) { \
        printf("\n    " ANSI_COLOR_RED "ASSERTION FAILED: " #condition ANSI_COLOR_RESET "\n"); \
        printf("    File: %s:%d\n", __FILE__, __LINE__); \
        g_test_ctx.current_test_failed = 1; \
        return; \
    } \
} while(0)

#define ASSERT_FALSE(condition) do { \
    if ((condition)) { \
        printf("\n    " ANSI_COLOR_RED "ASSERTION FAILED (expected FALSE): " #condition ANSI_COLOR_RESET "\n"); \
        printf("    File: %s:%d\n", __FILE__, __LINE__); \
        g_test_ctx.current_test_failed = 1; \
        return; \
    } \
} while(0)

#define ASSERT_NOT_NULL(ptr) do { \
    if ((ptr) == NULL || (ptr) == nil) { \
        printf("\n    " ANSI_COLOR_RED "ASSERTION FAILED (expected NOT NULL): " #ptr ANSI_COLOR_RESET "\n"); \
        printf("    File: %s:%d\n", __FILE__, __LINE__); \
        g_test_ctx.current_test_failed = 1; \
        return; \
    } \
} while(0)

#define ASSERT_NULL(ptr) do { \
    if ((ptr) != NULL && (ptr) != nil) { \
        printf("\n    " ANSI_COLOR_RED "ASSERTION FAILED (expected NULL): " #ptr ANSI_COLOR_RESET "\n"); \
        printf("    File: %s:%d\n", __FILE__, __LINE__); \
        g_test_ctx.current_test_failed = 1; \
        return; \
    } \
} while(0)

#define ASSERT_EQUAL(a, b) do { \
    __typeof__(a) _val_a = (a); \
    __typeof__(b) _val_b = (b); \
    if (_val_a != _val_b) { \
        printf("\n    " ANSI_COLOR_RED "ASSERTION FAILED: " #a " == " #b ANSI_COLOR_RESET "\n"); \
        printf("    Expected: %lld, Got: %lld\n", (long long)_val_b, (long long)_val_a); \
        printf("    File: %s:%d\n", __FILE__, __LINE__); \
        g_test_ctx.current_test_failed = 1; \
        return; \
    } \
} while(0)

#define ASSERT_FLOAT_EQUAL(a, b, eps) do { \
    double _fa = (double)(a); \
    double _fb = (double)(b); \
    double _feps = (double)(eps); \
    if (fabs(_fa - _fb) > _feps) { \
        printf("\n    " ANSI_COLOR_RED "ASSERTION FAILED: |" #a " - " #b "| <= " #eps ANSI_COLOR_RESET "\n"); \
        printf("    Expected: %f, Got: %f (diff %f > %f)\n", _fb, _fa, fabs(_fa - _fb), _feps); \
        printf("    File: %s:%d\n", __FILE__, __LINE__); \
        g_test_ctx.current_test_failed = 1; \
        return; \
    } \
} while(0)

#define ASSERT_STRING_EQUAL(s1, s2) do { \
    NSString *_str1 = (s1); \
    NSString *_str2 = (s2); \
    if (![_str1 isEqualToString:_str2]) { \
        printf("\n    " ANSI_COLOR_RED "ASSERTION FAILED (Strings differ):" ANSI_COLOR_RESET "\n"); \
        printf("    Expected: \"%s\"\n", _str2.UTF8String ?: "(nil)"); \
        printf("    Got:      \"%s\"\n", _str1.UTF8String ?: "(nil)"); \
        printf("    File: %s:%d\n", __FILE__, __LINE__); \
        g_test_ctx.current_test_failed = 1; \
        return; \
    } \
} while(0)

static inline int test_framework_summary(void) {
    printf("\n" ANSI_COLOR_BOLD "==================================================" ANSI_COLOR_RESET "\n");
    if (g_test_ctx.tests_failed == 0) {
        printf(ANSI_COLOR_BOLD ANSI_COLOR_GREEN "✓ ALL %d TESTS PASSED!" ANSI_COLOR_RESET "\n", g_test_ctx.tests_passed);
        printf(ANSI_COLOR_DIM "==================================================" ANSI_COLOR_RESET "\n\n");
        return 0;
    } else {
        printf(ANSI_COLOR_BOLD ANSI_COLOR_RED "✗ TEST SUITE FAILED: %d of %d tests failed." ANSI_COLOR_RESET "\n",
               g_test_ctx.tests_failed, g_test_ctx.tests_run);
        printf(ANSI_COLOR_DIM "==================================================" ANSI_COLOR_RESET "\n\n");
        return 1;
    }
}

#endif // TEST_FRAMEWORK_H
