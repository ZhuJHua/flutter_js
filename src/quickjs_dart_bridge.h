/*
 * A C ABI over QuickJS that is stable enough for `dart:ffi` to bind against.
 *
 * Every `JSValue` crosses the boundary as a heap-allocated `JSValue *` box, because `JSValue`
 * is a struct on 64-bit builds and a NaN-boxed `uint64_t` on 32-bit builds. Boxing keeps the
 * Dart side free of any assumption about that layout. Boxes are released by passing a non-zero
 * `free` argument to `jsFreeValue`/`jsFreeValueRT`.
 *
 * Derived from https://github.com/ekibun/flutter_qjs (cxx/ffi.h, MIT), ported to plain C and
 * adapted to the quickjs-ng API.
 */
#ifndef QUICKJS_DART_BRIDGE_H
#define QUICKJS_DART_BRIDGE_H

#include "quickjs/quickjs.h"

#ifdef _MSC_VER
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum JSChannelType {
  JSChannelType_METHON = 0,
  JSChannelType_MODULE = 1,
  JSChannelType_PROMISE_TRACK = 2,
  JSChannelType_FREE_OBJECT = 3,
};

typedef void *JSChannel(JSContext *ctx, size_t type, void *argv);

DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj);

DLLEXPORT JSValue *jsEXCEPTION(void);

DLLEXPORT JSValue *jsUNDEFINED(void);

DLLEXPORT JSValue *jsNULL(void);

DLLEXPORT JSRuntime *jsNewRuntime(JSChannel channel, int64_t timeout);

DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name);

DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid);

DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque);

DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size);

DLLEXPORT void jsSetMemoryLimit(JSRuntime *rt, size_t limit);

DLLEXPORT void jsFreeRuntime(JSRuntime *rt);

DLLEXPORT JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData);

DLLEXPORT JSValue *jsGetGlobalObject(JSContext *ctx);

DLLEXPORT JSContext *jsNewContext(JSRuntime *rt);

DLLEXPORT void jsFreeContext(JSContext *ctx);

DLLEXPORT JSRuntime *jsGetRuntime(JSContext *ctx);

DLLEXPORT JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len,
                          const char *filename, int32_t eval_flags);

DLLEXPORT int32_t jsValueGetTag(JSValue *val);

DLLEXPORT void *jsValueGetPtr(JSValue *val);

DLLEXPORT int32_t jsTagIsFloat64(int32_t tag);

DLLEXPORT JSValue *jsNewBool(JSContext *ctx, int32_t val);

DLLEXPORT JSValue *jsNewInt64(JSContext *ctx, int64_t val);

DLLEXPORT JSValue *jsNewFloat64(JSContext *ctx, double val);

DLLEXPORT JSValue *jsNewString(JSContext *ctx, const char *str);

DLLEXPORT JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len);

DLLEXPORT JSValue *jsNewArray(JSContext *ctx);

DLLEXPORT JSValue *jsNewObject(JSContext *ctx);

DLLEXPORT void jsFreeValue(JSContext *ctx, JSValue *v, int32_t free);

DLLEXPORT void jsFreeValueRT(JSRuntime *rt, JSValue *v, int32_t free);

DLLEXPORT JSValue *jsDupValue(JSContext *ctx, JSValue *v);

DLLEXPORT JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v);

DLLEXPORT int32_t jsToBool(JSContext *ctx, JSValue *val);

DLLEXPORT int64_t jsToInt64(JSContext *ctx, JSValue *val);

DLLEXPORT double jsToFloat64(JSContext *ctx, JSValue *val);

DLLEXPORT const char *jsToCString(JSContext *ctx, JSValue *val);

DLLEXPORT void jsFreeCString(JSContext *ctx, const char *ptr);

DLLEXPORT uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValue *obj);

DLLEXPORT int32_t jsIsFunction(JSContext *ctx, JSValue *val);

DLLEXPORT int32_t jsIsPromise(JSContext *ctx, JSValue *val);

DLLEXPORT int32_t jsIsArray(JSContext *ctx, JSValue *val);

DLLEXPORT int32_t jsIsError(JSContext *ctx, JSValue *val);

DLLEXPORT JSValue *jsNewError(JSContext *ctx);

DLLEXPORT JSValue *jsGetProperty(JSContext *ctx, JSValue *this_obj, JSAtom prop);

DLLEXPORT int32_t jsDefinePropertyValue(JSContext *ctx, JSValue *this_obj, JSAtom prop,
                                        JSValue *val, int32_t flags);

DLLEXPORT void jsFreeAtom(JSContext *ctx, JSAtom v);

DLLEXPORT JSAtom jsValueToAtom(JSContext *ctx, JSValue *val);

DLLEXPORT JSValue *jsAtomToValue(JSContext *ctx, JSAtom val);

DLLEXPORT int32_t jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab, uint32_t *plen,
                                        JSValue *obj, int32_t flags);

DLLEXPORT JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int32_t i);

DLLEXPORT uint32_t sizeOfJSValue(void);

DLLEXPORT void setJSValueList(JSValue *list, uint32_t i, JSValue *val);

DLLEXPORT JSValue *jsCall(JSContext *ctx, JSValue *func_obj, JSValue *this_obj, int32_t argc,
                          JSValue *argv);

DLLEXPORT int32_t jsIsException(JSValue *val);

DLLEXPORT JSValue *jsGetException(JSContext *ctx);

DLLEXPORT int32_t jsExecutePendingJob(JSRuntime *rt);

DLLEXPORT JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs);

DLLEXPORT void jsFree(JSContext *ctx, void *ptab);

/* Null-terminated "0.16.2"-style version of the bundled quickjs-ng. */
DLLEXPORT const char *jsQuickJSVersion(void);

#ifdef __cplusplus
}
#endif

#endif /* QUICKJS_DART_BRIDGE_H */
