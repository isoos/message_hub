import 'dart:async';
import 'dart:typed_data';

import '../message_hub.dart';

import 'package:service_worker/worker.dart' as sw;

class ServiceWorkerWorkerChannel extends DuplexChannel {
  @override
  Stream<Packet> get onPacket =>
      sw.onMessage.transform(new StreamTransformer.fromHandlers(handleData:
          (sw.ExtendableMessageEvent event, EventSink<Packet> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Packet.fromMap(map, client: event.source));
        }
      }));

  @override
  Future send(Packet envelope) async {
    if (envelope.client != null) {
      List transfer;
      if (envelope.data is ByteBuffer) {
        transfer = [envelope.data];
      }
      sw.ServiceWorkerClient client = envelope.client;
      client.postMessage(envelope.toMap(), transfer);
    } else {
      List<sw.ServiceWorkerClient> clients = await sw.clients.matchAll();
      for (var client in clients) {
        client.postMessage(envelope.toMap());
      }
    }
  }
}
