import 'dart:async';
import 'dart:convert';
import 'dart:html';

import '../message_hub.dart';

class WebSocketBrowserMessageHub extends MessageHubBase {
  final WebSocket _socket;
  WebSocketBrowserMessageHub(this._socket);

  @override
  Stream<Message> get onMessage =>
      _socket.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (MessageEvent event, EventSink<Message> sink) {
        if (event.data is String) {
          Map map = JSON.decode(event.data);
          sink.add(new Message.fromMap(map));
        }
      }));

  @override
  Future postMessage(Message message) async {
    _socket.sendString(JSON.encode(message.toMap()));
  }
}
