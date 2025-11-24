#!/usr/bin/env python3
"""
Script para actualizar el nombre de la organización en la base de datos existente.
"""

from modules.models import actualizar_configuracion, obtener_configuracion

def actualizar_nombre_organizacion():
    nombre_nuevo = 'ASOCIACION DE USUARIOS DE LA SECCION 14 EL BEXHA, A.C.'
    
    print("=== Actualizando nombre de organización en la base de datos ===")
    
    nombre_actual = obtener_configuracion('nombre_oficina')
    print(f"Nombre actual: {nombre_actual}")
    print(f"Nuevo nombre: {nombre_nuevo}")
    
    actualizar_configuracion('nombre_oficina', nombre_nuevo)
    
    # Verificar
    nombre_verificado = obtener_configuracion('nombre_oficina')
    print(f"Nombre verificado: {nombre_verificado}")
    
    if nombre_verificado == nombre_nuevo:
        print("✅ Nombre actualizado correctamente en la base de datos")
    else:
        print("❌ Error al actualizar el nombre")

if __name__ == "__main__":
    actualizar_nombre_organizacion()
