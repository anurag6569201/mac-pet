
import threading
import time
import os
import asyncio
from typing import Optional
import speech_recognition as sr
from django.conf import settings
from .voice_assistant_service import BasicVoiceAssistant, logger
from azure.core.credentials import AzureKeyCredential

class VoiceManager:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super(VoiceManager, cls).__new__(cls)
                cls._instance._initialized = False
            return cls._instance

    def __init__(self):
        if self._initialized:
            return
        
        self.is_running = False
        self.current_status = "idle"
        self.last_message = ""
        self.thread: Optional[threading.Thread] = None
        self.stop_event = threading.Event()
        self.assistant: Optional[BasicVoiceAssistant] = None
        self._initialized = True

    def get_status(self):
        return {
            "status": self.current_status,
            "message": self.last_message,
            "is_running": self.is_running
        }

    def _update_status(self, status, message=None):
        self.current_status = status
        if message:
            self.last_message = message
        # logger.info(f"Voice Status: {status} - {message}")

    def start_listening(self):
        with self._lock:
            if self.is_running:
                return False, "Already running"
            
            self.stop_event.clear()
            self.is_running = True
            self.thread = threading.Thread(target=self._run_loop, daemon=True)
            self.thread.start()
            return True, "Started voice assistant"

    def stop_listening(self):
        with self._lock:
            if not self.is_running:
                return False, "Not running"
            
            self.stop_event.set()
            if self.assistant:
                self.assistant.stop()
            
            # We don't join the thread here to avoid blocking the API request
            # The thread will exit gracefully
            self.is_running = False
            self._update_status("stopped", "Stopping...")
            return True, "Stop signal sent"

    def _run_loop(self):
        self._update_status("initializing", "Starting voice manager...")
        
        recognizer = sr.Recognizer()
        microphone = sr.Microphone()

        # Load environment variables if not loaded
        api_key = os.environ.get("AZURE_VOICELIVE_API_KEY")
        endpoint = os.environ.get("AZURE_VOICELIVE_ENDPOINT", "https://anurag6569201-1049-resource.services.ai.azure.com/")
        model = os.environ.get("AZURE_VOICELIVE_MODEL", "gpt-realtime")
        voice = os.environ.get("AZURE_VOICELIVE_VOICE", "en-US-Ava:DragonHDLatestNeural")
        instructions = os.environ.get(
            "AZURE_VOICELIVE_INSTRUCTIONS",
            "You are a helpful AI assistant. Respond naturally and conversationally."
        )

        if not api_key:
             self._update_status("error", "Missing Azure API Key")
             # Try loading from .env if possible, but environment should be set
             from dotenv import load_dotenv
             load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env'))
             api_key = os.environ.get("AZURE_VOICELIVE_API_KEY")
             if not api_key:
                self.is_running = False
                return

        credential = AzureKeyCredential(api_key)

        print(f"🎤 [VoiceManager] Initializing with device: {microphone.device_index}")
        
        try:
            with microphone as source:
                print("🎤 [VoiceManager] Adjusting for ambient noise... (Please be quiet)")
                recognizer.adjust_for_ambient_noise(source, duration=1)
                print(f"🎤 [VoiceManager] Threshold set to {recognizer.energy_threshold}")
        except Exception as e:
            self._update_status("error", f"Microphone init failed: {e}")
            print(f"❌ [VoiceManager] Microphone init failed: {e}")
            self.is_running = False
            return
        
        while not self.stop_event.is_set():
            try:
                self._update_status("listening_wake_word", "Waiting for 'Hey Pet'...")
                # print("👂 [VoiceManager] Listening for wake word...")
                
                # Listen for wake word (short timeout to check stop_event)
                try:
                    with microphone as source:
                        # minimal timeout to allow loop to check stop_event
                        # phrase_time_limit=3 prevents it from getting stuck listening to background noise
                        audio = recognizer.listen(source, timeout=2, phrase_time_limit=3)
                    
                    try:
                        text = recognizer.recognize_google(audio).lower()
                        print(f"🗣️  [VoiceManager] Heard: '{text}'")
                        
                        if "hey pet" in text or "hey pat" in text or "hi pet" in text:
                            self._update_status("wake_word_detected", "Wake word detected!")
                            print("🚀 [VoiceManager] Wake word detected! Starting Assistant...")
                            
                            # Initialize and start assistant
                            self.assistant = BasicVoiceAssistant(
                                endpoint=endpoint,
                                credential=credential,
                                model=model,
                                voice=voice,
                                instructions=instructions,
                                status_callback=self._update_status
                            )
                            
                            # run async start in this thread
                            asyncio.run(self.assistant.start())
                            
                            self.assistant = None # Reset after session ends
                            # Re-adjust after conversation to handle shifting noise levels
                            with microphone as source:
                                recognizer.adjust_for_ambient_noise(source, duration=0.5)
                            
                    except sr.UnknownValueError:
                        # print("🤷 [VoiceManager] Could not understand audio")
                        continue # unintelligible audio
                    except sr.RequestError as e:
                        self._update_status("error", "Speech service error")
                        print(f"❌ [VoiceManager] Speech recognition error: {e}")
                        time.sleep(2)
                        
                except sr.WaitTimeoutError:
                    # print("TIMEOUT")
                    continue
                except Exception as e:
                    self._update_status("error", f"Error in wake loop: {e}")
                    print(f"❌ [VoiceManager] Error in wake loop inner: {e}")
                    time.sleep(1)
                    
            except Exception as e:
                self._update_status("error", f"Fatal error: {e}")
                print(f"❌ [VoiceManager] Fatal loop error: {e}")
                break
        
        self.is_running = False
        self._update_status("stopped", "Voice manager stopped")
        print("🛑 [VoiceManager] Loop exited.")
