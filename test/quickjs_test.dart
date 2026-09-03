// Exercises the QuickJS engine directly. `getJavascriptRuntime()` picks JavaScriptCore on
// macOS hosts, so these tests instantiate `QuickJsRuntime2` explicitly to cover the code asset
// built by `hook/build.dart` and the `@Native` bindings in `lib/quickjs/ffi.dart`.
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuickJsRuntime2 runtime;

  setUp(() => runtime = QuickJsRuntime2());
  tearDown(() {
    try {
      runtime.dispose();
    } on Error catch (_) {}
  });

  String eval(String code) => runtime.evaluate(code).stringResult;

  test('evaluates arithmetic', () {
    expect(eval('Math.pow(5,3)'), '125');
  });

  test('converts primitive types back to Dart', () {
    expect(runtime.evaluate('1 + 1').rawResult, 2);
    expect(runtime.evaluate('1.5 + 1').rawResult, 2.5);
    expect(runtime.evaluate('true').rawResult, true);
    expect(runtime.evaluate('"hello"').rawResult, 'hello');
  });

  test('round-trips a long concatenated string', () {
    // quickjs-ng tags lazily-concatenated strings as JS_TAG_STRING_ROPE rather than
    // JS_TAG_STRING; `_jsToDart` has to accept both or this comes back null.
    final result = runtime.evaluate('''
      let s = "";
      for (let i = 0; i < 500; i++) s += "abcdefghij";
      s;
    ''');
    expect(result.rawResult, isA<String>());
    expect((result.rawResult as String).length, 5000);
  });

  test('runs on quickjs-ng, not the 2021 QuickJS', () {
    expect(quickJsVersion, '0.16.2');
    // Array.prototype.toSorted (ES2023) and Object.groupBy (ES2024) both postdate the
    // 2021-03-27 release this package used to bundle.
    expect(eval('JSON.stringify([3,1,2].toSorted())'), '[1,2,3]');
    expect(eval('JSON.stringify(Object.groupBy([1,2,3], (n) => n % 2))'),
        contains('"1"'));
    expect(eval('"abc".at(-1)'), 'c');
  });

  test('reports errors with a stack', () {
    final result = runtime.evaluate('null.foo');
    expect(result.isError, isTrue);
    expect(result.stringResult, contains('TypeError'));
  });

  test('resolves promises through the event loop', () async {
    final result = await runtime.evaluateAsync('''
      new Promise((resolve) => resolve(41 + 1));
    ''');
    runtime.executePendingJob();
    final resolved = await runtime.handlePromise(result);
    expect(resolved.stringResult, '42');
  });

  // Upstream abner/flutter_js#182 reports a leak on repeated failing evaluations. QuickJS's
  // own allocator accounting says otherwise: error results carry no owned reference, so the
  // three common failure shapes settle flat.
  test('repeated failing evaluations do not grow the runtime', () {
    for (final script in const [
      'function ( { bad syntax %%%', // SyntaxError
      'null.foo.bar', // runtime TypeError
      'function a(){ throw new Error("boom ".repeat(60)); } a();',
    ]) {
      final rt = QuickJsRuntime2();
      for (var i = 0; i < 100; i++) {
        expect(rt.evaluate(script).isError, isTrue);
      }
      final baseline = rt.memoryUsage;
      for (var i = 0; i < 2000; i++) {
        rt.evaluate(script);
      }
      expect(rt.memoryUsage, baseline, reason: 'leaked on: $script');
      rt.dispose();
    }
  });

  // A function-valued result hands the caller a JSRef it owns. Freeing it settles the runtime;
  // dropping it grows the runtime without bound, which is the real "grows until it crashes"
  // shape on a long-lived runtime.
  test('function-valued results must be freed by the caller', () {
    final freed = QuickJsRuntime2();
    for (var i = 0; i < 100; i++) {
      JSRef.freeRecursive(freed.evaluate('(function(){ return 1; })').rawResult);
    }
    final baseline = freed.memoryUsage;
    for (var i = 0; i < 2000; i++) {
      JSRef.freeRecursive(freed.evaluate('(function(){ return 1; })').rawResult);
    }
    expect(freed.memoryUsage, baseline);
    freed.dispose();

    final dropped = QuickJsRuntime2();
    for (var i = 0; i < 100; i++) {
      dropped.evaluate('(function(){ return 1; })');
    }
    final droppedBaseline = dropped.memoryUsage;
    for (var i = 0; i < 2000; i++) {
      dropped.evaluate('(function(){ return 1; })');
    }
    expect(dropped.memoryUsage, greaterThan(droppedBaseline),
        reason: 'documents the ownership contract; not a desired behaviour');
    dropped.dispose();
  });

  // moodiary's sandbox builds and disposes a runtime per call, so teardown has to stay safe
  // even when the caller never frees a returned JSRef. jsFreeRuntime raises the leak report as
  // a bare String, close() converts it to a JSError, and dispose() swallows that.
  test('dispose() is safe when the caller leaks a JSRef', () {
    final leaky = QuickJsRuntime2();
    expect(leaky.evaluate('(function(){ return 1; })').rawResult, isNotNull);
    expect(leaky.dispose, returnsNormally);

    final nested = QuickJsRuntime2();
    expect(nested.evaluate('({ handler: function(){}, name: "x" })').rawResult,
        isA<Map>());
    expect(nested.dispose, returnsNormally);
  });

  test('exposes a Dart function to JS through a channel', () {
    runtime.onMessage('greet', (dynamic args) => 'hi ${args[0]}');
    final result = runtime.evaluate(
      'sendMessage("greet", JSON.stringify(["world"]));',
    );
    expect(result.stringResult, 'hi world');
  });
}
