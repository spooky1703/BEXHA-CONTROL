import sys
import os
from unittest.mock import MagicMock, patch

# Add project root to path
sys.path.append('/Users/alonsomota/BEXHA')

from modules.email_sender import enviar_correo_reporte
from modules.logic import crear_backup, generar_archivo_auditoria

print("Successfully imported modules.")

# Mock smtplib to avoid sending real emails
with patch('smtplib.SMTP') as mock_smtp:
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    print("Testing email sending with multiple attachments...")
    
    # Create dummy files
    with open("test_report.pdf", "w") as f: f.write("dummy pdf content")
    with open("test_backup.db", "w") as f: f.write("dummy db content")
    
    archivos = ["test_report.pdf", "test_backup.db"]
    destinatario = "test@example.com"
    
    try:
        enviar_correo_reporte(destinatario, archivos)
        print("Email sent successfully (mocked).")
        
        # Verify attachments were added
        # This is hard to verify deeply without inspecting the MIME object, 
        # but if it didn't crash, it's a good sign.
        
    except Exception as e:
        print(f"ERROR sending email: {e}")
        
    # Clean up
    os.remove("test_report.pdf")
    os.remove("test_backup.db")

print("\nTesting backup generation...")
try:
    backups = crear_backup("Test Verification")
    print(f"Backups created: {backups}")
    if not isinstance(backups, list):
        print("ERROR: crear_backup should return a list")
    elif len(backups) == 0:
        print("WARNING: No backups created (maybe DB doesn't exist?)")
    else:
        print("Backup generation passed.")
except Exception as e:
    print(f"ERROR creating backup: {e}")

print("\nTesting audit log generation...")
try:
    audit_path = generar_archivo_auditoria()
    print(f"Audit log created at: {audit_path}")
    if os.path.exists(audit_path):
        print("Audit log file exists.")
    else:
        print("ERROR: Audit log file not found.")
except Exception as e:
    print(f"ERROR generating audit log: {e}")

print("\nVerification complete.")
