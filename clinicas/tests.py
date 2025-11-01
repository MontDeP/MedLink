from django.test import TestCase
from .models import Estado, Cidade, TipoClinica, Clinica

class EstadoModelTest(TestCase):
    """Testes para o modelo Estado."""
    def test_estado_creation(self):
        """Testa se um objeto Estado pode ser criado com sucesso."""
        estado = Estado.objects.create(nome='São Paulo', uf='SP')
        self.assertEqual(estado.nome, 'São Paulo')
        self.assertEqual(estado.uf, 'SP')
        self.assertEqual(str(estado), 'SP')

class CidadeModelTest(TestCase):
    """Testes para o modelo Cidade."""
    def setUp(self):
        """Cria um objeto Estado para ser usado nos testes de Cidade."""
        self.estado = Estado.objects.create(nome='São Paulo', uf='SP')

    def test_cidade_creation(self):
        """Testa se um objeto Cidade pode ser criado e associado a um Estado."""
        cidade = Cidade.objects.create(nome='São Paulo', estado=self.estado)
        self.assertEqual(cidade.nome, 'São Paulo')
        self.assertEqual(cidade.estado, self.estado)
        self.assertEqual(str(cidade), 'São Paulo - SP')

class TipoClinicaModelTest(TestCase):
    """Testes para o modelo TipoClinica."""
    def test_tipo_clinica_creation(self):
        """Testa se um objeto TipoClinica pode ser criado com sucesso."""
        tipo_clinica = TipoClinica.objects.create(descricao='Cardiologia')
        self.assertEqual(tipo_clinica.descricao, 'Cardiologia')
        self.assertEqual(str(tipo_clinica), 'Cardiologia')

class ClinicaModelTest(TestCase):
    """Testes para o modelo Clinica."""
    def setUp(self):
        """Cria objetos Estado, Cidade e TipoClinica para serem usados nos testes de Clinica."""
        self.estado = Estado.objects.create(nome='São Paulo', uf='SP')
        self.cidade = Cidade.objects.create(nome='São Paulo', estado=self.estado)
        self.tipo_clinica = TipoClinica.objects.create(descricao='Cardiologia')

    def test_clinica_creation(self):
        """Testa se um objeto Clinica pode ser criado com seus campos obrigatórios."""
        clinica = Clinica.objects.create(
            nome_fantasia='Clínica Coração',
            cnpj='12345678901234',
            cidade=self.cidade,
            tipo_clinica=self.tipo_clinica
        )
        self.assertEqual(clinica.nome_fantasia, 'Clínica Coração')
        self.assertEqual(clinica.cnpj, '12345678901234')
        self.assertEqual(clinica.cidade, self.cidade)
        self.assertEqual(clinica.tipo_clinica, self.tipo_clinica)
        self.assertEqual(str(clinica), 'Clínica Coração')

    def test_clinica_optional_fields(self):
        """Testa se os campos opcionais da Clinica são nulos por padrão."""
        clinica = Clinica.objects.create(
            nome_fantasia='Clínica Coração',
            cnpj='12345678901234',
            cidade=self.cidade,
            tipo_clinica=self.tipo_clinica
        )
        self.assertEqual(clinica.logradouro, None)
