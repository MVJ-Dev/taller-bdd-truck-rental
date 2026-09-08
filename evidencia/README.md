# Evidencia de ejecución

Salidas de consola **reales** capturadas al ejecutar los procesos en Oracle 21c XE
(septiembre 2026). Confirman los resultados reportados en `docs/resultados-esperados.md`.

| Archivo | Contenido |
|---|---|
| `salida_proceso_a_2025.txt` | Proceso A para el año 2025 (17 multas, 0 inconsistencias) |
| `salida_proceso_a_2026.txt` | Proceso A para el año 2026 (21 multas, 1 inconsistencia: arriendo 104) |
| `salida_proceso_b_2025.txt` | Proceso B para el año 2025 (12 camiones insertados, 13 excluidos) |
| `salida_proceso_b_2026.txt` | Proceso B para el año 2026 (12 camiones insertados, 13 excluidos) |
| `salida_reejecucion_dup_val.txt` | Reejecución del Proceso A 2025 → dispara DUP_VAL_ON_INDEX y omite duplicados |
| `salida_verificacion_tablas.txt` | Conteo final (38 y 24), distribución por período e historial completo |

## Capturas de pantalla (opcional, para el .docx)

Si el formato de entrega exige capturas de SQL Developer además del texto, sugerencia
de nombres:

- `proceso_a_2025.png`, `proceso_a_2026.png`
- `proceso_b_2025.png`, `proceso_b_2026.png`
- `excepcion_arriendo_104.png` (la excepción propia disparándose)
- `excepcion_dup_val.png` (DUP_VAL_ON_INDEX al reejecutar)
- `verificacion_tablas.png` (SELECT final sobre ambas tablas)

Estas capturas van en el anexo 7.3 del informe.
