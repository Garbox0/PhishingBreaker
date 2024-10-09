#!/bin/bash

function instalar_dependencias() {
    echo "Actualizando la lista de paquetes..."
    sudo apt update

    echo "Verificando e instalando dependencias necesarias..."
    paquetes=("rspamd" "notify-osd" "dialog" "amavisd-new" "spamassassin" "clamav")

    for paquete in "${paquetes[@]}"; do
        if ! dpkg -l | grep -q "$paquete"; then
            echo "Instalando $paquete..."
            if sudo apt install -y "$paquete"; then
                echo "$paquete instalado correctamente."
            else
                echo "Error: No se pudo instalar $paquete."
                echo "Advertencia: Tendrás problemas con la funcionalidad de $paquete." >> logs/error_log.txt
                sudo apt-get -f install
            fi
        else
            echo "$paquete ya está instalado."
        fi
    done
}

    if ! dpkg -l | grep -q "rspamd"; then
        echo "Instalando rspamd..."
        CODENAME=$(lsb_release -c -s)
        sudo apt-get install -y lsb-release wget gpg
        sudo mkdir -p /etc/apt/keyrings
        wget -O- https://rspamd.com/apt-stable/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/rspamd.gpg > /dev/null
        echo "deb [signed-by=/etc/apt/keyrings/rspamd.gpg] http://rspamd.com/apt-stable/ $CODENAME main" | sudo tee /etc/apt/sources.list.d/rspamd.list
        sudo apt-get update
        if sudo apt-get --no-install-recommends install rspamd; then
            echo "rspamd instalado correctamente."
        else
            echo "Error: No se pudo instalar rspamd." >> logs/error_log.txt
            sudo apt-get -f install
        fi
    else
        echo "rspamd ya está instalado."
    fi

    if ! dpkg -l | grep -q "amavisd-new"; then
        echo "Instalando Amavis..."
        if sudo apt-get install amavisd-new spamassassin clamav; then
            echo "Amavis y herramientas asociadas instaladas correctamente."
        else
            echo "Error: No se pudo instalar Amavis y las herramientas asociadas." >> logs/error_log.txt
            sudo apt-get -f install
        fi
    else
        echo "Amavis ya está instalado."
    fi

    if ! command -v exiftool &> /dev/null; then
        echo "Instalando ExifTool desde la fuente..."
        cd /tmp
        wget https://exiftool.org/Image-ExifTool-12.97.tar.gz -O Image-ExifTool.tar.gz
        tar -xzf Image-ExifTool.tar.gz
        cd Image-ExifTool-12.97

        if perl Makefile.PL && make test && sudo make install; then
            echo "ExifTool instalado correctamente."
        else
            echo "Error: No se pudo instalar ExifTool." >> logs/error_log.txt
        fi
    else
        echo "ExifTool ya está instalado."
    fi
}

function desinstalar_aplicacion() {
    echo "¿Estás seguro de que deseas desinstalar PhishingBreaker y eliminar todas las dependencias? [s/n]"
    read -p "Opción: " confirmar

    if [[ "$confirmar" == "s" ]]; then
        echo "Desinstalando PhishingBreaker..."

        echo "Eliminando archivos de configuración y logs..."
        sudo rm -rf /etc/PhishingBreaker
        sudo rm -rf logs/

        echo "Eliminando dependencias instaladas..."
        paquetes=("rspamd" "amavisd-new" "spamassassin" "clamav" "notify-osd" "exiftool" "dialog")
        for paquete in "${paquetes[@]}"; do
            if dpkg -l | grep -q "$paquete"; then
                echo "Desinstalando $paquete..."
                sudo apt remove --purge -y "$paquete"
            fi
        done

        echo "PhishingBreaker y sus dependencias han sido desinstalados correctamente."
    else
        echo "Desinstalación cancelada."
    fi
}

function crear_directorios_logs() {
    mkdir -p logs/analisis_urls
    mkdir -p logs/verificacion_remitentes
    mkdir -p logs/spamassassin
    mkdir -p logs/rspamd
    mkdir -p logs/amavis
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

function analizar_con_rspamd() {
    local archivo=$1
    echo "Analizando el archivo con rspamd: $archivo"
    rspamc -h localhost < "$archivo" > "logs/rspamd/resultado_rspamd.txt"

    if grep -q "spam" "logs/rspamd/resultado_rspamd.txt"; then
        enviar_alerta "El correo ha sido marcado como SPAM/PHISHING por rspamd."
    else
        echo "El correo parece seguro según rspamd."
    fi
}

function analizar_con_mailscanner() {
    local archivo=$1
    echo "Analizando el archivo con MailScanner: $archivo"
    mailscanner "$archivo" > "logs/mailscanner/resultado_mailscanner.txt"

    if grep -q "Spam detected" "logs/mailscanner/resultado_mailscanner.txt"; then
        enviar_alerta "El correo ha sido marcado como SPAM/PHISHING por MailScanner."
    else
        echo "El correo parece seguro según MailScanner."
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
    echo "3. Escanear con rspamd"
    echo "4. Escanear con MailScanner"
    echo "5. Comprobar dependencias"
    echo "6. Mostrar consejos sobre phishing"
    echo "7. Desinstalar PhishingBreaker"
    echo "8. Salir"
    echo "======================================"
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1) submenu_analisis_correo ;;
        2) submenu_escanear_directorio ;;
        3) submenu_rspamd ;;
        4) submenu_mailscanner ;;
        5) comprobar_dependencias ;;
        6) mostrar_consejos ;;
        7) desinstalar_aplicacion ;;
        8) exit 0 ;;
        *) echo "Opción inválida!" && sleep 2 && menu_principal ;;
    esac
}

