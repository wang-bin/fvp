import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/src/media_fragment.dart';

void main() {
  test('no fragment leaves the URI alone', () {
    expect(takeMediaFragmentStart('http://h/v.mp4'),
        (uri: 'http://h/v.mp4', startMs: 0));
  });

  test('seconds', () {
    expect(takeMediaFragmentStart('http://h/v.mp4#t=104'),
        (uri: 'http://h/v.mp4', startMs: 104000));
    expect(takeMediaFragmentStart('http://h/v.mp4#t=104.25'),
        (uri: 'http://h/v.mp4', startMs: 104250));
  });

  test('npt prefix, clock form and an end time', () {
    expect(takeMediaFragmentStart('http://h/v.mp4#t=npt:1:44'),
        (uri: 'http://h/v.mp4', startMs: 104000));
    expect(takeMediaFragmentStart('http://h/v.mp4#t=1:00:01.5,1:10:00'),
        (uri: 'http://h/v.mp4', startMs: 3601500));
  });

  test('keeps other fragment parameters', () {
    expect(takeMediaFragmentStart('http://h/v.mp4#t=5&track=audio'),
        (uri: 'http://h/v.mp4#track=audio', startMs: 5000));
  });

  test('a fragment that is not a valid time is left alone', () {
    expect(takeMediaFragmentStart('http://h/v.mp4#section'),
        (uri: 'http://h/v.mp4#section', startMs: 0));
    expect(takeMediaFragmentStart('http://h/v.mp4#t=abc'),
        (uri: 'http://h/v.mp4#t=abc', startMs: 0));
  });
}
