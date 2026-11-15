/// Start time from a W3C Media Fragments URI (`#t=104`, `#t=npt:1:44.5`,
/// `#t=104,200`), split off the URI.
///
/// Returns the URI without the `t` parameter and the start in milliseconds,
/// or the URI unchanged and 0 when there is no valid `t`. Other fragment
/// parameters are kept. https://www.w3.org/TR/media-frags/#naming-time
({String uri, int startMs}) takeMediaFragmentStart(String uri) {
  final hash = uri.indexOf('#');
  if (hash < 0) return (uri: uri, startMs: 0);
  final params = uri.substring(hash + 1).split('&');
  final i = params.indexWhere((p) => p.startsWith('t='));
  if (i < 0) return (uri: uri, startMs: 0);
  final startMs = _parseNpt(params[i].substring(2).split(',').first);
  if (startMs == null) return (uri: uri, startMs: 0);
  params.removeAt(i);
  final base = uri.substring(0, hash);
  return (
    uri: params.isEmpty ? base : '$base#${params.join('&')}',
    startMs: startMs,
  );
}

/// Normal Play Time: `[npt:]SECONDS[.frac]` or `[npt:][HH:]MM:SS[.frac]`.
int? _parseNpt(String value) {
  var v = value.startsWith('npt:') ? value.substring(4) : value;
  if (v.isEmpty) return null;
  final parts = v.split(':');
  if (parts.length > 3) return null;
  var seconds = 0.0;
  for (final p in parts) {
    final n = double.tryParse(p);
    if (n == null || n < 0) return null;
    seconds = seconds * 60 + n;
  }
  return (seconds * 1000).round();
}
