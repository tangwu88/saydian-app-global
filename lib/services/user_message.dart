/// Keep diagnostic payloads out of UI; preserve concise, actionable errors.
String userFacingMessage(String? value, {required String fallback}) {
  final message = value?.trim() ?? '';
  if (message.isEmpty || message.length > 180) return fallback;
  final chinese = RegExp(r'[\u3400-\u9fff]');
  final chineseFallback = chinese.hasMatch(fallback);
  final lower = message.toLowerCase();
  if (RegExp(r'network|socket|timeout|timed out').hasMatch(lower) ||
      message.contains('网络')) {
    return chineseFallback
        ? '网络不可用，请检查后重试'
        : 'Network unavailable. Check your connection and try again.';
  }
  if (!chineseFallback && chinese.hasMatch(message)) return fallback;
  if (RegExp(
    r'sdk|api|http|token|appid|universal.?link|exception|stack.?trace|<[^>]+>|'
    r'接口|服务端|后端|后台返回|后台未返回|桥接|未配置|配置异常|未实现|未接入|调试|原生|回调|服务器返回|响应格式',
    caseSensitive: false,
  ).hasMatch(message)) {
    return fallback;
  }
  return message;
}
