import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../message_hub.dart';

class WebSocketConsoleMessageHub extends MessageHubBase {
  final WebSocket _socket;
  WebSocketConsoleMessageHub(this._socket);

  @override
  Stream<Envelope> get onEnvelope =>
      _socket.transform(new StreamTransformer.fromHandlers(
          handleData: (event, EventSink<Envelope> sink) {
        if (event is String) {
          Map map = JSON.decode(event);
          sink.add(new Envelope.fromMap(map));
        }
      }));

  @override
  Future postEnvelope(Envelope envelope) async {
    _socket.add(JSON.encode(envelope.toMap()));
  }
}
