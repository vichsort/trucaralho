abstract interface class StateSerializer<S> {
  Map<String, dynamic> serialize(S state);
  S deserialize(Map<String, dynamic> data);
}

final class JsonStateSerializer<S> implements StateSerializer<S> {
  final Map<String, dynamic> Function(S) _encode;
  final S Function(Map<String, dynamic>) _decode;

  const JsonStateSerializer({
    required Map<String, dynamic> Function(S) encode,
    required S Function(Map<String, dynamic>) decode,
  })  : _encode = encode,
        _decode = decode;

  @override
  Map<String, dynamic> serialize(S state) => _encode(state);

  @override
  S deserialize(Map<String, dynamic> data) => _decode(data);
}
