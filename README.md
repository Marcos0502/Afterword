# AFTERWAR — Android Vertical Slice 0.1

Primer prototipo jugable de AFTERWAR basado en el GDD maestro v0.2.

## Alcance
- Valle 17, mapa compacto generado con geometría procedural simple.
- Cámara en tercera persona.
- Movimiento WASD y control táctil.
- Hambre, sed y salud.
- Recolección de agua, comida, madera y metal.
- Construcción del purificador y refugio permanente.
- NPC Elena con interacción narrativa.
- Guardado local en `user://afterwar_save.json`.
- Ciclo día/noche simplificado.
- Arquitectura inicial con datos separados en `data/`.

## Build cloud
El pipeline canónico se encuentra en `.github/workflows/android-apk.yml`.
El workflow descarga Godot 4.7.2 y sus export templates, prepara Android SDK/Build Tools 36 y exporta `build/afterwar-debug.apk`.

## Próximas fases
1. Persistencia y UX avanzada.
2. Comunidad de 5 supervivientes y trabajos.
3. NPC/IA y fauna.
4. Crafting ampliado y construcción modular.
5. Mundo streaming y producción de contenido.
