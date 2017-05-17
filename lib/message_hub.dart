import 'dart:async';
import 'dart:convert';

/// A generic messaging communication channel that
abstract class Channel {
  /// Subscribes to a specific topic.
  Stream<Packet> getTopic(String topic);

  /// Subscribes to a specific topic, and returns the request objects on it.
  Stream<Packet> getRequests(String topic);

  /// Subscribes to a specific topic, and returns the request objects on it.
  Stream<Packet> getReplies(String topic, String inReplyTo);

  /// Send a [Packet] to the other end.
  FutureOr send(Packet packet);
}

/// A bi-directional, full-duplex communication channel between two parts.
abstract class DuplexChannel extends Channel {
  Stream<Packet> _onPacketStream;

  /// The broadcast stream that emits values from the other endpoint.
  Stream<Packet> get onPacket;

  @override
  Stream<Packet> getTopic(String topic) {
    _onPacketStream ??= onPacket.asBroadcastStream();
    return _onPacketStream.where((p) => (p.topic == topic));
  }

  @override
  Stream<Packet> getRequests(String topic) =>
      getTopic(topic).where((p) => p.requestId != null && p.inReplyTo == null);

  @override
  Stream<Packet> getReplies(String topic, String inReplyTo) => getTopic(topic)
      .where((p) => p.inReplyTo != null && p.inReplyTo == inReplyTo);
}

///
class Packet {
  final String topic;
  final String requestId;
  final String inReplyTo;
  final String error;
  final bool isClose;
  final data;
  // transient on the wire
  final dynamic client;

  Packet(
    this.topic, {
    this.requestId,
    this.inReplyTo,
    this.error,
    this.data,
    this.isClose,
    this.client,
  });

  factory Packet.fromMap(Map map, {dynamic client}) => new Packet(
        map['topic'],
        requestId: map['requestId'],
        inReplyTo: map['inReplyTo'],
        error: map['error'],
        data: map['data'],
        isClose: map['isClose'],
        client: client,
      );

  Map toMap() => {
        'topic': topic,
        'requestId': requestId,
        'inReplyTo': inReplyTo,
        'error': error,
        'isClose': isClose,
        'data': data,
      };
}

/// A single-parameter async function that returns a [Future].
typedef Future<RS> UnaryHubFn<RQ, RS>(RQ request);

/// A single-parameter async function that returns a [Stream].
typedef Stream<RS> StreamHubFn<RQ, RS>(RQ request);

/// Handles [request] asynchronously, populating the [replySink] with one or
/// more reply objects.
/// Returns a [Future] that indicates the completion of the processing.
typedef Future RequestHandler<RQ, RS>(RQ request, Sink<RS> replySink);

/// Convert [source] object to target type [T].
typedef T Converter<S, T>(S source);

/// Cancel the async task.
typedef void Cancellable();

/// Messaging service abstraction.
abstract class MessageHub {
  /// Messaging service abstraction.
  factory MessageHub(Channel channel) => new _MessageHub(channel);

  /// Listen on messages from [topic], calling the [requestHandler] function to
  /// respond to each of these messages with zero, one or more replies.
  ///
  /// [requestDecoder] converts the wire-format (in [Packet]) to a typed object.
  /// [replyEncoder] converts the typed reply object to the wire format.
  ///
  /// Returns a subscription object to cancel the binding when it is no
  /// longer required.
  StreamSubscription listen<RQ, RS>(
    String topic,
    RequestHandler<RQ, RS> requestHandler, {
    Converter<dynamic, RQ> requestDecoder,
    Converter<RS, dynamic> replyEncoder,
  });

  /// Returns a function that can be used to send a request to [topic] and
  /// receives a single reply. (It will be processed on the other end by another
  /// process calling [listen] on the [topic].)
  ///
  /// [requestEncoder] converts the typed request object to the wire format.
  /// [replyDecoder] converts the wire-format (in [Packet]) to a typed object.
  UnaryHubFn<RQ, RS> bindUnaryCaller<RQ, RS>(
    String topic, {
    Converter<RQ, dynamic> requestEncoder,
    Converter<dynamic, RS> replyDecoder,
  });

