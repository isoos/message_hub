import 'dart:async';
import 'dart:collection';

/// A remote-aware message passing framework.
abstract class MessageHub {
  /// Registers an adapter for the [type]
  void registerAdapter(String type, WireAdapter adapter);

  /// Sends a message
  void sendMessage<T>(T message);

  /// Gets the stream of messages for [type] that are not request-reply.
  Stream<T> onMessage<T>(String type);

  /// Register a handler.
  void registerHandler<RQ, RS>(
      String requestType, void handleRequest(RQ request, Sink<RS> replySink));

  /// Invokes a remote handler that responds with a stream.
  Stream<RS> invoke<RQ, RS>(RQ request);

  /// Invokes a remote handler and return with its first reply.
  Future<RS> call<RQ, RS>(RQ request);
}

abstract class WireAdapter<T, W> {
  bool accept(T object);

  W encode(T object);
  T decode(W data);
}

class IdentityAdapter<T> implements WireAdapter<T, T> {
  @override
  bool accept(T object) =>
      object == null ||
      (object is num) ||
      (object is bool) ||
      (object is String);

  @override
  T encode(T object) => object;

  @override
  T decode(T data) => data;
}

class Envelope {
  final String type;
  final String requestId;
  final String inReplyTo;
  final String error;
  final bool isClose;
  final data;
  // transient on the wire
  final dynamic client;

  Envelope(
    this.type, {
    this.requestId,
    this.inReplyTo,
    this.error,
    this.data,
    this.isClose,
    this.client,
  });

  factory Envelope.fromMap(Map map, {dynamic client}) => new Envelope(
        map['type'],
        requestId: map['requestId'],
        inReplyTo: map['inReplyTo'],
        error: map['error'],
        data: map['data'],
        isClose: map['isClose'],
        client: client,
      );

  Map toMap() => {
        'type': type,
        'requestId': requestId,
        'inReplyTo': inReplyTo,
        'error': error,
        'isClose': isClose,
        'data': data,
      };
}

abstract class MessageHubBase implements MessageHub {
  List<_AdapterRegistration> _adapters = [];
  int _requestCounter = 0;

  Stream<Envelope> get onEnvelope;
  Future postEnvelope(Envelope message);

  @override
  void registerAdapter(String type, WireAdapter adapter) {
    if (_adapters.any((r) => r.type == type)) {
      throw new Exception(
          'An Adapter has been already registered for type: $type.');
    }
    _adapters.add(new _AdapterRegistration(type, adapter));
  }

  @override
  void sendMessage<T>(T message) {
    _AdapterRegistration ar = _selectRegistration(message);
    postEnvelope(new Envelope(
      ar.type,
      data: ar.adapter.encode(message),
    ));
  }

  @override
  Stream<T> onMessage<T>(String type) {
    WireAdapter adapter = _selectAdapter(type);
    return onEnvelope
        .where((Envelope envelope) =>
            envelope.type == type &&
            envelope.inReplyTo == null &&
            envelope.requestId == null)
        .transform(new StreamTransformer.fromHandlers(
            handleData: (Envelope envelope, EventSink<T> sink) {
      if (envelope.isClose) {
        // sink.close();
        return;
      }
      if (envelope.error != null) {
        sink.addError(envelope.error);
        return;
      }
      sink.add(_decodeData(adapter, envelope.data));
    }));
  }

  @override
  Stream<RS> invoke<RQ, RS>(RQ request) {
    _AdapterRegistration ar = _selectRegistration(request);
    String requestId = _generateRequestId();
    String responseType;
    WireAdapter responseAdapter;
    Stream<RS> stream = onEnvelope
        .where((Envelope envelope) => envelope.inReplyTo == requestId)
        .transform(new StreamTransformer.fromHandlers(
            handleData: (Envelope envelope, EventSink<RS> sink) {
      if (envelope.isClose) {
        sink.close();
        return;
      }
      if (envelope.error != null) {
        sink.addError(envelope.error);
        sink.close();
        return;
      }
      if (responseAdapter == null) {
        responseType = envelope.type;
        responseAdapter = _selectAdapter(envelope.type);
      } else if (responseType != envelope.type) {
        throw new Exception('Type mismatch: $responseType != ${envelope.type}');
      }
      sink.add(_decodeData(responseAdapter, envelope.data));
    }));
    postEnvelope(new Envelope(
      ar.type,
      requestId: requestId,
      data: ar.adapter.encode(request),
    ));
    return stream;
  }

  @override
  Future<RS> call<RQ, RS>(RQ request) {
    return invoke<RQ, RS>(request).first;
  }

  @override
  void registerHandler<RQ, RS>(
      String requestType, void handleRequest(RQ request, Sink<RS> replySink)) {
    WireAdapter requestAdapter = _selectAdapter(requestType);
    String responseType;
    WireAdapter responseAdapter;
    onEnvelope
        .where((Envelope envelope) =>
            envelope.type == requestType && envelope.requestId != null)
        .listen((Envelope envelope) {
      var data = _decodeData(requestAdapter, envelope.data);
      StreamController<RS> controller = new StreamController();
      controller.stream.listen((RS event) {
        if (responseAdapter == null) {
          _AdapterRegistration ar = _selectRegistration(event);
          responseType = ar.type;
          responseAdapter = ar.adapter;
        }
        postEnvelope(new Envelope(responseType,
            inReplyTo: envelope.requestId,
            data: responseAdapter.encode(event),
            client: envelope.client));
      }, onError: (e) {
        postEnvelope(new Envelope(
          responseType,
          inReplyTo: envelope.requestId,
          error: e.toString(),
          client: envelope.client,
        ));
      }, onDone: () {
        postEnvelope(new Envelope(responseType,
            inReplyTo: envelope.requestId,
            isClose: true,
            client: envelope.client));
      });
      try {
        handleRequest(data, controller.sink);
      } catch (e) {
        postEnvelope(new Envelope(
          responseType,
          inReplyTo: envelope.requestId,
          error: e.toString(),
          client: envelope.client,
        ));
        controller.close();
      }
    });
  }

  WireAdapter _selectAdapter(String type) => _adapters
      .firstWhere((r) => r.type == type,
          orElse: () => throw new Exception('No adapter for type $type.'))
      .adapter;

  _AdapterRegistration _selectRegistration(dynamic object) =>
      _adapters.firstWhere((r) => r.adapter.accept(object),
          orElse: () =>
              throw new Exception('No suitable adapter for $object.'));

  dynamic _decodeData(WireAdapter adapter, dynamic data) {
    if (data == null) return null;
    return adapter == null ? data : adapter.decode(data);
  }

  String _generateRequestId() {
    _requestCounter++;
    return '$_requestCounter-${new DateTime.now().microsecondsSinceEpoch}';
  }
}

class _AdapterRegistration {
  final String type;
  final WireAdapter adapter;
  _AdapterRegistration(this.type, this.adapter);
}
