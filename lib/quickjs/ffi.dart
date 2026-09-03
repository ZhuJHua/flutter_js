/*
 * QuickJS bindings.
 *
 * Originally from https://github.com/ekibun/flutter_qjs (MIT); the native library is now built
 * from `src/` by `hook/build.dart` and resolved as a code asset rather than dlopen'd.
 */
@DefaultAsset('package:flutter_js/quickjs/ffi.dart')
library;

import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

extension ListFirstWhere<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } on StateError {
      return null;
    }
  }
}

abstract class JSRef {
  int _refCount = 0;
  void dup() {
    _refCount++;
  }

  void free() {
    _refCount--;
    if (_refCount < 0) destroy();
  }

  void destroy();

  static void freeRecursive(dynamic obj) {
    _callRecursive(obj, (ref) => ref.free());
  }

  static void dupRecursive(dynamic obj) {
    _callRecursive(obj, (ref) => ref.dup());
  }

  static void _callRecursive(
    dynamic obj,
    void Function(JSRef) cb, [
    Set? cache,
  ]) {
    if (obj == null) return;
    cache ??= <dynamic>{};
    if (cache.contains(obj)) return;
    if (obj is List) {
      cache.add(obj);
      for (var e in List.from(obj)) {
        _callRecursive(e, cb, cache);
      }
    }
    if (obj is Map) {
      cache.add(obj);
      obj.values.toList().forEach((e) => _callRecursive(e, cb, cache));
    }
    if (obj is JSRef) {
      cb(obj);
    }
  }
}

abstract class JSRefLeakable {}

class JSEvalFlag {
  static const GLOBAL = 0 << 0;
  static const MODULE = 1 << 0;
}

class JSChannelType {
  static const METHON = 0;
  static const MODULE = 1;
  static const PROMISE_TRACK = 2;
  static const FREE_OBJECT = 3;
}

class JSProp {
  static const CONFIGURABLE = (1 << 0);
  static const WRITABLE = (1 << 1);
  static const ENUMERABLE = (1 << 2);
  static const C_W_E = (CONFIGURABLE | WRITABLE | ENUMERABLE);
}

/// Mirrors the tag enum in `src/quickjs/quickjs.h`.
///
/// quickjs-ng renumbered these relative to the 2021-03-27 QuickJS this package used to bundle:
/// `BIG_FLOAT`/`BIG_DECIMAL` are gone, `STRING_ROPE` and `SHORT_BIG_INT` are new, and
/// `FLOAT64` moved from 7 to 8. Keep this in sync when re-vendoring quickjs.
class JSTag {
  static const FIRST = -9; /* first negative tag */
  static const BIG_INT = -9;
  static const SYMBOL = -8;
  static const STRING = -7;
  static const STRING_ROPE = -6;
  static const MODULE = -3; /* used internally */
  static const FUNCTION_BYTECODE = -2; /* used internally */
  static const OBJECT = -1;

  static const INT = 0;
  static const BOOL = 1;
  static const NULL = 2;
  static const UNDEFINED = 3;
  static const UNINITIALIZED = 4;
  static const CATCH_OFFSET = 5;
  static const EXCEPTION = 6;
  static const SHORT_BIG_INT = 7;
  static const FLOAT64 = 8;
}

abstract base class JSValue extends Opaque {}

abstract base class JSContext extends Opaque {}

abstract base class JSRuntime extends Opaque {}

abstract base class JSPropertyEnum extends Opaque {}

/// DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj)
@Native<Pointer<Utf8> Function()>(symbol: 'jsQuickJSVersion')
external Pointer<Utf8> _jsQuickJSVersion();

/// Version of the bundled quickjs-ng engine, e.g. `0.16.2`.
///
/// Reads it out of the compiled library rather than a Dart constant, so it cannot drift from
/// what is actually linked in.
String get quickJsVersion => _jsQuickJSVersion().toDartString();

@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsThrow')
external Pointer<JSValue> jsThrow(Pointer<JSContext> ctx, Pointer<JSValue> obj);

/// JSValue *jsEXCEPTION()
@Native<Pointer<JSValue> Function()>(symbol: 'jsEXCEPTION')
external Pointer<JSValue> jsEXCEPTION();

/// JSValue *jsUNDEFINED()
@Native<Pointer<JSValue> Function()>(symbol: 'jsUNDEFINED')
external Pointer<JSValue> jsUNDEFINED();

typedef _JSChannel = Pointer<JSValue> Function(
    Pointer<JSContext> ctx, int method, Pointer<JSValue> argv);
