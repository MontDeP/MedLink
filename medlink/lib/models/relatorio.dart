class Relatorio {
  final String titulo;
  final String conteudo;

  Relatorio({
    required this.titulo,
    required this.conteudo,
  });

  factory Relatorio.fromJson(Map<String, dynamic> json) {
    return Relatorio(
      titulo: json['titulo'],
      conteudo: json['conteudo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'conteudo': conteudo,
    };
  }
}