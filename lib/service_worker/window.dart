import 'dart:async';
import 'dart:typed_data';

import '../message_hub.dart';

import 'package:service_worker/window.dart' as sw;

class ServiceWorkerWindowMessageHub extends MessageHubBase {
  @override
  Stream<Message> get onMessage =>
      sw.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (sw.MessageEvent event, EventSink<Message> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Message.fromMap(map));
        }
      }));

  @override
  Future postMessage(Message message) async {
    sw.ServiceWorkerRegistration registration = await sw.ready;
    List transfer;
    if (message.data is ByteBuffer) {
      transfer = [message.data];
    }
    registration.active.postMessage(message.toMap(), transfer);
  }
}