function submenu_analisis_correo() {
    clear
    echo "====================="
    echo "   Análisis de Correo Electrónico"
    echo "====================="
    echo "1. Analizar URL en el correo"
    echo "2. Verificar remitente"
    echo "3. Volver al Menú Principal"
    echo ""
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1) 
            archivo=$(seleccionar_archivo)
            if [[ -f "$archivo" ]]; then
                analizar_url "$archivo"
            else
                echo "Error: El archivo especificado no existe."
            fi
            read -p "Presiona Enter para continuar..." && submenu_analisis_correo ;;
        2) 
            archivo=$(seleccionar_archivo)
            if [[ -f "$archivo" ]]; then
                verificar_remitente "$archivo"
            else
                echo "Error: El archivo especificado no existe."
            fi
            read -p "Presiona Enter para continuar..." && submenu_analisis_correo ;;
        3) menu_principal ;;
        *) echo "Opción inválida!" && sleep 2 && submenu_analisis_correo ;;
    esac
}

function submenu_escanear_directorio() {
    clear
    echo "====================="
    echo "   Escaneo de Directorio"
    echo "====================="
    echo "1. Escanear con ClamAV"
    echo "2. Escanear con otra herramienta"
    echo "3. Volver al Menú Principal"
    echo ""
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1)
            directorio=$(seleccionar_directorio)
            if [[ -d "$directorio" ]]; then
                escanear_con_clamav "$directorio"
            else
                echo "Error: El directorio especificado no existe."
            fi
            read -p "Presiona Enter para continuar..." && submenu_escanear_directorio ;;
        2)
            echo "Opción no implementada todavía."
            read -p "Presiona Enter para continuar..." && submenu_escanear_directorio ;;
        3) menu_principal ;;
        *) echo "Opción inválida!" && sleep 2 && submenu_escanear_directorio ;;
    esac
}

function submenu_rspamd() {
    clear
    echo "====================="
    echo "   Escaneo con rspamd"
    echo "====================="
    echo "1. Analizar un correo"
    echo "2. Verificar el estado del servicio"
    echo "3. Volver al Menú Principal"
    echo ""
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1)
            archivo=$(seleccionar_archivo)
            if [[ -f "$archivo" ]]; then
                analizar_con_rspamd "$archivo"
            else
                echo "Error: El archivo especificado no existe."
            fi
            read -p "Presiona Enter para continuar..." && submenu_rspamd ;;
        2)
            echo "Verificando el estado de rspamd..."
            sudo systemctl status rspamd
            read -p "Presiona Enter para continuar..." && submenu_rspamd ;;
        3) menu_principal ;;
        *) echo "Opción inválida!" && sleep 2 && submenu_rspamd ;;
    esac
}

function submenu_mailscanner() {
    clear
    echo "====================="
    echo "   Escaneo con MailScanner"
    echo "====================="
    echo "1. Analizar un correo"
    echo "2. Verificar el estado del servicio"
    echo "3. Volver al Menú Principal"
    echo ""
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1)
            archivo=$(seleccionar_archivo)
            if [[ -f "$archivo" ]]; then
                analizar_con_mailscanner "$archivo"
            else
                echo "Error: El archivo especificado no existe."
            fi
            read -p "Presiona Enter para continuar..." && submenu_mailscanner ;;
        2)
            echo "Verificando el estado de MailScanner..."
            sudo systemctl status mailscanner
            read -p "Presiona Enter para continuar..." && submenu_mailscanner ;;
        3) menu_principal ;;
        *) echo "Opción inválida!" && sleep 2 && submenu_mailscanner ;;
    esac
}

function comprobar_dependencias() {
    echo "Comprobando dependencias..."
    paquetes=("rspamd" "notify-osd" "dialog" "exiftool" "amavisd-new" "spamassassin" "clamav")

    for paquete in "${paquetes[@]}"; do
        if ! dpkg -l | grep -q "$paquete"; then
            echo "Error: $paquete no está instalado."
        else
            echo "$paquete está instalado."
        fi
    done

    echo "Presiona Enter para continuar..."
    read
}

instalar_dependencias
crear_directorios_logs

while true; do
    menu_principal
done
