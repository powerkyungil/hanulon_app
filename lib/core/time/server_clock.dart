import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerClock {
  Duration _offset = Duration.zero;

  Duration get offset => _offset;

  DateTime now({DateTime? localNow}) {
    return (localNow ?? DateTime.now()).add(_offset);
  }

  void synchronize({required int serverEpochMilliseconds, DateTime? localNow}) {
    final local = localNow ?? DateTime.now();
    final server = DateTime.fromMillisecondsSinceEpoch(serverEpochMilliseconds);
    _offset = server.difference(local);
  }
}

final serverClockProvider = Provider<ServerClock>((ref) => ServerClock());
