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
```
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
```
add the following lines before `registerWith()`
```
  Logger.root.level = Level.ALL;
  final df = DateFormat("HH:mm:ss.SSS");
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}.${record.level.name}: ${df.format(record.time)}: ${record.message}');
  });
```
and
```
Past log here
```
