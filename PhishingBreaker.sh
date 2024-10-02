#!/bin/bash

function instalar_dependencias() {
    echo "Actualizando la lista de paquetes..."
    sudo apt update
    echo "Verificando e instalando dependencias necesarias..."
    paquetes=("spamassassin" "clamav" "notify-osd" "exiftool" "dialog")
    herramientas_afectadas=("Análisis de correos con SpamAssassin" "Escaneo de archivos adjuntos con ClamAV" "Notificaciones de alertas" "Análisis de metadatos con ExifTool" "Selección de archivos y directorios")
    
    for i in "${!paquetes[@]}"; do
        paquete="${paquetes[$i]}"
        herramienta_afectada="${herramientas_afectadas[$i]}"
        
        if ! dpkg -l | grep -q "$paquete"; then
            echo "Instalando $paquete..."
            if sudo apt install -y "$paquete"; then
                echo "$paquete instalado correctamente."
            else
                echo "Error: No se pudo instalar $paquete."
                echo "Advertencia: Tendrás problemas con la funcionalidad: $herramienta_afectada." >> logs/error_log.txt
            fi
        else
            echo "$paquete ya está instalado."
        fi
    done
}

function comprobar_dependencias() {
    echo "Comprobando dependencias..."
    paquetes=("spamassassin" "clamav" "notify-osd" "exiftool" "dialog")
    
    for paquete in "${paquetes[@]}"; do
        if ! dpkg -l | grep -q "$paquete"; then
            echo "Error: $paquete no está instalado."
        else
            echo "$paquete está instalado."
        fi
    done
}

function crear_directorios_logs() {
    mkdir -p logs/analisis_urls
    mkdir -p logs/verificacion_remitentes
    mkdir -p logs/spamassassin
    mkdir -p logs/clamav
    mkdir -p logs/error_log
}

function seleccionar_archivo() {
    local archivo_seleccionado=$(dialog --stdout --title "Seleccionar archivo" --fselect $HOME/ 14 48)
    if [ -n "$archivo_seleccionado" ] && [ -f "$archivo_seleccionado" ]; then
        echo "$archivo_seleccionado"
    else
        echo ""
    fi
}

function seleccionar_directorio() {
    local directorio_seleccionado=$(dialog --stdout --title "Seleccionar directorio" --dselect $HOME/ 14 48)
    if [ -n "$directorio_seleccionado" ] && [ -d "$directorio_seleccionado" ]; then
        echo "$directorio_seleccionado"
    else
        echo ""
    fi
}

function analizar_url() {
    local archivo=$1
    echo "Analizando el archivo: $archivo"
    
    grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" "$archivo" > "logs/analisis_urls/urls_extraidas.txt"

    if grep -E "(bit.ly|tinyurl|goo.gl)" "logs/analisis_urls/urls_extraidas.txt" > /dev/null; then
        echo "¡Alerta! Se encontraron URLs acortadas sospechosas."
        enviar_alerta "Se encontraron URLs sospechosas en el análisis."
    else
        echo "No se encontraron URLs sospechosas."
    fi
}

function verificar_remitente() {
    local archivo=$1
    local dominio_confiable="tudominio.com"
    
    remitente=$(grep -i "From:" "$archivo" | awk '{print $2}')
    echo "Remitente detectado: $remitente"
    
    if [[ "$remitente" != *"$dominio_confiable"* ]]; then
        echo "¡Cuidado! El remitente no pertenece al dominio confiable."
        enviar_alerta "El remitente no pertenece al dominio confiable."
    else
        echo "El remitente parece ser seguro."
    fi
}

function enviar_alerta() {
    local mensaje=$1
    notify-send "PhishAlert" "$mensaje" --icon=dialog-warning
}

