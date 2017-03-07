import 'dart:async';

typedef Future<S> AsyncFunction<Q, S>(Q request);
typedef O WireAdapter<I, O>(I input);

abstract class MessageHub {

  AsyncFunction<Q, S> registerFunction<Q, S>(
    String type, {
    WireAdapter<Q, dynamic> requestEncoder,
    WireAdapter<dynamic, S> responseDecoder,
  });

  void registerHandler<Q, S>(
    String type,
    AsyncFunction<FutureOr<Q>, S> handler, {
    WireAdapter<dynamic, Q> requestDecoder,
    WireAdapter<S, dynamic> responseEncoder,
  });

  Sink<T> registerSink<T>(
    String type, {
    WireAdapter<T, dynamic> encoder,
  });

  Stream<T> registerStream<T>(
    String type, {
    WireAdapter<dynamic, T> decoder,
  });
}

class Message {
  final String type;
  final String requestId;
  final String inReplyTo;
  final String error;
  final bool isClose;
  final data;
  // transient on the wire
  final dynamic client;

  Message(this.type,
      {this.requestId,
      this.inReplyTo,
      this.error,
      this.data,
      this.isClose,
      this.client});

  factory Message.fromMap(Map map, {dynamic client}) => new Message(map['type'],
      requestId: map['requestId'],
      inReplyTo: map['inReplyTo'],
      error: map['error'],
      data: map['data'],
      isClose: map['isClose'],
      client: client);

  Map toMap() => {
        'type': type,
        'requestId': requestId,
        'inReplyTo': inReplyTo,
        'error': error,
        'isClose': isClose,
        'data': data,
      };
}

typedef void _MessageHandler(Message message);

abstract class MessageHubBase implements MessageHub {
  Map<String, _MessageHandler> _handlers = {};
  Map<String, Completer> _completers = {};
  StreamSubscription _subscription;
  int _requestCounter = 0;

  Stream<Message> get onMessage;
  Future postMessage(Message message);

  @override
  AsyncFunction<Q, S> registerFunction<Q, S>(String type,
      {WireAdapter<Q, dynamic> requestEncoder,
      WireAdapter<dynamic, S> responseDecoder}) {
    _initIfRequired();
    String handlerKey = _replyKey(type);
    if (_handlers.containsKey(handlerKey)) {
      throw new Exception('Type $type already registered.');
    }
    _handlers[handlerKey] = (Message message) {
      Completer c = _completers.remove(message.inReplyTo);
      if (c == null) return;
      if (message.error == null) {
        var data = message.data;
        if (responseDecoder != null && data != null) {
          data = responseDecoder(data);
        }
        c.complete(data);
      } else {
        c.completeError(message.error);
      }
    };
    String requestKey = _requestKey(type);
    return (Q request) {
      String requestId = _generateRequestId();
      var data = request;
      if (requestEncoder != null && data != null) {
        data = requestEncoder(data);
      }
      Completer<S> c = _registerCompleter(requestId);
      postMessage(new Message(requestKey, data: data, requestId: requestId));
      return c.future;
    };
  }

  @override
  void registerHandler<Q, S>(String type, AsyncFunction<FutureOr<Q>, S> handler,
      {WireAdapter<dynamic, Q> requestDecoder,
      WireAdapter<S, dynamic> responseEncoder}) {
    _initIfRequired();
    String requestKey = _requestKey(type);
    if (_handlers.containsKey(requestKey)) {
      throw new Exception('Type $type already registered.');
    }
    String replyKey = _replyKey(type);
    _handlers[requestKey] = (Message message) async {
      var rq = message.data;
      if (rq != null && requestDecoder != null) {
        rq = requestDecoder(rq);
      }
      try {
        var rs = await handler(rq);
        if (rs != null && responseEncoder != null) {
          rs = responseEncoder(rs);
        }
        await postMessage(new Message(replyKey,
            data: rs, inReplyTo: message.requestId, client: message.client));
      } catch (e) {
        await postMessage(new Message(replyKey,
            error: e.toString(),
            inReplyTo: message.requestId,
            client: message.client));
      }
    };
  }

  @override
  Sink<T> registerSink<T>(String type, {WireAdapter<T, dynamic> encoder}) {
    StreamController<T> controller = new StreamController<T>.broadcast();
    controller.stream.listen((event) {
      var data = event;
      if (encoder != null && data != null) {
        data = encoder(data);
      }
      postMessage(new Message(type, data: data));
    }, onDone: () {
      postMessage(new Message(type, isClose: true));
    });
    return controller;
  }

  @override
  Stream<T> registerStream<T>(String type, {WireAdapter<dynamic, T> decoder}) {
    StreamController<T> controller = new StreamController<T>.broadcast();
    _handlers[type] = (Message message) {
      if (message.isClose == true) {
        controller.close();
      } else {
        var data = message.data;
        if (decoder != null && data != null) {
          data = decoder(data);
        }
        controller.add(data);
      }
    };
    return controller.stream;
  }

  String _generateRequestId() {
    _requestCounter++;
    return '$_requestCounter-${new DateTime.now().microsecondsSinceEpoch}';
  }

  void _initIfRequired() {
    if (_subscription != null) return;
    _subscription = onMessage.listen((Message message) {
      _MessageHandler handler = _handlers[message.type];
      if (handler == null) {
        // TODO: log
        return;
      }
      // TODO: try-catch-and-log
      handler(message);
    });
  }

  String _replyKey(String type) => '\$reply-for-$type';
  String _requestKey(String type) => '\$request-for-$type';

  // TODO: add some kind of timeout handling
  Completer<T> _registerCompleter<T>(String requestId) {
    Completer<T> c = new Completer();
    _completers[requestId] = c;
    return c;
  }
}
