/*
 * A C ABI over QuickJS that is stable enough for `dart:ffi` to bind against.
 *
 * Derived from https://github.com/ekibun/flutter_qjs (cxx/ffi.cpp, MIT), ported to plain C
 * (so Android does not need to link libc++) and adapted to the quickjs-ng API.
 */
#include "quickjs_dart_bridge.h"

#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Every JSValue crossing the FFI boundary is a heap box; see the header for why. */
static JSValue *js_value_box(JSValue v) {
  JSValue *p = (JSValue *)malloc(sizeof(JSValue));
  *p = v;
  return p;
}

typedef struct RuntimeOpaque {
  JSChannel *channel;
  int64_t timeout;
  int64_t start;
} RuntimeOpaque;

DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj) {
  return js_value_box(JS_Throw(ctx, JS_DupValue(ctx, *obj)));
}

DLLEXPORT JSValue *jsEXCEPTION(void) { return js_value_box(JS_EXCEPTION); }

DLLEXPORT JSValue *jsUNDEFINED(void) { return js_value_box(JS_UNDEFINED); }

DLLEXPORT JSValue *jsNULL(void) { return js_value_box(JS_NULL); }

static JSModuleDef *js_module_loader(JSContext *ctx, const char *module_name, void *opaque) {
  const char *str = (const char *)((RuntimeOpaque *)opaque)
                        ->channel(ctx, JSChannelType_MODULE, (void *)module_name);
  if (str == 0)
    return NULL;
  JSValue func_val = JS_Eval(ctx, str, strlen(str), module_name,
                             JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
  if (JS_IsException(func_val))
    return NULL;
  /* the module is already referenced, so we must free it */
  JSModuleDef *m = (JSModuleDef *)JS_VALUE_GET_PTR(func_val);
  JS_FreeValue(ctx, func_val);
  return m;
}

static JSValue js_channel(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv,
                          int magic, JSValue *func_data) {
  JSRuntime *rt = JS_GetRuntime(ctx);
  RuntimeOpaque *opaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  void *data[4];
  data[0] = &this_val;
  data[1] = &argc;
  data[2] = argv;
  data[3] = func_data;
  return *(JSValue *)opaque->channel(ctx, JSChannelType_METHON, data);
}

static void js_promise_rejection_tracker(JSContext *ctx, JSValueConst promise,
                                         JSValueConst reason, bool is_handled, void *opaque) {
  if (is_handled)
    return;
  ((RuntimeOpaque *)opaque)->channel(ctx, JSChannelType_PROMISE_TRACK, &reason);
}

static int js_interrupt_handler(JSRuntime *rt, void *opaque) {
  RuntimeOpaque *op = (RuntimeOpaque *)opaque;
  if (op->timeout && op->start && (clock() - op->start) > op->timeout * CLOCKS_PER_SEC / 1000) {
    op->start = 0;
    return 1;
  }
  return 0;
}

DLLEXPORT JSRuntime *jsNewRuntime(JSChannel channel, int64_t timeout) {
  JSRuntime *rt = JS_NewRuntime();
  RuntimeOpaque *opaque = (RuntimeOpaque *)malloc(sizeof(RuntimeOpaque));
  opaque->channel = channel;
  opaque->timeout = timeout;
  opaque->start = 0;
  JS_SetRuntimeOpaque(rt, opaque);
  JS_SetHostPromiseRejectionTracker(rt, js_promise_rejection_tracker, opaque);
  JS_SetModuleLoaderFunc(rt, NULL, js_module_loader, opaque);
  JS_SetInterruptHandler(rt, js_interrupt_handler, opaque);
  return rt;
}

/* Hands the object's opaque pointer back to Dart so it can drop the matching Dart-side ref.
   The channel receives the runtime cast to JSContext*; Dart casts it back for FREE_OBJECT. */
static void qjs_class_finalizer(JSRuntime *rt, JSValueConst obj) {
  JSClassID classid = JS_GetClassID(obj);
  void *opaque = JS_GetOpaque(obj, classid);
  RuntimeOpaque *runtimeOpaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  if (runtimeOpaque == NULL)
    return;
  runtimeOpaque->channel((JSContext *)rt, JSChannelType_FREE_OBJECT, opaque);
}

DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name) {
  JSRuntime *rt = JS_GetRuntime(ctx);
  JSClassID QJSClassId = 0;
  JS_NewClassID(rt, &QJSClassId);
  if (!JS_IsRegisteredClass(rt, QJSClassId)) {
    JSClassDef def;
    memset(&def, 0, sizeof(def));
    def.class_name = name;
    def.finalizer = qjs_class_finalizer;
    int e = JS_NewClass(rt, QJSClassId, &def);
    if (e < 0) {
      JS_ThrowInternalError(ctx, "Cant register class %s", name);
      return 0;
    }
  }
  return QJSClassId;
}

DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid) {
  return JS_GetOpaque(*obj, classid);
}

DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque) {
  JSValue *jsobj = js_value_box(JS_NewObjectClass(ctx, QJSClassId));
  if (JS_IsException(*jsobj))
    return jsobj;
  JS_SetOpaque(*jsobj, opaque);
  return jsobj;
}

DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size) {
  JS_SetMaxStackSize(rt, stack_size);
}

DLLEXPORT void jsSetMemoryLimit(JSRuntime *rt, size_t limit) { JS_SetMemoryLimit(rt, limit); }

DLLEXPORT void jsFreeRuntime(JSRuntime *rt) {
  RuntimeOpaque *opaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  /* Cleared before JS_FreeRuntime so the class finalizer, which runs during teardown, sees a
     NULL opaque and stops calling back into Dart. */
  JS_SetRuntimeOpaque(rt, NULL);
  JS_FreeRuntime(rt);
  free(opaque);
}

DLLEXPORT JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData) {
  return js_value_box(JS_NewCFunctionData(ctx, js_channel, 0, 0, 1, funcData));
}

DLLEXPORT JSValue *jsGetGlobalObject(JSContext *ctx) {
  return js_value_box(JS_GetGlobalObject(ctx));
}

DLLEXPORT JSContext *jsNewContext(JSRuntime *rt) {
  JS_UpdateStackTop(rt);
  return JS_NewContext(rt);
}

DLLEXPORT void jsFreeContext(JSContext *ctx) { JS_FreeContext(ctx); }

DLLEXPORT JSRuntime *jsGetRuntime(JSContext *ctx) { return JS_GetRuntime(ctx); }

/* Re-anchors the stack top (calls arrive on whatever thread Dart is on) and restarts the
   timeout clock consulted by js_interrupt_handler. */
static void js_begin_call(JSRuntime *rt) {
  JS_UpdateStackTop(rt);
  RuntimeOpaque *opaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  if (opaque)
    opaque->start = clock();
}

DLLEXPORT JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len,
                          const char *filename, int32_t eval_flags) {
  js_begin_call(JS_GetRuntime(ctx));
  return js_value_box(JS_Eval(ctx, input, input_len, filename, eval_flags));
}

DLLEXPORT int32_t jsValueGetTag(JSValue *val) { return JS_VALUE_GET_TAG(*val); }

DLLEXPORT void *jsValueGetPtr(JSValue *val) { return JS_VALUE_GET_PTR(*val); }

DLLEXPORT int32_t jsTagIsFloat64(int32_t tag) { return JS_TAG_IS_FLOAT64(tag); }

DLLEXPORT JSValue *jsNewBool(JSContext *ctx, int32_t val) {
  return js_value_box(JS_NewBool(ctx, val));
}

DLLEXPORT JSValue *jsNewInt64(JSContext *ctx, int64_t val) {
  return js_value_box(JS_NewInt64(ctx, val));
}

DLLEXPORT JSValue *jsNewFloat64(JSContext *ctx, double val) {
  return js_value_box(JS_NewFloat64(ctx, val));
}

DLLEXPORT JSValue *jsNewString(JSContext *ctx, const char *str) {
  return js_value_box(JS_NewString(ctx, str));
}

DLLEXPORT JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len) {
  return js_value_box(JS_NewArrayBufferCopy(ctx, buf, len));
}

DLLEXPORT JSValue *jsNewArray(JSContext *ctx) { return js_value_box(JS_NewArray(ctx)); }

DLLEXPORT JSValue *jsNewObject(JSContext *ctx) { return js_value_box(JS_NewObject(ctx)); }

DLLEXPORT void jsFreeValue(JSContext *ctx, JSValue *v, int32_t free_box) {
  JS_FreeValue(ctx, *v);
  if (free_box)
    free(v);
}

DLLEXPORT void jsFreeValueRT(JSRuntime *rt, JSValue *v, int32_t free_box) {
  JS_FreeValueRT(rt, *v);
  if (free_box)
    free(v);
}

DLLEXPORT JSValue *jsDupValue(JSContext *ctx, JSValue *v) {
  return js_value_box(JS_DupValue(ctx, *v));
}

DLLEXPORT JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v) {
  return js_value_box(JS_DupValueRT(rt, *v));
}

