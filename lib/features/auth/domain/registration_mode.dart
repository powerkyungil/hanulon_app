enum RegistrationMode {
  joinGuild('JOIN_GUILD', '기존 길드 가입'),
  createGuild('CREATE_GUILD', '새 길드 생성');

  const RegistrationMode(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