typedef _JSChannelNative = Pointer<JSValue> Function(
    Pointer<JSContext> ctx, IntPtr method, Pointer<JSValue> argv);

/// JSRuntime *jsNewRuntime(JSChannel channel)
@Native<Pointer<JSRuntime> Function(Pointer<NativeFunction<_JSChannelNative>>, Int64)>(symbol: 'jsNewRuntime')
external Pointer<JSRuntime> _jsNewRuntime(Pointer<NativeFunction<_JSChannelNative>> a0, int a1);

class _RuntimeOpaque {
  final _JSChannel _channel;
  final List<JSRef> _ref = [];
  final ReceivePort _port;
  int? _dartObjectClassId;
  _RuntimeOpaque(this._channel, this._port);

  int? get dartObjectClassId => _dartObjectClassId;

  void addRef(JSRef ref) => _ref.add(ref);

  bool removeRef(JSRef ref) => _ref.remove(ref);

  JSRef? getRef(bool Function(JSRef ref) test) {
    return _ref.firstWhereOrNull(test);
  }
}

final Map<Pointer<JSRuntime>, _RuntimeOpaque> runtimeOpaques = {};

Pointer<JSValue> channelDispacher(
  Pointer<JSContext> ctx,
  int type,
  Pointer<JSValue> argv,
) {
  final rt = type == JSChannelType.FREE_OBJECT
      ? ctx.cast<JSRuntime>()
      : jsGetRuntime(ctx);
  return runtimeOpaques[rt]!._channel(ctx, type, argv);
}

Pointer<JSRuntime> jsNewRuntime(
  _JSChannel callback,
  int timeout,
  ReceivePort port,
) {
  final rt = _jsNewRuntime(Pointer.fromFunction(channelDispacher), timeout);
  runtimeOpaques[rt] = _RuntimeOpaque(callback, port);
  return rt;
}

/// DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size)
@Native<Void Function(Pointer<JSRuntime>, IntPtr)>(symbol: 'jsSetMaxStackSize')
external void jsSetMaxStackSize(Pointer<JSRuntime> a0, int a1);

/// DLLEXPORT void jsSetMemoryLimit(JSRuntime *rt, size_t limit);
@Native<Void Function(Pointer<JSRuntime>, IntPtr)>(symbol: 'jsSetMemoryLimit')
external void jsSetMemoryLimit(Pointer<JSRuntime> a0, int a1);

/// void jsFreeRuntime(JSRuntime *rt)
@Native<Void Function(Pointer<JSRuntime>)>(symbol: 'jsFreeRuntime')
external void _jsFreeRuntime(Pointer<JSRuntime> a0);

void jsFreeRuntime(
  Pointer<JSRuntime> rt,
) {
  final referenceleak = <String>[];
  final opaque = runtimeOpaques[rt];
  if (opaque != null) {
    while (opaque._ref.isNotEmpty) {
      final ref = opaque._ref.first;
      ref.destroy();
      runtimeOpaques[rt]?._ref.remove(ref);
    }
    while (opaque._ref.isNotEmpty) {
      final ref = opaque._ref.first;
      final objStrs = ref.toString().split('\n');
      final objStr = objStrs.isNotEmpty ? "${objStrs[0]} ..." : objStrs[0];
      referenceleak.add(
          "  ${identityHashCode(ref)}\t${ref._refCount + 1}\t${ref.runtimeType.toString()}\t$objStr");
      ref.destroy();
    }
  }
  _jsFreeRuntime(rt);
  if (referenceleak.isNotEmpty) {
    throw ('reference leak:\n    ADDR\tREF\tTYPE\tPROP\n${referenceleak.join('\n')}');
  }
}

/// JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsNewCFunction')
external Pointer<JSValue> jsNewCFunction(Pointer<JSContext> ctx, Pointer<JSValue> funcData);

/// JSContext *jsNewContext(JSRuntime *rt)
@Native<Pointer<JSContext> Function(Pointer<JSRuntime>)>(symbol: 'jsNewContext')
external Pointer<JSContext> _jsNewContext(Pointer<JSRuntime> rt);

Pointer<JSContext> jsNewContext(Pointer<JSRuntime> rt) {
  final ctx = _jsNewContext(rt);
  if (ctx.address == 0) throw Exception('Context create failed!');
  final runtimeOpaque = runtimeOpaques[rt];
  if (runtimeOpaque == null) throw Exception('Runtime has been released!');
  runtimeOpaque._dartObjectClassId = jsNewClass(ctx, 'DartObject');
  return ctx;
}