DLLEXPORT int32_t jsToBool(JSContext *ctx, JSValue *val) { return JS_ToBool(ctx, *val); }

DLLEXPORT int64_t jsToInt64(JSContext *ctx, JSValue *val) {
  int64_t p = 0;
  JS_ToInt64(ctx, &p, *val);
  return p;
}

DLLEXPORT double jsToFloat64(JSContext *ctx, JSValue *val) {
  double p = 0;
  JS_ToFloat64(ctx, &p, *val);
  return p;
}

DLLEXPORT const char *jsToCString(JSContext *ctx, JSValue *val) {
  js_begin_call(JS_GetRuntime(ctx));
  return JS_ToCString(ctx, *val);
}

DLLEXPORT void jsFreeCString(JSContext *ctx, const char *ptr) { JS_FreeCString(ctx, ptr); }

DLLEXPORT uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValue *obj) {
  return JS_GetArrayBuffer(ctx, psize, *obj);
}

DLLEXPORT int32_t jsIsFunction(JSContext *ctx, JSValue *val) {
  return JS_IsFunction(ctx, *val);
}

DLLEXPORT int32_t jsIsPromise(JSContext *ctx, JSValue *val) { return JS_IsPromise(*val); }

DLLEXPORT int32_t jsIsArray(JSContext *ctx, JSValue *val) { return JS_IsArray(*val); }

DLLEXPORT int32_t jsIsError(JSContext *ctx, JSValue *val) { return JS_IsError(*val); }

DLLEXPORT JSValue *jsNewError(JSContext *ctx) { return js_value_box(JS_NewError(ctx)); }

DLLEXPORT JSValue *jsGetProperty(JSContext *ctx, JSValue *this_obj, JSAtom prop) {
  return js_value_box(JS_GetProperty(ctx, *this_obj, prop));
}

DLLEXPORT int32_t jsDefinePropertyValue(JSContext *ctx, JSValue *this_obj, JSAtom prop,
                                        JSValue *val, int32_t flags) {
  return JS_DefinePropertyValue(ctx, *this_obj, prop, *val, flags);
}

DLLEXPORT void jsFreeAtom(JSContext *ctx, JSAtom v) { JS_FreeAtom(ctx, v); }

DLLEXPORT JSAtom jsValueToAtom(JSContext *ctx, JSValue *val) {
  return JS_ValueToAtom(ctx, *val);
}

DLLEXPORT JSValue *jsAtomToValue(JSContext *ctx, JSAtom val) {
  return js_value_box(JS_AtomToValue(ctx, val));
}

DLLEXPORT int32_t jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab, uint32_t *plen,
                                        JSValue *obj, int32_t flags) {
  return JS_GetOwnPropertyNames(ctx, ptab, plen, *obj, flags);
}

DLLEXPORT JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int32_t i) { return ptab[i].atom; }

DLLEXPORT uint32_t sizeOfJSValue(void) { return (uint32_t)sizeof(JSValue); }

DLLEXPORT void setJSValueList(JSValue *list, uint32_t i, JSValue *val) { list[i] = *val; }

DLLEXPORT JSValue *jsCall(JSContext *ctx, JSValue *func_obj, JSValue *this_obj, int32_t argc,
                          JSValue *argv) {
  js_begin_call(JS_GetRuntime(ctx));
  return js_value_box(JS_Call(ctx, *func_obj, *this_obj, argc, argv));
}

DLLEXPORT int32_t jsIsException(JSValue *val) { return JS_IsException(*val); }

DLLEXPORT JSValue *jsGetException(JSContext *ctx) {
  return js_value_box(JS_GetException(ctx));
}

DLLEXPORT int32_t jsExecutePendingJob(JSRuntime *rt) {
  js_begin_call(rt);
  JSContext *ctx;
  return JS_ExecutePendingJob(rt, &ctx);
}

DLLEXPORT JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs) {
  return js_value_box(JS_NewPromiseCapability(ctx, resolving_funcs));
}

DLLEXPORT void jsFree(JSContext *ctx, void *ptab) { js_free(ctx, ptab); }

DLLEXPORT int64_t jsMallocSize(JSRuntime *rt) {
  JSMemoryUsage s;
  JS_ComputeMemoryUsage(rt, &s);
  return s.malloc_size;
}

DLLEXPORT int64_t jsMallocCount(JSRuntime *rt) {
  JSMemoryUsage s;
  JS_ComputeMemoryUsage(rt, &s);
  return s.malloc_count;
}

DLLEXPORT const char *jsQuickJSVersion(void) { return JS_GetVersion(); }
