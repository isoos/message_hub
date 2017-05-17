import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:message_hub/message_hub.dart';
import 'package:message_hub/native/isolate.dart';

Future main() async {
  ReceivePort mainReceivePort = new ReceivePort();
  ReceivePort channelReceivePort = new ReceivePort();
  Future<SendPort> isolateSendPortFuture = mainReceivePort.first;

  Isolate iso = await Isolate.spawn(
      _startIsolate, [mainReceivePort.sendPort, channelReceivePort.sendPort]);

  MessageHub mainHub = new MessageHub(
      new IsolateChannel(await isolateSendPortFuture, channelReceivePort));

  UnaryHubFn primeFn = mainHub.bindUnaryCaller(
    'factorization',
    requestEncoder: (Request r) => r.toMap(),
    replyDecoder: (Map map) => new Response.fromMap(map),
  );

  // measure the overhead too
  Stopwatch sw = new Stopwatch()..start();
  Response r = await primeFn(new Request(349857394857398457));
  sw.stop();

  print('found: ${r.factors} in '
      '${r.duration.inMilliseconds} ms, with the overhead of '
      '${(sw.elapsed - r.duration).inMilliseconds} ms.');

  // close processing
  iso.kill();
  channelReceivePort.close();
}

void _startIsolate(List<SendPort> sendPorts) {
  SendPort mainSendPort = sendPorts[0];
  SendPort channelSendPort = sendPorts[1];
  ReceivePort isolateReceivePort = new ReceivePort();

  MessageHub isolateHub =
      new MessageHub(new IsolateChannel(channelSendPort, isolateReceivePort));

  isolateHub.listen(
    'factorization',
    (Request request, Sink<Response> replySink) async {
      Stopwatch sw = new Stopwatch()..start();
      List<int> factors = _calculateFactors(request.value);
      sw.stop();
      replySink.add(new Response(sw.elapsed, factors));
      // sink should auto-close when this closure's returned Future completes,
      // but could do it manually for efficiency:
      // replySink.close();
    },
    requestDecoder: (map) => new Request.fromMap(map),
    replyEncoder: (Response r) => r.toMap(),
  );

  mainSendPort.send(isolateReceivePort.sendPort);
}

// Inefficient, but I wanted the CPU to spend some time on the factorization.
List<int> _calculateFactors(int value) {
  if (value <= 3) return [value];
  List<int> factors = [];
  while (value > 1) {
    int root = sqrt(value).floor();
    bool found = false;
    for (int i = 2; i <= root; i++) {
      if (value % i == 0) {
        factors.add(i);
        value = value ~/ i;
        found = true;
        break;
      }
    }
    if (!found) {
      factors.add(value);
      value = 1;
    }
  }
  return factors;
}

class Request {
  int value;

  Request(this.value);

  factory Request.fromMap(Map map) => new Request(map['value']);

  Map toMap() => {
        'value': value,
      };
}

class Response {
  Duration duration;
  List<int> factors;

  Response(this.duration, this.factors);

  factory Response.fromMap(Map map) =>
      new Response(new Duration(microseconds: map['duration']), map['factors']);

  Map toMap() => {
        'duration': duration.inMicroseconds,
        'factors': factors,
      };
}