/// void jsFreeContext(JSContext *ctx)
@Native<Void Function(Pointer<JSContext>)>(symbol: 'jsFreeContext')
external void jsFreeContext(Pointer<JSContext> a0);

/// JSRuntime *jsGetRuntime(JSContext *ctx)
@Native<Pointer<JSRuntime> Function(Pointer<JSContext>)>(symbol: 'jsGetRuntime')
external Pointer<JSRuntime> jsGetRuntime(Pointer<JSContext> a0);

/// JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int eval_flags)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<Utf8>, IntPtr, Pointer<Utf8>, Int32)>(symbol: 'jsEval')
external Pointer<JSValue> _jsEval(Pointer<JSContext> ctx, Pointer<Utf8> input, int inputLen, Pointer<Utf8> filename, int evalFlags);

Pointer<JSValue> jsEval(
  Pointer<JSContext> ctx,
  String input,
  String filename,
  int evalFlags,
) {
  final utf8input = input.toNativeUtf8();
  final utf8filename = filename.toNativeUtf8();
  final val = _jsEval(
    ctx,
    utf8input,
    utf8input.length,
    utf8filename,
    evalFlags,
  );
  malloc.free(utf8input);
  malloc.free(utf8filename);
  runtimeOpaques[jsGetRuntime(ctx)]?._port.sendPort.send(#eval);
  return val;
}

/// DLLEXPORT int32_t jsValueGetTag(JSValue *val)
@Native<Int32 Function(Pointer<JSValue>)>(symbol: 'jsValueGetTag')
external int jsValueGetTag(Pointer<JSValue> val);

/// void *jsValueGetPtr(JSValue *val)
@Native<IntPtr Function(Pointer<JSValue>)>(symbol: 'jsValueGetPtr')
external int jsValueGetPtr(Pointer<JSValue> val);

/// DLLEXPORT bool jsTagIsFloat64(int32_t tag)
@Native<Int32 Function(Int32)>(symbol: 'jsTagIsFloat64')
external int jsTagIsFloat64(int val);

/// JSValue *jsNewBool(JSContext *ctx, int val)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Int32)>(symbol: 'jsNewBool')
external Pointer<JSValue> jsNewBool(Pointer<JSContext> ctx, int val);

/// JSValue *jsNewInt64(JSContext *ctx, int64_t val)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Int64)>(symbol: 'jsNewInt64')
external Pointer<JSValue> jsNewInt64(Pointer<JSContext> ctx, int val);

/// JSValue *jsNewFloat64(JSContext *ctx, double val)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Double)>(symbol: 'jsNewFloat64')
external Pointer<JSValue> jsNewFloat64(Pointer<JSContext> ctx, double val);

/// JSValue *jsNewString(JSContext *ctx, const char *str)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<Utf8>)>(symbol: 'jsNewString')
external Pointer<JSValue> _jsNewString(Pointer<JSContext> ctx, Pointer<Utf8> str);

Pointer<JSValue> jsNewString(
  Pointer<JSContext> ctx,
  String str,
) {
  final utf8str = str.toNativeUtf8();
  final jsStr = _jsNewString(ctx, utf8str);
  malloc.free(utf8str);
  return jsStr;
}

/// JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<Uint8>, IntPtr)>(symbol: 'jsNewArrayBufferCopy')
external Pointer<JSValue> jsNewArrayBufferCopy(Pointer<JSContext> ctx, Pointer<Uint8> buf, int len);

/// JSValue *jsNewArray(JSContext *ctx)
@Native<Pointer<JSValue> Function(Pointer<JSContext>)>(symbol: 'jsNewArray')
external Pointer<JSValue> jsNewArray(Pointer<JSContext> ctx);

/// JSValue *jsNewObject(JSContext *ctx)
@Native<Pointer<JSValue> Function(Pointer<JSContext>)>(symbol: 'jsNewObject')
external Pointer<JSValue> jsNewObject(Pointer<JSContext> ctx);

/// void jsFreeValue(JSContext *ctx, JSValue *val, int32_t free)
@Native<Void Function(Pointer<JSContext>, Pointer<JSValue>, Int32)>(symbol: 'jsFreeValue')
external void _jsFreeValue(Pointer<JSContext> ctx, Pointer<JSValue> val, int free);

void jsFreeValue(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val, {
  bool free = true,
}) {
  _jsFreeValue(ctx, val, free ? 1 : 0);
}

/// void jsFreeValue(JSRuntime *rt, JSValue *val, int32_t free)
@Native<Void Function(Pointer<JSRuntime>, Pointer<JSValue>, Int32)>(symbol: 'jsFreeValueRT')
external void _jsFreeValueRT(Pointer<JSRuntime> rt, Pointer<JSValue> val, int free);

void jsFreeValueRT(
  Pointer<JSRuntime> rt,
  Pointer<JSValue> val, {
  bool free = true,
}) {
  _jsFreeValueRT(rt, val, free ? 1 : 0);
}

/// JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsDupValue')
external Pointer<JSValue> jsDupValue(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
@Native<Pointer<JSValue> Function(Pointer<JSRuntime>, Pointer<JSValue>)>(symbol: 'jsDupValueRT')
external Pointer<JSValue> jsDupValueRT(Pointer<JSRuntime> rt, Pointer<JSValue> val);

/// int32_t jsToBool(JSContext *ctx, JSValueConst *val)
@Native<Int32 Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsToBool')
external int jsToBool(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// int64_t jsToFloat64(JSContext *ctx, JSValueConst *val)
@Native<Int64 Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsToInt64')
external int jsToInt64(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// double jsToFloat64(JSContext *ctx, JSValueConst *val)
@Native<Double Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsToFloat64')
external double jsToFloat64(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// const char *jsToCString(JSContext *ctx, JSValue *val)
@Native<Pointer<Utf8> Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsToCString')
external Pointer<Utf8> _jsToCString(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// void jsFreeCString(JSContext *ctx, const char *ptr)
@Native<Void Function(Pointer<JSContext>, Pointer<Utf8>)>(symbol: 'jsFreeCString')
external void jsFreeCString(Pointer<JSContext> ctx, Pointer<Utf8> val);

String jsToCString(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) {
  final ptr = _jsToCString(ctx, val);
  if (ptr.address == 0) throw Exception('JSValue cannot convert to string');
  final str = ptr.toDartString();
  jsFreeCString(ctx, ptr);
  return str;
}

/// DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name)
@Native<Uint32 Function(Pointer<JSContext>, Pointer<Utf8>)>(symbol: 'jsNewClass')
external int _jsNewClass(Pointer<JSContext> ctx, Pointer<Utf8> name);

int jsNewClass(
  Pointer<JSContext> ctx,
  String name,
) {
  final utf8name = name.toNativeUtf8();
  final val = _jsNewClass(
    ctx,
    utf8name,
  );
  malloc.free(utf8name);
  return val;
}

/// DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Uint32, IntPtr)>(symbol: 'jsNewObjectClass')
external Pointer<JSValue> jsNewObjectClass(Pointer<JSContext> ctx, int classId, int opaque);

/// DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid)
@Native<IntPtr Function(Pointer<JSValue>, Uint32)>(symbol: 'jsGetObjectOpaque')
external int jsGetObjectOpaque(Pointer<JSValue> obj, int classid);

/// uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
@Native<Pointer<Uint8> Function(Pointer<JSContext>, Pointer<IntPtr>, Pointer<JSValue>)>(symbol: 'jsGetArrayBuffer')
external Pointer<Uint8> jsGetArrayBuffer(Pointer<JSContext> ctx, Pointer<IntPtr> psize, Pointer<JSValue> val);

/// int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
@Native<Int32 Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsIsFunction')
external int jsIsFunction(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// int32_t jsIsPromise(JSContext *ctx, JSValueConst *val)
@Native<Int32 Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsIsPromise')
external int jsIsPromise(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
@Native<Int32 Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsIsArray')
external int jsIsArray(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// DLLEXPORT int32_t jsIsError(JSContext *ctx, JSValueConst *val);
@Native<Int32 Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsIsError')
external int jsIsError(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// DLLEXPORT JSValue *jsNewError(JSContext *ctx);
@Native<Pointer<JSValue> Function(Pointer<JSContext>)>(symbol: 'jsNewError')
external Pointer<JSValue> jsNewError(Pointer<JSContext> ctx);

/// JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<JSValue>, Uint32)>(symbol: 'jsGetProperty')
external Pointer<JSValue> jsGetProperty(Pointer<JSContext> ctx, Pointer<JSValue> thisObj, int prop);

/// int jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop, JSValue *val, int flags)
@Native<Int32 Function(Pointer<JSContext>, Pointer<JSValue>, Uint32, Pointer<JSValue>, Int32)>(symbol: 'jsDefinePropertyValue')
external int jsDefinePropertyValue(Pointer<JSContext> ctx, Pointer<JSValue> thisObj, int prop, Pointer<JSValue> val, int flag);

/// void jsFreeAtom(JSContext *ctx, JSAtom v)
@Native<Void Function(Pointer<JSContext>, Uint32)>(symbol: 'jsFreeAtom')
external void jsFreeAtom(Pointer<JSContext> ctx, int v);

/// JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
@Native<Uint32 Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsValueToAtom')
external int jsValueToAtom(Pointer<JSContext> ctx, Pointer<JSValue> val);

/// JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Uint32)>(symbol: 'jsAtomToValue')
external Pointer<JSValue> jsAtomToValue(Pointer<JSContext> ctx, int val);

/// int jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
///                           uint32_t *plen, JSValueConst *obj, int flags)
@Native<Int32 Function(Pointer<JSContext>, Pointer<Pointer<JSPropertyEnum>>, Pointer<Uint32>, Pointer<JSValue>, Int32)>(symbol: 'jsGetOwnPropertyNames')
external int jsGetOwnPropertyNames(Pointer<JSContext> ctx, Pointer<Pointer<JSPropertyEnum>> ptab, Pointer<Uint32> plen, Pointer<JSValue> obj, int flags);

/// JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int i)
@Native<Uint32 Function(Pointer<JSPropertyEnum>, Int32)>(symbol: 'jsPropertyEnumGetAtom')
external int jsPropertyEnumGetAtom(Pointer<JSPropertyEnum> ptab, int i);

/// uint32_t sizeOfJSValue()
@Native<Uint32 Function()>(symbol: 'sizeOfJSValue')
external int _sizeOfJSValue();

final sizeOfJSValue = _sizeOfJSValue();

/// void setJSValueList(JSValue *list, int i, JSValue *val)
@Native<Void Function(Pointer<JSValue>, Uint32, Pointer<JSValue>)>(symbol: 'setJSValueList')
external void setJSValueList(Pointer<JSValue> list, int i, Pointer<JSValue> val);

/// JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
///                 int argc, JSValueConst *argv)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<JSValue>, Pointer<JSValue>, Int32, Pointer<JSValue>)>(symbol: 'jsCall')
external Pointer<JSValue> _jsCall(Pointer<JSContext> ctx, Pointer<JSValue> funcObj, Pointer<JSValue> thisObj, int argc, Pointer<JSValue> argv);

Pointer<JSValue> jsCall(
  Pointer<JSContext> ctx,
  Pointer<JSValue> funcObj,
  Pointer<JSValue> thisObj,
  List<Pointer<JSValue>> argv,
) {
  final jsArgs = calloc<Uint8>(
    argv.isNotEmpty ? sizeOfJSValue * argv.length : 1,
  ).cast<JSValue>();
  for (int i = 0; i < argv.length; ++i) {
    Pointer<JSValue> jsArg = argv[i];
    setJSValueList(jsArgs, i, jsArg);
  }
  final func1 = jsDupValue(ctx, funcObj);
  final thisObj0 = thisObj;
  final jsRet = _jsCall(ctx, funcObj, thisObj0, argv.length, jsArgs);
  jsFreeValue(ctx, func1);
  malloc.free(jsArgs);
  runtimeOpaques[jsGetRuntime(ctx)]?._port.sendPort.send(#call);
  return jsRet;
}

/// int jsIsException(JSValueConst *val)
@Native<Int32 Function(Pointer<JSValue>)>(symbol: 'jsIsException')
external int jsIsException(Pointer<JSValue> val);

/// JSValue *jsGetException(JSContext *ctx)
@Native<Pointer<JSValue> Function(Pointer<JSContext>)>(symbol: 'jsGetException')
external Pointer<JSValue> jsGetException(Pointer<JSContext> ctx);

/// int jsExecutePendingJob(JSRuntime *rt)
@Native<Int32 Function(Pointer<JSRuntime>)>(symbol: 'jsExecutePendingJob')
external int jsExecutePendingJob(Pointer<JSRuntime> ctx);

/// JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
@Native<Pointer<JSValue> Function(Pointer<JSContext>, Pointer<JSValue>)>(symbol: 'jsNewPromiseCapability')
external Pointer<JSValue> jsNewPromiseCapability(Pointer<JSContext> ctx, Pointer<JSValue> resolvingFuncs);

/// void jsFree(JSContext *ctx, void *ptab)
@Native<Void Function(Pointer<JSContext>, Pointer<JSPropertyEnum>)>(symbol: 'jsFree')
external void jsFree(Pointer<JSContext> ctx, Pointer<JSPropertyEnum> ptab);
