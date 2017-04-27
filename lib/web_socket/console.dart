import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../message_hub.dart';

class WebSocketConsoleChannel extends DuplexChannel {
  final WebSocket _socket;
  WebSocketConsoleChannel(this._socket);

  @override
  Stream<Packet> get onPacket =>
      _socket.transform(new StreamTransformer.fromHandlers(
          handleData: (event, EventSink<Packet> sink) {
        if (event is String) {
          Map map = JSON.decode(event);
          sink.add(new Packet.fromMap(map));
        }
      }));

  @override
  Future send(Packet envelope) async {
    _socket.add(JSON.encode(envelope.toMap()));
  }
}
