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

  test('exposes a Dart function to JS through a channel', () {
    runtime.onMessage('greet', (dynamic args) => 'hi ${args[0]}');
    final result = runtime.evaluate(
      'sendMessage("greet", JSON.stringify(["world"]));',
    );
    expect(result.stringResult, 'hi world');
  });
}
