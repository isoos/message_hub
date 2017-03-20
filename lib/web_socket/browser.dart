import 'dart:async';
import 'dart:convert';
import 'dart:html';

import '../message_hub.dart';

class WebSocketBrowserMessageHub extends MessageHubBase {
  final WebSocket _socket;
  WebSocketBrowserMessageHub(this._socket);

  @override
  Stream<Envelope> get onEnvelope =>
      _socket.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (MessageEvent event, EventSink<Envelope> sink) {
        if (event.data is String) {
          Map map = JSON.decode(event.data);
          sink.add(new Envelope.fromMap(map));
        }
      }));

  @override
  Future postEnvelope(Envelope envelope) async {
    _socket.sendString(JSON.encode(envelope.toMap()));
  }
}
