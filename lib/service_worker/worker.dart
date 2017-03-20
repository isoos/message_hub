import 'dart:async';
import 'dart:typed_data';

import '../message_hub.dart';

import 'package:service_worker/worker.dart' as sw;

class ServiceWorkerMessageHub extends MessageHubBase {
  @override
  Stream<Envelope> get onEnvelope =>
      sw.onMessage.transform(new StreamTransformer.fromHandlers(handleData:
          (sw.ExtendableMessageEvent event, EventSink<Envelope> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Envelope.fromMap(map, client: event.source));
        }
      }));

  @override
  Future postEnvelope(Envelope envelope) async {
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
