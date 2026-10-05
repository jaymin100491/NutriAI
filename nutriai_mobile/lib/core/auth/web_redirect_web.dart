import 'dart:html' as html;

Future<void> redirectToUrl(String url) async {
  html.window.location.href = url;
}

String? getCurrentPath() => html.window.location.pathname;

String? getQueryParameter(String name) {
  final params = Uri.parse(html.window.location.href).queryParameters;
  return params[name];
}
