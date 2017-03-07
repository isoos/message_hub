import 'dart:async';
import 'dart:typed_data';

import '../message_hub.dart';

import 'package:service_worker/worker.dart' as sw;

class ServiceWorkerMessageHub extends MessageHubBase {
  @override
  Stream<Message> get onMessage =>
      sw.onMessage.transform(new StreamTransformer.fromHandlers(handleData:
          (sw.ExtendableMessageEvent event, EventSink<Message> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Message.fromMap(map, client: event.source));
        }
      }));

  @override
  Future postMessage(Message message) async {
    if (message.client != null) {
      List transfer;
      if (message.data is ByteBuffer) {
        transfer = [message.data];
      }
      sw.ServiceWorkerClient client = message.client;
      client.postMessage(message.toMap(), transfer);
    } else {
      List<sw.ServiceWorkerClient> clients = await sw.clients.matchAll();
      for (var client in clients) {
        client.postMessage(message.toMap());
      }
    }
  }
}
