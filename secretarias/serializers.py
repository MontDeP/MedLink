from rest_framework import serializers
from agendamentos.models import Consulta

class DashboardStatsSerializer(serializers.Serializer):
    """
    Serializer para as estatísticas dos cards do dashboard.
    """
    today = serializers.IntegerField()
    confirmed = serializers.IntegerField()
    pending = serializers.IntegerField()
    totalMonth = serializers.IntegerField()


class ConsultaHojeSerializer(serializers.ModelSerializer):
    """
    Serializer para a lista de "Consultas de Hoje", agora com os caminhos corretos.
    """
    # Renomeia e formata os campos para o frontend
    time = serializers.SerializerMethodField()
    
    # 👇 CORREÇÃO APLICADA AQUI 👇
    # Usa o caminho correto para buscar o nome do paciente e do médico
    patient = serializers.CharField(source='paciente.nome_completo', read_only=True)
    doctor = serializers.CharField(source='medico.get_full_name', read_only=True)
    
    type = serializers.CharField(source='get_status_atual_display', read_only=True)
    status = serializers.SerializerMethodField()

    class Meta:
        model = Consulta
        # Lista de campos que o JSON final terá
        fields = ['id', 'time', 'patient', 'doctor', 'type', 'status']

    def get_time(self, obj):
        # Função para formatar a hora corretamente
        if obj.data_hora:
            return obj.data_hora.strftime('%H:%M')
        return None

    def get_status(self, obj):
        # Sua lógica de tradução de status, que já está correta
        if obj.status_atual == 'AGENDADA':
            return 'pending'
        elif obj.status_atual == 'CONFIRMADA':
            return 'confirmed'
        elif obj.status_atual == 'CANCELADA':
            return 'cancelled'
        return obj.status_atual.lower()