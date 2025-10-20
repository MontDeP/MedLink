# MedLink (v1.0.0)

[![Versão](https://img.shields.io/badge/version-v1.0.0-blue)](https://github.com/seu-usuario/medlink/releases/tag/v1.0.0)
[![Python](https://img.shields.io/badge/Python-3.12-blue?logo=python&logoColor=white)](https://www.python.org/) [![Django](https://img.shields.io/badge/Django-5.2-green?logo=django&logoColor=white)](https://www.djangoproject.com/) [![Flutter](https://img.shields.io/badge/Flutter-blue?logo=flutter&logoColor=white)](https://flutter.dev/) [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-darkblue?logo=postgresql&logoColor=white)](https://www.postgresql.org/) **MedLink** é um sistema multiplataforma (Web, Desktop) para gestão de agendamentos e informações de clínicas médicas, desenvolvido em Django (backend) e Flutter (frontend). Facilita a organização de médicos, secretárias e administradores, além de oferecer funcionalidades básicas para pacientes.

## Funcionalidades Implementadas (v1.0.0)

Esta versão inclui as seguintes funcionalidades principais:

* **Autenticação:**
    * Login via CPF/Senha para todos os tipos de utilizador (Admin, Médico, Secretária, Paciente).
    * Recuperação de senha por e-mail.
    * Criação inicial de senha via link por e-mail (para utilizadores criados pelo admin).
* **Módulo Administrativo (Web/Desktop App):**
    * Dashboard com estatísticas de utilizadores.
    * Gestão completa de Utilizadores (CRUD) com diferentes perfis (Médico, Secretária, Paciente, Admin).
    * Visualização de Logs de Auditoria (Backend).
    * Configurações do Sistema (Backend).
* **Módulo da Secretária (Web/Desktop App):**
    * Dashboard com estatísticas de consultas (hoje, confirmadas, pendentes, mês).
    * Visualização e pesquisa da agenda do dia.
    * Agendamento de novas consultas (com validação de conflito no backend).
    * Confirmação, cancelamento e remarcação de consultas.
    * Cadastro rápido de novos pacientes.
* **Módulo do Médico (Web/Desktop App):**
    * Dashboard com lista de pacientes do dia e detalhes da consulta atual.
    * Visualização de informações do paciente selecionado.
    * Registo e gravação de anotações para a consulta atual.
    * Visualização do histórico de consultas e anotações anteriores do paciente selecionado.
    * Funcionalidade para finalizar consulta (atualiza status e anotação).
    * Visualização da agenda completa em formato de calendário.
* **Módulo do Paciente (Web/Desktop App):**
    * Cadastro inicial.
    * Login e página de confirmação básica. *(Funcionalidades de histórico e agendamento pelo paciente ainda não implementadas no frontend)*.
* **Gestão de Clínicas (Backend):** Modelos e API para CRUD de Clínicas, Cidades, Estados e Tipos de Clínica.

## Tecnologias Utilizadas

* **Backend:** Python 3.12, Django 5.2, Django REST Framework, Simple JWT, PostgreSQL
* **Frontend:** Flutter 3.x, Dart
* **Gestão de Estado (Flutter):** Provider, GetX
* **Packages Flutter Notáveis:** http, flutter_secure_storage, jwt_decoder, table_calendar, intl, mask_text_input_formatter
* **Plataformas Suportadas (Frontend):** Web, Windows, macOS, Linux, iOS, Android (estrutura Flutter preparada)
* **Hospedagem (Exemplo):** Render.com (configurado para PostgreSQL e deploy via `build.sh`)

## Estrutura do Projeto

* `/` (Raiz): Contém os apps Django (backend), `manage.py`, `requirements.txt`, etc.
* `/medlink`: Contém o projeto Flutter (frontend).

## Configuração do Ambiente de Desenvolvimento

Siga os passos abaixo para executar o projeto localmente.

### Pré-requisitos

* Python 3.12+
* Pip (para gerir dependências Python)
* PostgreSQL (instalado e rodando localmente, ou via Docker)
* Flutter SDK (versão 3.x ou superior)
* Um editor de código (ex: VS Code com extensões Dart & Flutter)

### Backend (Django)

1.  **Clone o repositório:**
    ```bash
    git clone [https://github.com/seu-usuario/MedLink.git](https://github.com/seu-usuario/MedLink.git)
    cd MedLink
    ```

2.  **Crie e ative o ambiente virtual:**
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate  # Linux/macOS
    # .\.venv\Scripts\activate # Windows
    ```

3.  **Instale as dependências Python:**
    ```bash
    pip install -r requirements.txt
    ```

4.  **Configure as variáveis de ambiente:**
    Crie um ficheiro `.env` na raiz do projeto (`/MedLink/.env`). **Certifique-se que o seu banco de dados PostgreSQL local está a correr e que existe uma base de dados chamada `medlink_db` (ou o nome que definir abaixo).**

    ```ini
    # Exemplo de .env para banco de dados local
    DEBUG=True
    SECRET_KEY=sua-secret-key-de-desenvolvimento-aqui # Gere uma chave segura

    # --- Configuração do Banco de Dados Local ---
    DATABASE_URL=postgres://SEU_USER:SUA_SENHA@localhost:5432/medlink_db

    # --- Configuração de E-mail (Exemplo Gmail - Crie uma Senha de App) ---
    EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
    EMAIL_HOST=smtp.gmail.com
    EMAIL_PORT=587
    EMAIL_USE_TLS=True
    EMAIL_HOST_USER=seu-email@gmail.com
    EMAIL_HOST_PASSWORD=sua-senha-de-app-do-gmail
    DEFAULT_FROM_EMAIL=seu-email@gmail.com
    ```
    *Nota: Para o Gmail, precisará gerar uma "App Password" se tiver 2FA ativo.*

5.  **Aplique as migrações do banco de dados:**
    ```bash
    python manage.py migrate
    ```

6.  **(Opcional) Popule Estados e Cidades (necessário para cadastro de clínicas):**
    ```bash
    python manage.py popular_localidades
    ```

7.  **Crie um superusuário (Admin Django):**
    ```bash
    python manage.py createsuperuser
    ```

8.  **Execute o servidor de desenvolvimento Django:**
    ```bash
    python manage.py runserver
    ```
    O backend estará acessível em `http://127.0.0.1:8000/`.

### Frontend (Flutter)

1.  **Navegue até o diretório do Flutter:**
    ```bash
    cd medlink
    ```

2.  **Instale as dependências Flutter:**
    ```bash
    flutter pub get
    ```

3.  **Configure a URL da API:**
    * Abra o ficheiro `medlink/lib/services/api_service.dart`.
    * Verifique se a `baseUrl` está correta para o seu ambiente. O código atual já deteta se está a correr na Web (`127.0.0.1:8000`) ou em emulador Android (`10.0.2.2:8000`). Ajuste se necessário.

4.  **Execute a aplicação Flutter:**
    * Selecione o dispositivo desejado (Chrome para Web, Emulador Android/iOS, Desktop).
    * Execute a partir do seu editor ou via terminal:
        ```bash
        flutter run
        ```

## Considerações Importantes

* **Banco de Dados:** **NÃO** use o banco de dados do Render.com para desenvolvimento local. Configure e use sempre uma instância do PostgreSQL na sua máquina local para evitar problemas de conectividade (`Connection timed out`) e risco de afetar dados de produção/staging.
* **Variáveis de Ambiente:** Nunca comite o ficheiro `.env` para o Git. Use-o apenas localmente. Para produção (Render.com), configure as variáveis de ambiente diretamente na plataforma.
* **Flutter Web:** Para executar na Web, use `flutter run -d chrome`.