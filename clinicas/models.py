from django.db import models
from django.utils.translation import gettext_lazy as _
from users.models import User

class Estado(models.Model):
    """
    Tabela de referência para os estados brasileiros.
    """
    nome = models.CharField(max_length=50, unique=True)
    uf = models.CharField(max_length=2, unique=True, verbose_name=_("UF"))

    class Meta:
        verbose_name = _("Estado")
        verbose_name_plural = _("Estados")

    def __str__(self):
        return self.uf

class Cidade(models.Model):
    """
    Tabela de referência para as cidades, vinculadas a um estado.
    """
    nome = models.CharField(max_length=100)
    estado = models.ForeignKey(Estado, on_delete=models.RESTRICT, verbose_name=_("Estado"))

    class Meta:
        verbose_name = _("Cidade")
        verbose_name_plural = _("Cidades")
        unique_together = ('nome', 'estado') # Garante que não haja cidades com o mesmo nome no mesmo estado

    def __str__(self):
        return f"{self.nome} - {self.estado.uf}"

class TipoClinica(models.Model):
    """
    Tabela de referência para os tipos de clínica.
    """
    descricao = models.CharField(max_length=100, unique=True, verbose_name=_("Descrição"))

    class Meta:
        verbose_name = _("Tipo de Clínica")
        verbose_name_plural = _("Tipos de Clínica")

    def __str__(self):
        return self.descricao

class Clinica(models.Model):
    """
    Armazena os dados cadastrais de cada clínica.
    """
    nome_fantasia = models.CharField(max_length=255, verbose_name=_("Nome Fantasia"))
    cnpj = models.CharField(max_length=14, unique=True, verbose_name=_("CNPJ"))
    logradouro = models.CharField(max_length=255, null=True, blank=True)
    numero = models.CharField(max_length=20, null=True, blank=True, verbose_name=_("Número"))
    bairro = models.CharField(max_length=100, null=True, blank=True)
    cep = models.CharField(max_length=8, null=True, blank=True)
    telefone = models.CharField(max_length=20, null=True, blank=True)
    
    cidade = models.ForeignKey(Cidade, on_delete=models.RESTRICT, verbose_name=_("Cidade"))
    tipo_clinica = models.ForeignKey(TipoClinica, on_delete=models.RESTRICT, verbose_name=_("Tipo de Clínica"))
    
    # Relação com o usuário responsável
    responsavel = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='clinicas_responsavel',
        verbose_name=_("Responsável")
    )
    
    data_criacao = models.DateTimeField(auto_now_add=True)
    data_atualizacao = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _("Clínica")
        verbose_name_plural = _("Clínicas")

    def __str__(self):
        return self.nome_fantasia
