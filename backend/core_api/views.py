from django.http import JsonResponse

def status_view(request):
    return JsonResponse({
        "status": "ok",
        "message": "Pet Backend is running",
        "version": "1.0.0"
    })
