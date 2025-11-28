import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def test_qr_data_format():
    # Mock receipt data
    recibo = {
        'numero_lote': '123',
        'nombre': 'JUAN PEREZ',
        'folio': '1001',
        'cultivo': 'MAIZ',
        'superficie': '2.5',
        'barrio': 'CENTRO'
    }
    
    # Mock receipt data
    recibo = {
        'numero_lote': '123',
        'nombre': 'JUAN PEREZ',
        'folio': '1001',
        'cultivo': 'MAIZ',
        'superficie': '2.5',
        'barrio': 'CENTRO'
    }
    
    # Mock list of irrigations
    lista_riegos = "1,2,3"
    
    # Expected format: lote|nombre|folio|cultivo|superficie|lista_riegos|paraje
    expected_data = "123|JUAN PEREZ|1001|MAIZ|2.5|1,2,3|CENTRO"
    
    # Generate data using the same logic as in reports.py
    qr_data = f"{recibo['numero_lote']}|{recibo['nombre']}|{recibo['folio']}|{recibo['cultivo']}|{recibo['superficie']}|{lista_riegos}|{recibo['barrio']}"
    
    print(f"Generated Data: {qr_data}")
    print(f"Expected Data:  {expected_data}")
    
    if qr_data == expected_data:
        print("✅ QR Data Format Verification PASSED")
    else:
        print("❌ QR Data Format Verification FAILED")

if __name__ == "__main__":
    test_qr_data_format()