  /// Returns a function that can be used to send a request to [topic] and
  /// receives multiple replies. (It will be processed on the other end by
  /// another process calling [listen] on the [topic].)
  ///
  /// [requestEncoder] converts the typed request object to the wire format.
  /// [replyDecoder] converts the wire-format (in [Packet]) to a typed object.
  StreamHubFn<RQ, RS> bindStreamCaller<RQ, RS>(
    String topic, {
    Converter<RQ, dynamic> requestEncoder,
    Converter<dynamic, RS> replyDecoder,
  });

  /// Returns a [Sink] that can be used to send typed messages to the [topic].
  ///
  /// [encoder] converts the typed request object to the wire format.
  Sink<T> getSink<T>(String topic, {Converter<T, dynamic> encoder});

  /// Returns a [Stream] of typed messages from [topic].
  ///
  /// [decoder] converts the wire format to [T].
  Stream<T> getStream<T>(String topic, {Converter<dynamic, T> decoder});
}

class _MessageHub implements MessageHub {
  final Channel _channel;
  _MessageHub(Channel channel) : _channel = channel;

  @override
  StreamSubscription listen<RQ, RS>(
    String topic,
    RequestHandler<RQ, RS> requestHandler, {
    Converter<dynamic, RQ> requestDecoder,
    Converter<RS, dynamic> replyEncoder,
  }) {
    return _channel.getRequests(topic).listen((Packet p) {
      RQ request = requestDecoder != null ? requestDecoder(p.data) : p.data;
      StreamController<RS> controller = new StreamController(sync: true);
      controller.stream.listen((RS reply) {
        var data = replyEncoder != null ? replyEncoder(reply) : reply;
        _channel.send(new Packet(topic, inReplyTo: p.requestId, data: data));
      }, onError: (e) {
        _channel.send(
            new Packet(topic, inReplyTo: p.requestId, error: e.toString()));
      }, onDone: () {
        _channel.send(new Packet(topic, inReplyTo: p.requestId, isClose: true));
      });
      Future f = requestHandler(request, controller) ?? new Future.value();
      f.then((_) => null, onError: (e) {
        _channel.send(new Packet(topic,
            inReplyTo: p.requestId, error: e.toString(), isClose: true));
      }).whenComplete(() {
        if (!controller.isClosed) {
          controller.close();
        }
      });
    });
  }

  @override
  UnaryHubFn<RQ, RS> bindUnaryCaller<RQ, RS>(
    String topic, {
    Converter<RQ, dynamic> requestEncoder,
    Converter<dynamic, RS> replyDecoder,
  }) {
    StreamHubFn<RQ, RS> fn = bindStreamCaller(topic,
        requestEncoder: requestEncoder, replyDecoder: replyDecoder);
    return (request) => fn(request).first;
  }

  @override
  StreamHubFn<RQ, RS> bindStreamCaller<RQ, RS>(
    String topic, {
    Converter<RQ, dynamic> requestEncoder,
    Converter<dynamic, RS> replyDecoder,
  }) {
    return (RQ request) {
      String requestId = _newRequestId();
      var data = requestEncoder != null ? requestEncoder(request) : request;
      Stream<RS> stream = _channel
          .getReplies(topic, requestId)
          .transform(new StreamTransformer.fromHandlers(
        handleData: (Packet p, EventSink<RS> sink) {
          if (p.error != null) {
            sink.addError(p.error);
          }
          if (p.isClose == true) {
            sink.close();
          }
          if (p.error == null && p.isClose != true) {
            RS reply = replyDecoder != null ? replyDecoder(p.data) : p.data;
            sink.add(reply);
          }
        },
      ));
      _channel.send(new Packet(topic, requestId: requestId, data: data));
      return stream;
    };
  }

  @override
  Sink<T> getSink<T>(String topic, {Converter<T, dynamic> encoder}) {
    final StreamController<T> controller = new StreamController<T>(sync: true);
    controller.stream.listen((T data) {
      var encodedData = (encoder != null) ? encoder(data) : data;
      _channel.send(new Packet(topic, data: encodedData));
    });
    return controller;
  }

  @override
  Stream<T> getStream<T>(String topic, {Converter<dynamic, T> decoder}) {
    return _channel.getTopic(topic).transform(
        new StreamTransformer.fromHandlers(
            handleData: (Packet p, EventSink<T> sink) {
      T decodedData;
      if (decoder != null) {
        decodedData = decoder(p.data);
      } else {
        decodedData = p.data;
      }
      sink.add(decodedData);
    }));
  }
}

int _requestCounter = 0;
String _newRequestId() => 'id${_requestCounter++}';
