import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../message_hub.dart';

class IsolateChannel extends DuplexChannel {
  final SendPort _sendPort;
  final ReceivePort _receivePort;

  IsolateChannel(this._sendPort, this._receivePort);

  @override
  Stream<Packet> get onPacket =>
      _receivePort.transform(new StreamTransformer.fromHandlers(
          handleData: (message, EventSink<Packet> sink) {
        if (message is Map) {
          sink.add(new Packet.fromMap(message));
        } else if (message is String) {
          sink.add(new Packet.fromMap(JSON.decode(message)));
        } else {
          throw new Exception('Unable to decode Packet.');
        }
      }));

  @override
  FutureOr send(Packet packet) {
    _sendPort.send(packet.toMap());
    return null;
  }
}
