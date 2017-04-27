import 'dart:async';
import 'dart:typed_data';

import '../message_hub.dart';

import 'package:service_worker/window.dart' as sw;

/// A [DuplexChannel] that handles the ServiceWorker's Window-side.
class ServiceWorkerWindowChannel extends DuplexChannel {
  @override
  Stream<Packet> get onPacket =>
      sw.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (sw.MessageEvent event, EventSink<Packet> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Packet.fromMap(map));
        }
      }));

  @override
  Future send(Packet packet) async {
    List transfer;
    if (packet.data is ByteBuffer) {
      transfer = [packet.data];
    }
    sw.ServiceWorkerRegistration registration = await sw.ready;
    registration.active.postMessage(packet.toMap(), transfer);
  }
}
