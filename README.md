# CultivoID

## Asistencia Biométrica Facial Offline para Entornos Agrícolas

!Logo(assets/images/logo_cultivoid.png)
**CultivoID** es una solución de vanguardia desarrollada para el registro de asistencia biométrica facial, diseñada específicamente para operar en entornos con conectividad a internet limitada o nula, como la agroindustria o zonas rurales. Este proyecto fue desarrollado como respuesta al reto "Identidad del Campo" de SIOMA, ofreciendo una alternativa robusta y segura a los métodos tradicionales de registro.

## Características Principales

* **Reconocimiento Facial Offline:** Utiliza un modelo de Machine Learning (MobileFaceNet TFLite) ejecutado directamente en el dispositivo (edge computing), permitiendo la identificación de trabajadores sin necesidad de conexión a la nube.
* **Base de Datos Local Cifrada:** Todos los registros de asistencia y los datos sensibles de los empleados se almacenan en una base de datos SQLite local, cifrada con SQLCipher (AES de 256 bits). Esto garantiza la seguridad y privacidad de la información.
* **Sincronización Inteligente:** Monitorea activamente la conectividad de red. Cuando se detecta una conexión, sincroniza automáticamente los registros pendientes con un servidor externo (API simulada en este proyecto), asegurando que ningún dato se pierda y manteniendo la información actualizada.
* **Gestión de Empleados y Áreas:**
    * Registro de nuevos trabajadores mediante captura facial en múltiples poses.
    * Asignación y creación de "Áreas de Trabajo" para organizar al personal.
    * Edición y eliminación de perfiles de empleados.
    * Visualización de empleados agrupados por área.
* **Acceso Seguro a Configuración:** Un PIN de seguridad protege el acceso a las funciones administrativas de la aplicación.
* **Escaneo de Emergencia (Valor Añadido):** Una función innovadora que permite identificar rápidamente a un trabajador mediante la cámara trasera para acceder a datos médicos vitales (tipo de sangre, alergias, contacto de emergencia, EPS), crucial para situaciones de seguridad en entornos de campo.

## Tecnologías Utilizadas

* **Flutter:** Framework para el desarrollo multiplataforma (Android).
* **Dart:** Lenguaje de programación.
* **TensorFlow Lite:** Para la ejecución del modelo de Machine Learning de reconocimiento facial (MobileFaceNet).
* **`camera`:** Acceso y control de la cámara del dispositivo.
* **`sqflite_sqlcipher`:** Base de datos SQLite local con cifrado.
* **`flutter_secure_storage`:** Almacenamiento seguro de claves de cifrado y PINs.
* **`connectivity_plus`:** Detección del estado de la conexión a internet.
* **`http`:** Realización de peticiones HTTP para la sincronización.
* **`provider` / `get_it` / `ServiceLocator`:** Gestión de estado y localización de servicios (ajusta según tu implementación específica).

## Arquitectura

La aplicación sigue principios de arquitectura limpia, utilizando inyección de dependencias (a través de un `ServiceLocator`) para desacoplar componentes y facilitar la escalabilidad y el mantenimiento. Los servicios principales (reconocimiento, autenticación, embebber de ML, sincronización) son gestionados centralizadamente.

## Cómo Ejecutar el Proyecto

### Prerrequisitos

* [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado (Versión 3.x recomendada).
* Un dispositivo Android o emulador configurado (API nivel 24+ recomendado).

### Pasos de Configuración

1.  **Clona el Repositorio:**
    ```bash
    git clone https://github.com/DanielCifuentes1997/CultivoID.git
    (https://github.com/TU_USUARIO_DE_GITHUB/NOMBRE_DE_TU_REPOSITORIO.git)
    cd NOMBRE_DE_TU_REPOSITORIO

2.  **Obtén las Dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Asegura los Assets:**
    Verifica que el modelo TFLite (`assets/models/mobilefacenet_112x112_128d.tflite`) y los logos (`assets/images/logo_dataface.png`, `assets/images/logo_sioma.png`) estén presentes en sus respectivas carpetas y declarados correctamente en `pubspec.yaml`.

4.  **Ejecuta la Aplicación:**
    ```bash
    flutter run
    ```

### Consideraciones de Seguridad

* La base de datos cifrada y las claves se gestionan para máxima seguridad en el dispositivo.
* El PIN de acceso a la configuración se almacena de forma segura.
* El modelo ML se ejecuta localmente, sin enviar datos biométricos a la nube para la identificación.

## Contribuciones

Este proyecto se desarrolló en el marco de la Hackathon Data Synergy. Las contribuciones futuras son bienvenidas. Si tienes sugerencias o mejoras, no dudes en abrir un *issue* o enviar un *pull request*.