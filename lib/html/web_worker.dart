import 'dart:async';
import 'dart:html';

import '../message_hub.dart';

class WebWorkerMessageHub extends MessageHubBase {
  final Worker _worker;
  WebWorkerMessageHub(this._worker);

  @override
  Stream<Message> get onMessage =>
      _worker.onMessage.transform(new StreamTransformer.fromHandlers(
          handleData: (MessageEvent event, EventSink<Message> sink) {
        if (event.data is Map) {
          Map map = event.data;
          sink.add(new Message.fromMap(map));
        }
      }));

  @override
  Future postMessage(Message message) async {
//    List transfer;
//    if (message.data is ByteBuffer) {
//      transfer = [message.data];
//    }
//    worker.postMessage(message.toMap(), transfer);
    // TODO: use code above when postMessage accepts all kinds of Transferables
    _worker.postMessage(message.toMap());
  }
}
