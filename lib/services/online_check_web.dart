import 'dart:html' as html;

Future<bool> checkOnline() async {
  return html.window.navigator.onLine ?? true;
}
