import sys
import os

sys.path.append('/Users/alonsomota/BEXHA')

from modules.whatsapp_handler import abrir_chat_whatsapp
from modules.ui_components import VentanaAgenda

print("Successfully imported modules.")

if hasattr(VentanaAgenda, 'abrir_whatsapp'):
    print("VentanaAgenda has method 'abrir_whatsapp'.")
else:
    print("ERROR: VentanaAgenda missing 'abrir_whatsapp'.")

import webbrowser
from unittest.mock import MagicMock

webbrowser.open = MagicMock()

print("Testing abrir_chat_whatsapp with '1234567890'...")
abrir_chat_whatsapp('1234567890')
webbrowser.open.assert_called_with('https://web.whatsapp.com/send?phone=521234567890')
print("Test 1 passed (10 digits adds 52).")

print("Testing abrir_chat_whatsapp with '(55) 1234-5678'...")
abrir_chat_whatsapp('(55) 1234-5678')
webbrowser.open.assert_called_with('https://web.whatsapp.com/send?phone=525512345678')
print("Test 2 passed (formatting).")

print("Verification complete.")
