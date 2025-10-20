class User {
  final String username;
  final String cpf;
  final String email;
  final String telefone;
  final String password;
  final String? tipo; // paciente, medico, secretaria, adm (opcional no cadastro inicial)

  User({
    required this.username,
    required this.cpf,
    required this.email,
    required this.telefone,
    required this.password,
    this.tipo,
  });

  Map<String, dynamic> toJson() {
    return {
      "username": username,
      "cpf": cpf,
      "email": email,
      "telefone": telefone,
      "password": password,
      "tipo": tipo ?? "Paciente", // por padrão, no app mobile será paciente
    };
  }
}