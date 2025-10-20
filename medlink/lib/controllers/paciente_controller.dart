// lib/controllers/paciente_controller.dart (VERSÃO ATUALIZADA)

import 'package:flutter/material.dart';
import '../models/paciente.dart';
import '../models/consultas.dart' as consultas_model; // Importa o modelo de consulta
import '../services/api_service.dart';

class PacienteController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Estados para a lista de pacientes do dia
  List<Paciente> pacientes = [];
  int _selectedIndex = -1; 
  bool isLoading = true;
  String? errorMessage;

  // --- NOVOS ESTADOS PARA A ANOTAÇÃO ---
  String anotacaoAtual = "";
  bool isAnotacaoLoading = false;
  bool isSaving = false; // Para o botão de salvar

  // --- NOVOS ESTADOS PARA O HISTÓRICO ---
  List<consultas_model.Consulta> historicoConsultas = [];
  bool isHistoricoLoading = false;
  String? historicoErrorMessage;

  int get selectedIndex => _selectedIndex;
  Paciente? get pacienteSelecionado {
    if (_selectedIndex >= 0 && _selectedIndex < pacientes.length) {
      return pacientes[_selectedIndex];
    }
    return null;
  }

  PacienteController() {
    fetchPacientesDoDia();
  }

  Future<void> fetchPacientesDoDia() async {
    // ... (este método continua igual)
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      pacientes = await _apiService.getPacientesDoDia();
      if (pacientes.isNotEmpty) {
        // Ao carregar a lista, já busca o histórico do primeiro paciente
        selecionarPaciente(0); 
      } else {
        _selectedIndex = -1;
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 👇 ADICIONE ESTE NOVO MÉTODO 👇
  Future<bool> finalizarConsulta(String conteudo) async {
    if (pacienteSelecionado == null) return false;

    isSaving = true; // Reutiliza o estado de 'salvando'
    notifyListeners();

    try {
      // Usa o ID correto da consulta que adicionamos ao modelo
      final consultaId = pacienteSelecionado!.consultaId;
      await _apiService.finalizarConsulta(consultaId, conteudo);

      // Limpa a anotação atual para o próximo paciente
      anotacaoAtual = "";

      // Remove o paciente da lista da esquerda, pois a consulta foi concluída
      pacientes.removeWhere((p) => p.id == pacienteSelecionado!.id);
      
      // Se ainda houver pacientes, seleciona o próximo. Senão, limpa a seleção.
      if (pacientes.isNotEmpty) {
        // Seleciona o primeiro da lista restante para não deixar a tela vazia
        selecionarPaciente(0);
      } else {
        _selectedIndex = -1;
      }

      return true;
    } catch (e) {
      print("Erro ao finalizar consulta: $e");
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

   // O MÉTODO selecionarPaciente VOLTA AO NORMAL (REMOVA A LIMPEZA DAQUI)
  void selecionarPaciente(int index) {
    if (index >= 0 && index < pacientes.length) {
      _selectedIndex = index;
      final paciente = pacientes[index];

      // Apenas chama os métodos de busca
      _fetchHistorico(paciente.id);
      
      final consultaDeHojeId = paciente.consultaId;
      _fetchAnotacao(consultaDeHojeId); 
      
      notifyListeners();
    }
  }

  // --- CORREÇÃO APLICADA DIRETAMENTE AQUI ---
  // ATUALIZE O MÉTODO _fetchAnotacao PARA ESTA VERSÃO:
  Future<void> _fetchAnotacao(int consultaId) async {
    // 1. Limpa imediatamente o estado da anotação anterior e avisa a UI.
    // Isso garante que o campo de texto fique em branco enquanto os novos dados são carregados.
    anotacaoAtual = "";
    isAnotacaoLoading = true;
    notifyListeners();

    try {
      // 2. Busca a anotação para a nova consulta.
      // O ApiService já retorna uma string vazia ("") caso a API retorne 404 (não encontrado).
      final fetchedAnnotation = await _apiService.getAnotacao(consultaId) ?? "";
      
      // 3. Atualiza o estado com o conteúdo encontrado.
      // Se por acaso uma anotação para a consulta de hoje já existir, o campo será preenchido.
      // Caso contrário, ele permanecerá vazio, que é o comportamento esperado.
      anotacaoAtual = fetchedAnnotation;

    } catch(e) {
      print("Erro ao buscar anotação: $e");
      // Mantém o campo vazio em caso de qualquer erro.
      anotacaoAtual = "";
    } finally {
      isAnotacaoLoading = false;
      
      // 4. Notifica a UI pela última vez com o estado final (ou com a anotação do dia, ou vazio).
      notifyListeners();
    }
  }

  // --- NOVO MÉTODO PARA SALVAR A ANOTAÇÃO ---
  Future<bool> salvarAnotacao(String conteudo) async {
    if (pacienteSelecionado == null) return false;

    isSaving = true;
    notifyListeners();

    try {
      final consultaId = pacienteSelecionado!.id; // Supondo que o ID coincida
      await _apiService.salvarAnotacao(consultaId, conteudo);
      anotacaoAtual = conteudo; // Atualiza o estado local
      
      // Força a atualização do histórico para refletir a nova anotação
      _fetchHistorico(pacienteSelecionado!.id);
      
      return true;
    } catch (e) {
      print("Erro ao salvar anotação: $e");
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // --- NOVO MÉTODO PRIVADO PARA BUSCAR O HISTÓRICO ---
  Future<void> _fetchHistorico(int pacienteId) async {
    isHistoricoLoading = true;
    historicoErrorMessage = null;
    notifyListeners();

    try {
      historicoConsultas = await _apiService.getHistoricoConsultas(pacienteId);
    } catch (e) {
      historicoErrorMessage = e.toString();
      print("Erro ao buscar histórico: $e");
    } finally {
      isHistoricoLoading = false;
      notifyListeners();
    }
  }
}