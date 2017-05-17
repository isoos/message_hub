import 'dart:async';

import 'package:message_hub/message_hub.dart';
import 'package:message_hub/native/inproc.dart';

Future main() async {
  MessageHub hub = new MessageHub(new InprocChannel());

  StreamSubscription serviceSubscription =
      hub.listen('echo', (String name, Sink<String> replySink) async {
    replySink.add('Hello $name!');
    replySink.close();
  });

  UnaryHubFn<String, String> echoFn = hub.bindUnaryCaller('echo');

  print(await echoFn('world'));

  await serviceSubscription.cancel();
}
