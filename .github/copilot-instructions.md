# MedLink Project Guidelines

## Architecture Overview

MedLink is a full-stack medical appointment management system with:
- Backend: Django REST API with multiple Django apps for domain separation
- Frontend: Flutter application for cross-platform support
- Authentication: JWT-based with role-specific tokens

### Key Components

1. Backend Structure (Django):
```
medlink_core/      # Main Django project settings
├── settings.py    # Core configuration
└── urls.py        # Main URL routing
```

Domain-specific apps:
- `users/` - User authentication and role management
- `clinicas/` - Clinic management
- `agendamentos/` - Appointment scheduling
- `medicos/` - Doctor profiles and availability
- `secretarias/` - Secretary dashboard and operations
- `pacientes/` - Patient records

2. Frontend Structure (Flutter):
```
medlink/lib/
├── services/      # API communication
├── models/        # Data models
└── views/
    └── pages/     # Screen implementations
```

## Key Patterns

### Authentication Flow
- JWT tokens stored in `flutter_secure_storage`
- Token includes role-specific data (e.g., `clinica_id` for secretaries)
- Example in `users/serializers.py`: `MyTokenObtainPairSerializer`

### API Integration
- Base URL pattern: `http://127.0.0.1:8000/api/`
- Endpoints follow RESTful conventions:
  - GET/POST: `/api/agendamentos/`
  - PUT: `/api/agendamentos/{id}/`
  - PATCH: `/api/secretarias/consultas/{id}/confirmar/`

### Security Patterns
- Role-based access control via Django permissions
- Clinic-scoped data access (secretaries see only their clinic's data)
- Token enrichment with necessary role data

## Development Workflows

### Backend Setup
```bash
python -m venv .venv
source .venv/Scripts/activate  # Windows/Git Bash
pip install -r requirements.txt
python manage.py migrate
```

### Frontend Setup
```bash
cd medlink
flutter pub get
```

### Common Issues
1. Database Migrations:
   - Always check for unapplied migrations: `python manage.py showmigrations`
   - If duplicate columns occur, may need `--fake` migrations

2. Authentication:
   - JWT tokens must include role-specific data (check `MyTokenObtainPairSerializer`)
   - Frontend must extract clinic_id from token for proper scoping

## Testing

- Backend: Django test cases in `*/tests.py`
- Frontend: Flutter tests in `medlink/test/`

## Project-Specific Conventions

1. API Response Format:
   - Success: HTTP 200/201 with data
   - Errors: HTTP 4xx with `{"error": "message"}`

2. Role Types:
   - ADMIN
   - SECRETARY
   - DOCTOR
   - PATIENT

3. Appointment Status:
   - PENDENTE
   - CONFIRMADA
   - CANCELADA