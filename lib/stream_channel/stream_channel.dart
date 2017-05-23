import 'dart:async';
import 'package:stream_channel/stream_channel.dart';

import '../message_hub.dart';

class StreamChannelAdapter extends DuplexChannel {
  final StreamChannel<Packet> packetChannel;
  StreamChannelAdapter(this.packetChannel);

  @override
  Stream<Packet> get onPacket => packetChannel.stream;

  @override
  Future send(Packet packet) {
    packetChannel.sink.add(packet);
  }
}
