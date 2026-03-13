// Stub pour protocol_handler sur web (pas de schéma offibox://).
import 'package:flutter/material.dart';

mixin ProtocolListener on State<StatefulWidget> {
  void onProtocolUrlReceived(String url) {}
}

final protocolHandler = _ProtocolHandlerStub();

class _ProtocolHandlerStub {
  void addListener(dynamic listener) {}
  void removeListener(dynamic listener) {}
}
