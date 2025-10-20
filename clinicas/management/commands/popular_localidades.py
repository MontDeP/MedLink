import requests
from django.core.management.base import BaseCommand
from clinicas.models import Estado, Cidade, Clinica
from agendamentos.models import Consulta # <<<---- IMPORTE O MODELO CONSULTA

class Command(BaseCommand):
    help = 'Popula o banco de dados com os estados e cidades do Brasil utilizando a API do IBGE.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.HTTP_INFO('Iniciando o processo de popular estados e cidades...'))

        # Limpando dados existentes para evitar duplicatas
        if Cidade.objects.exists() or Estado.objects.exists() or Clinica.objects.exists() or Consulta.objects.exists():
            self.stdout.write(self.style.WARNING('Limpando tabelas de Consulta, Clinica, Cidade e Estado existentes...'))
            
            # A ORDEM IMPORTA:
            Consulta.objects.all().delete() # 1. Apaga as consultas
            Clinica.objects.all().delete()  # 2. Apaga as clínicas
            Cidade.objects.all().delete()   # 3. Apaga as cidades
            Estado.objects.all().delete()   # 4. Apaga os estados

        # URL da API de estados do IBGE
        url_estados = 'https://servicodados.ibge.gov.br/api/v1/localidades/estados?orderBy=nome'
        
        try:
            # (O restante do código permanece exatamente o mesmo)
            response_estados = requests.get(url_estados)
            response_estados.raise_for_status()
            estados = response_estados.json()

            self.stdout.write(f'Encontrados {len(estados)} estados. Cadastrando...')

            for estado_data in estados:
                estado_obj, created = Estado.objects.get_or_create(
                    uf=estado_data['sigla'],
                    defaults={'nome': estado_data['nome']}
                )
                
                if created:
                    self.stdout.write(self.style.SUCCESS(f'Estado "{estado_obj.nome}" cadastrado.'))
                
                url_cidades = f'https://servicodados.ibge.gov.br/api/v1/localidades/estados/{estado_obj.uf}/municipios'
                response_cidades = requests.get(url_cidades)
                response_cidades.raise_for_status()
                cidades = response_cidades.json()

                cidades_para_criar = []
                for cidade_data in cidades:
                    cidades_para_criar.append(
                        Cidade(nome=cidade_data['nome'], estado=estado_obj)
                    )
                
                Cidade.objects.bulk_create(cidades_para_criar)
                self.stdout.write(f'  -> {len(cidades)} cidades cadastradas para {estado_obj.uf}.')

        except requests.RequestException as e:
            self.stdout.write(self.style.ERROR(f'Erro ao acessar a API do IBGE: {e}'))
            return

        self.stdout.write(self.style.SUCCESS('Processo finalizado com sucesso!'))