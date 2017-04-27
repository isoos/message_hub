import 'dart:async';
import 'dart:convert';
import 'dart:html';

import '../message_hub.dart';

class WebSocketBrowserChannel extends DuplexChannel {
  final WebSocket _socket;
  WebSocketBrowserChannel(this._socket);

  @override
  Stream<Packet> get onPacket =>
      _socket.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (MessageEvent event, EventSink<Packet> sink) {
        if (event.data is String) {
          Map map = JSON.decode(event.data);
          sink.add(new Packet.fromMap(map));
        }
      }));

  @override
  Future send(Packet envelope) async {
    _socket.sendString(JSON.encode(envelope.toMap()));
  }
}
