import 'dart:async';
import 'dart:html';

import '../message_hub.dart';

class WindowChannel extends DuplexChannel {
  Window _window;
  WindowChannel([Window w]) {
    _window = w ?? window;
  }

  @override
  Stream<Packet> get onPacket =>
      _window.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (MessageEvent event, EventSink<Packet> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Packet.fromMap(map));
        }
      }));

  @override
  Future send(Packet envelope) async {
//    List transfer;
//    if (envelope.data is ByteBuffer) {
//      transfer = [envelope.data];
//    }
//    worker.postMessage(envelope.toMap(), '*', transfer);
    // TODO: use code above when postMessage accepts all kinds of Transferables
    _window.postMessage(envelope.toMap(), '*');
  }
}
