import 'dart:async';
import 'dart:html';

import '../message_hub.dart';

class WindowMessageHub extends MessageHubBase {
  Window _window;
  WindowMessageHub([Window w]) {
    _window = w ?? window;
  }

  @override
  Stream<Envelope> get onEnvelope =>
      _window.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (MessageEvent event, EventSink<Envelope> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Envelope.fromMap(map));
        }
      }));

  @override
  Future postEnvelope(Envelope envelope) async {
//    List transfer;
//    if (envelope.data is ByteBuffer) {
//      transfer = [envelope.data];
//    }
//    worker.postMessage(envelope.toMap(), '*', transfer);
    // TODO: use code above when postMessage accepts all kinds of Transferables
    _window.postMessage(envelope.toMap(), '*');
  }
}