function mostrar_consejos() {
    echo "Consejos para evitar el phishing:"
    echo "1. No hagas clic en enlaces de correos inesperados."
    echo "2. Verifica siempre la URL antes de introducir información personal."
    echo "3. Desconfía de correos que te pidan actuar de forma urgente."
    echo "4. Nunca compartas información confidencial a través de enlaces sospechosos."
    read -p "Presiona Enter para continuar..."
}

function escanear_directorio() {
    local directorio=$1
    echo "Escaneando todos los archivos en el directorio: $directorio"
    
    for archivo in "$directorio"/*; do
        if [ -f "$archivo" ]; then
            echo "Analizando el archivo: $archivo"
            analizar_url "$archivo"
            verificar_remitente "$archivo"
        fi
    done
}

function analizar_con_spamassassin() {
    local archivo=$1
    echo "Analizando el archivo con SpamAssassin: $archivo"
    spamassassin "$archivo" > "logs/spamassassin/resultado_spamassassin.txt"

    if grep -q "X-Spam-Status: Yes" "logs/spamassassin/resultado_spamassassin.txt"; then
        echo "¡Alerta! El correo ha sido marcado como SPAM/PHISHING."
        enviar_alerta "El correo ha sido marcado como SPAM/PHISHING."
    else
        echo "El correo parece seguro."
    fi
}

function escanear_con_clamav() {
    local archivo=$1
    echo "Escaneando archivo adjunto con ClamAV: $archivo"
    clamscan "$archivo" > "logs/clamav/resultado_clamav.txt"

    if grep -q "Infected files: 0" "logs/clamav/resultado_clamav.txt"; then
        echo "El archivo está limpio."
    else
        echo "¡Alerta! Se detectó malware en el archivo."
        enviar_alerta "Se detectó malware en el archivo adjunto."
    fi
}

function menu_principal() {
    clear
    echo "=====================" 
    figlet  "PhishingBreaker"
    echo                "by GarboX0" 
    echo "====================="
    echo "1. Analizar un correo electrónico"
    echo "2. Escanear un directorio completo"
    echo "3. Escanear con SpamAssassin"
    echo "4. Escanear con ClamAV"
    echo "5. Comprobar dependencias"
    echo "6. Mostrar consejos sobre phishing"
    echo "7. Salir"
    echo "======================================"
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1) 
            seleccionar_servicio
            archivo=$(seleccionar_archivo)
            if [[ -f "$archivo" ]]; then
                analizar_url "$archivo"
                verificar_remitente "$archivo"
            else
                echo "Error: El archivo especificado no existe."
            fi
            ;;
        2) 
            directorio=$(seleccionar_directorio)
            if [[ -d "$directorio" ]]; then
                escanear_directorio "$directorio"
            else
                echo "Error: El directorio especificado no existe."
            fi
            ;;
        3) 
            archivo=$(seleccionar_archivo)
            if [[ -f "$archivo" ]]; then
                analizar_con_spamassassin "$archivo"
            else
                echo "Error: El archivo especificado no existe."
            fi
            ;;
        4)
            archivo=$(seleccionar_archivo)
            if [[ -f "$archivo" ]]; then
                escanear_con_clamav "$archivo"
            else
                echo "Error: El archivo especificado no existe."
            fi
            ;;
        5)
            comprobar_dependencias
            ;;
        6) 
            mostrar_consejos
            ;;
        7)
            exit 0
            ;;
        *) 
            echo "Opción inválida. Por favor, selecciona una opción válida."
            ;;
    esac
}

function comprobar_dependencias() {
    echo "Comprobando dependencias..."
    paquetes=("spamassassin" "clamav" "notify-osd" "exiftool" "dialog")
    echo "Dependencias instaladas:"
    
    for paquete in "${paquetes[@]}"; do
        if dpkg -l | grep -q "$paquete"; then
            echo "$paquete está instalado."
        else
            echo "Error: $paquete no está instalado."
        fi
    done
}

instalar_dependencias
crear_directorios_logs

while true; do
    menu_principal
done
