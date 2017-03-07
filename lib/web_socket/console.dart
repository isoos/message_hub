import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../message_hub.dart';

class WebSocketConsoleMessageHub extends MessageHubBase {
  final WebSocket _socket;
  WebSocketConsoleMessageHub(this._socket);

  @override
  Stream<Message> get onMessage =>
      _socket.transform(new StreamTransformer.fromHandlers(
          handleData: (event, EventSink<Message> sink) {
        if (event is String) {
          Map map = JSON.decode(event);
          sink.add(new Message.fromMap(map));
        }
      }));

  @override
  Future postMessage(Message message) async {
    _socket.add(JSON.encode(message.toMap()));
  }
}
