---
name: Bug report
about: Report bugs
title: ''
labels: ''
assignees: ''

---

**Describe the bug**

A clear and concise description of what the bug is.


**Expected behavior**

A clear and concise description of what you expected to happen.

**Log**

Add
```dart
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
```
add the following lines before `registerWith()`
```dart
  Logger.root.level = Level.ALL;
  final df = DateFormat("HH:mm:ss.SSS");
  Logger.root.onRecord.listen((record) {
    debugPrint(
        '${record.loggerName}.${record.level.name}: ${df.format(record.time)}: ${record.message}',
        wrapWidth: 0x7FFFFFFFFFFFFFFF);
  });
```
and

<details>
<summary>log</summary>

```
PASTE LOG HERE
```
</details>
