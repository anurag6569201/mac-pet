from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import json
from .voice_manager import VoiceManager

def status_view(request):
    return JsonResponse({
        "status": "ok",
        "message": "Pet Backend is running",
        "version": "1.0.0"
    })

@csrf_exempt
@require_http_methods(["POST"])
def start_voice(request):
    manager = VoiceManager()
    success, message = manager.start_listening()
    return JsonResponse({"success": success, "message": message})

@csrf_exempt
@require_http_methods(["POST"])
def stop_voice(request):
    manager = VoiceManager()
    success, message = manager.stop_listening()
    return JsonResponse({"success": success, "message": message})

@require_http_methods(["GET"])
def voice_status(request):
    manager = VoiceManager()
    result = manager.get_status()
    return JsonResponse(result)

