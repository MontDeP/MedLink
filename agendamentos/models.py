from django.db import models
from django.utils.translation import gettext_lazy as _
from users.models import User
from pacientes.models import Paciente
from clinicas.models import Clinica # Importa o modelo Clinica
from .consts import (
    STATUS_CONSULTA_CHOICES, STATUS_CONSULTA_PENDENTE,
    STATUS_PAGAMENTO_CHOICES, STATUS_PAGAMENTO_PENDENTE,
)

class Consulta(models.Model):
    """
    Representa a tabela `Consultas` no banco de dados.
    Armazena os detalhes de um agendamento e seus relacionamentos.
    """
    data_hora = models.DateTimeField(
        verbose_name=_('Data e Hora da Consulta')
    )
    status_atual = models.CharField(
        max_length=50,
        choices=STATUS_CONSULTA_CHOICES,
        default=STATUS_CONSULTA_PENDENTE,
        verbose_name=_('Status Atual')
    )
    valor = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        verbose_name=_('Valor da Consulta')
    )
    
    # Relações de Chave Estrangeira com outros modelos:
    # 1. Com o Paciente
    paciente = models.ForeignKey(
        Paciente,
        on_delete=models.CASCADE,
        related_name='consultas_agendadas',
        verbose_name=_('Paciente')
    )
    
    # 2. Com o Médico. A documentação prevê o modelo `Medicos` como uma entidade fraca.
    # Por enquanto, usamos `User` com um filtro para o tipo de usuário `MEDICO`.
    medico = models.ForeignKey(
        User,
        on_delete=models.RESTRICT,
        limit_choices_to={'user_type': 'MEDICO'},
        related_name='consultas_realizadas',
        verbose_name=_('Médico')
    )
    
    # 3. Com a Clínica. Agora referenciando o novo modelo `Clinica`.
    clinica = models.ForeignKey(
        Clinica, # Referência corrigida para o modelo Clinica
        on_delete=models.RESTRICT,
        related_name='consultas_sediadas',
        verbose_name=_('Clínica')
    )

    data_criacao = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_('Data de Criação')
    )
    data_atualizacao = models.DateTimeField(
        auto_now=True,
        verbose_name=_('Data de Atualização')
    )
    
    class Meta:
        verbose_name = _("Consulta")
        verbose_name_plural = _("Consultas")
        ordering = ['data_hora']
        
    def __str__(self):
        return f"Consulta de {self.paciente.nome_completo} em {self.data_hora}"


class Pagamento(models.Model):
    """
    Representa a tabela `Pagamentos` no banco de dados.
    Mantida separada da Consulta para clareza e escalabilidade,
    conforme as melhores práticas [cite: Medlink-bd-main/README.md].
    """
    consulta = models.OneToOneField(
        Consulta,
        on_delete=models.CASCADE,
        primary_key=True,
        verbose_name=_('Consulta')
    )
    
    valor_pago = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True, blank=True,
        verbose_name=_('Valor Pago')
    )
    status = models.CharField(
        max_length=50,
        choices=STATUS_PAGAMENTO_CHOICES,
        default=STATUS_PAGAMENTO_PENDENTE,
        verbose_name=_('Status do Pagamento')
    )
    data_pagamento = models.DateTimeField(
        null=True, blank=True,
        verbose_name=_('Data do Pagamento')
    )
    
    data_criacao = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_('Data de Criação')
    )
    data_atualizacao = models.DateTimeField(
        auto_now=True,
        verbose_name=_('Data de Atualização')
    )

    class Meta:
        verbose_name = _("Pagamento")
        verbose_name_plural = _("Pagamentos")

    def __str__(self):
        return f"Pagamento da Consulta {self.consulta.id} - {self.status}"


class ConsultaStatusLog(models.Model):
    """
    Representa a tabela de auditoria `ConsultaStatusLog` no banco de dados.
    É usada para rastrear as mudanças de status da consulta [cite: Medlink-bd-main/README.md].
    """
    status_novo = models.CharField(
        max_length=50,
        verbose_name=_('Novo Status')
    )
    data_modificacao = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_('Data da Modificação')
    )
    
    consulta = models.ForeignKey(
        Consulta,
        on_delete=models.CASCADE,
        related_name='historico_status',
        verbose_name=_('Consulta')
    )
    
    pessoa = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        verbose_name=_('Modificado por')
    )

    class Meta:
        verbose_name = _("Log de Status da Consulta")
        verbose_name_plural = _("Logs de Status da Consulta")

    def __str__(self):
        return f"Status da Consulta {self.consulta.id} alterado para {self.status_novo}"
    
# --- ADICIONE ESTA NOVA CLASSE AO FINAL DO FICHEIRO ---
class AnotacaoConsulta(models.Model):
    """
    Armazena as anotações feitas por um médico para uma consulta específica.
    A relação OneToOneField garante que cada consulta tenha apenas uma anotação.
    """
    consulta = models.OneToOneField(
        Consulta,
        on_delete=models.CASCADE,
        primary_key=True, # A própria consulta é a chave
        related_name='anotacao'
    )
    conteudo = models.TextField(
        verbose_name=_("Conteúdo da Anotação")
    )
    data_criacao = models.DateTimeField(auto_now_add=True)
    data_atualizacao = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _("Anotação de Consulta")
        verbose_name_plural = _("Anotações de Consulta")

    def __str__(self):
        return f"Anotação para a Consulta ID {self.consulta.id}"