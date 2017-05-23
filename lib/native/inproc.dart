import 'dart:async';

import '../message_hub.dart';

class InprocChannel extends DuplexChannel {
  final StreamController<Packet> _controller = new StreamController.broadcast();

  @override
  Stream<Packet> get onPacket => _controller.stream;

  @override
  Future send(Packet packet) {
    _controller.add(packet);
    return null;
  }
}
