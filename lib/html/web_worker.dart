import 'dart:async';
import 'dart:html';

import '../message_hub.dart';

class WebWorkerChannel extends DuplexChannel {
  final Worker _worker;
  WebWorkerChannel(this._worker);

  @override
  Stream<Packet> get onPacket =>
      _worker.onMessage.transform(new StreamTransformer.fromHandlers(
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
//    worker.postMessage(envelope.toMap(), transfer);
    // TODO: use code above when postMessage accepts all kinds of Transferables
    _worker.postMessage(envelope.toMap());
  }
}
