import 'dart:async';
import 'dart:typed_data';

import '../message_hub.dart';

import 'package:service_worker/window.dart' as sw;

class ServiceWorkerWindowMessageHub extends MessageHubBase {
  @override
  Stream<Envelope> get onEnvelope =>
      sw.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (sw.MessageEvent event, EventSink<Envelope> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Envelope.fromMap(map));
        }
      }));

  @override
  Future postEnvelope(Envelope envelope) async {
    sw.ServiceWorkerRegistration registration = await sw.ready;
    List transfer;
    if (envelope.data is ByteBuffer) {
      transfer = [envelope.data];
    }
    registration.active.postMessage(envelope.toMap(), transfer);
  }
}
