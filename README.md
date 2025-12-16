CultivoID: Asistencia Biométrica Facial Offline
CultivoID es una solución de vanguardia diseñada para el registro de asistencia mediante biometría facial, optimizada para operar en entornos con conectividad a internet limitada o nula, como la agroindustria o zonas rurales. Este proyecto fue desarrollado como respuesta al reto "Identidad del Campo" de SIOMA, ofreciendo una alternativa robusta y segura a los métodos tradicionales de registro.

Características Principales
Reconocimiento Facial sin Conexión: Utiliza un modelo de ejecución en dispositivo (edge computing), lo que permite la identificación de trabajadores en tiempo real sin depender de una conexión a la nube.

Base de Datos Local Cifrada: Los registros de asistencia y la información sensible de los empleados se almacenan en una base de datos SQLite local, cifrada con SQLCipher (AES de 256 bits), garantizando la máxima seguridad y privacidad.

Sincronización Inteligente: Monitorea el estado de la red. Al detectar conectividad, sincroniza automáticamente los registros pendientes con un servidor externo, asegurando la integridad y actualización de los datos.

Gestión de Personal y Áreas:

Registro de nuevos trabajadores mediante captura facial multi-pose.

Asignación y creación de "Áreas de Trabajo".

Visualización, edición y eliminación de perfiles de empleados.

Acceso Seguro: Un PIN protege el acceso a las funciones administrativas y de configuración de la aplicación.

Escaneo de Emergencia (Valor Añadido): Función para identificar rápidamente a un trabajador usando la cámara y acceder a datos médicos vitales (tipo de sangre, alergias, contacto de emergencia), crucial para situaciones de seguridad en entornos de campo.

Tecnologías Utilizadas
Flutter & Dart: Framework y lenguaje base para el desarrollo multiplataforma (Android).

TensorFlow Lite: Para la ejecución local del modelo de reconocimiento facial.

Almacenamiento y Seguridad: sqflite_sqlcipher (Base de datos cifrada) y flutter_secure_storage (Almacenamiento seguro de claves).

Conectividad: connectivity_plus (Detección de estado de red) y http (Peticiones para sincronización).

Arquitectura: Principios de Arquitectura Limpia, utilizando inyección de dependencias (provider / get_it) para componentes desacoplados.

Arquitectura
La aplicación sigue principios de arquitectura limpia, utilizando inyección de dependencias para desacoplar componentes, lo que facilita la escalabilidad y el mantenimiento. Los servicios principales (reconocimiento, autenticación, sincronización, gestión de datos) son gestionados centralizadamente.

Cómo Ejecutar el Proyecto
Prerrequisitos
Flutter SDK instalado (Versión 3.x recomendada).

Un dispositivo Android o emulador configurado (API nivel 24+ recomendado).

Pasos de Configuración
Clona el Repositorio:

Bash

git clone https://aws.amazon.com/es/what-is/repo/
cd CultivoID
Obtén las Dependencias:

Bash

flutter pub get
Asegura los Assets: Verifica que el modelo TFLite (assets/models/...) y otros archivos necesarios estén presentes en sus respectivas carpetas y declarados correctamente en pubspec.yaml.

Ejecuta la Aplicación:

Bash

flutter run
Consideraciones de Seguridad
La base de datos cifrada y sus claves se gestionan para máxima seguridad en el dispositivo.

El PIN de acceso a la configuración se almacena de forma segura.

El modelo de reconocimiento se ejecuta localmente, sin enviar datos biométricos a la nube para la identificación.

Contribuciones
Este proyecto se desarrolló en el marco de la Hackathon Data Synergy. Si tienes sugerencias o mejoras, eres bienvenido a abrir un issue o enviar un pull request.
