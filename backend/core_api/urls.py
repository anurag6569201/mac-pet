from django.urls import path
from .views import status_view, start_voice, stop_voice, voice_status

urlpatterns = [
    path('status/', status_view, name='status'),
    path('voice/start/', start_voice, name='voice_start'),
    path('voice/stop/', stop_voice, name='voice_stop'),
    path('voice/status/', voice_status, name='voice_status'),
]
