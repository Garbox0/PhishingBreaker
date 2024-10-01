# PhishingBreaker

PhishingBreaker es una herramienta de análisis de seguridad diseñada para ayudar a los usuarios a identificar correos electrónicos y mensajes sospechosos que pueden contener intentos de phishing. Esta aplicación de línea de comandos en Bash permite a los usuarios escanear correos, verificar remitentes y obtener consejos para prevenir ataques de phishing.

## Características

- **Análisis de URLs**: Detecta URLs acortadas y potencialmente peligrosas en correos electrónicos.
- **Verificación de remitentes**: Compara el dominio del remitente con un dominio confiable para identificar posibles fraudes.
- **Integración con SpamAssassin**: Analiza correos electrónicos en busca de spam y phishing.
- **Escaneo con ClamAV**: Verifica archivos adjuntos en busca de malware.
- **Consejos de seguridad**: Proporciona recomendaciones sobre cómo identificar correos sospechosos.
- **Estructura de logs**: Almacena los resultados de los análisis en carpetas organizadas.

## Instalación

1. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/PhishingBreaker.git
   cd PhishingBreaker
   chmod +x PhishingBreaker.sh
   ./PhishingBreaker.sh
   ```
