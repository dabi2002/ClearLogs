#!/bin/bash

set -x
# Parámetros
logsFiles=4
logsArchivePath="/home/drodriguez/historic"
logsPath="/home/drodriguez/logs"
archiveDays=2
username="drodriguez"

# Definicion de fechas para cada uno de los usos
fechaCorta=$(date +%Y%m%d)
fechaLarga=$(date +%F-%H-%M)

# Definimos las rutas de los logs y sus respectivos directorios históricos
declare -A logPaths=(
    ["SDP"]="$logsPath/sdp"
    ["AE"]="$logsPath/ae"
)

declare -A historicPaths=(
    ["SDP"]="$logsArchivePath/sdp"
    ["AE"]="$logsArchivePath/ae"
)
# Definimos los nodos donde ingresará el script
declare -A nodos=(
    ["nodo1"]="server1-l03-nodo2"  
    ["nodo2"]="server2-l03-nodo2"  
    ["nodo3"]="server3-l04-nodo1"  
)
# Función para procesar logs en una ruta dada
process_logs() {
    set -x

    local logPath=$1
    local dirNameHist=$2
    local historicPath=$3
    local archiveDays=$4
    local fechaCorta=$5
    local logsFiles=$6
    
    cd $logPath/$fechaCorta
    # Creamos array con los diferentes logs
    limspLogsNames=()
    for archivo in $(ls -1 limsp*.log ltimers*.log 2> /dev/null); do
        # Elimina del nombre todo a partir del último _
        nombre_base=${archivo%_*}

        # Comprobamos si el nombre ya está en el array
        if [[ ! "${limspLogsNames[@]}" =~ "$nombre_base" ]]; then
            # Si no está, lo añadimos al array
            limspLogsNames+=("$nombre_base")
        fi
    done

    # Ahora procesamos los logs para cada nombre base
    for limspLog in "${limspLogsNames[@]}"; do
        # Obtenemos la rotación actual y la rotación máxima hasta la que vamos a rotar los logs
        temp=$(ls -1 ${limspLog}_*.log | awk -F \_ '{print $NF}' | sort -n | tail -1)
        currentRotation=$(echo ${temp%????})
        maxRotation=$((currentRotation - logsFiles))
        test $maxRotation -gt 0 || continue

        logFilesArray=()  # Reiniciamos el array de archivos de logs para cada nombre base

        # Procesamos los archivos de logs para este nombre base
        for logFile in $(ls -1 ${limspLog}_*.log  | sort -n); do
            logRotation=$(echo ${logFile%????} | awk -F \_ '{print $NF}')
            if [[ $logRotation -lt $maxRotation ]]; then
                logFilesArray+=("$logFile")
            fi
        done

        # Rotamos los logs.
        if [[ ${#logFilesArray[@]} -gt 0 ]]; then
            tar czf "${logPath}/${fechaCorta}/limsp-logs-archives-rotation.tgz" "${logFilesArray[@]}"
            if [[ $? -eq 0 ]]; then
                rm -f "${logFilesArray[@]}"
            fi
        fi
    done 

# Mover logs al histórico, si aplica, o eliminarlos
logsDate=$(date -d "${fechaCorta} - ${archiveDays} days" +%Y%m%d)
cd "$logPath"
find . -maxdepth 1 -type d -name "20??????" -exec basename {} \; | grep -o '[0-9]\{8\}' | while read dayPath; do
    # Verificar si dayPath es menor que logsDate
    if [ "$dayPath" -lt "$logsDate" ]; then
        if [ "${archiveDays}" -eq 0 ]; then
            echo "Eliminando directorio de logs ${dayPath}"
            rm -rf "${dayPath}"
        else
            echo "Moviendo al histórico directorio de logs ${dayPath}"
            mv "${dayPath}" "${historicPath}"
        fi
    fi
done

}

ssh_session(){
    local nodo=$1
    local logPath=$2
    local dirName=$3
    local historicPath=$4
    local archiveDays=$5
    local fechaCorta=$6
    local logsFiles=$7
    echo "Ingresando a sesión SSH en $nodo..."
    ssh -o ForwardX11=no "$username"@"$nodo" "
        cd "$logPath"
        $(typeset -f process_logs)  # Exportar la función process_logs a la sesión SSH
        process_logs "$logPath" "$dirName" "$historicPath" "$archiveDays" "$fechaCorta" "$logsFiles" # Llamar a la función process_logs dentro de la sesión SSH
    "
}

# Recorremos los nodos y directorios simultáneamente
for nodo in "${!nodos[@]}"; do
    nodeName="${nodos[$nodo]}"
    for dirName in "${!logPaths[@]}"; do
        logPath=${logPaths[$dirName]}
        historicPath=${historicPaths[$dirName]}
        echo "Procesando logs en ${logPath} en el nodo ${nodos[$nodo]}:"

        # Llamamos a la función ssh_session para este nodo y directorio
        ssh_session "$nodeName" "$logPath" "$dirName" "$historicPath" "$archiveDays" "$fechaCorta" "$logsFiles"
    done
done


# Purgado del histórico
if [ "${archiveDays}" ]; then   
    find "$logsArchivePath" -iname "limsp-logs-*.tgz" -mtime +${archiveDays} -delete
fi

echo
echo "Proceso finalizado."
date
exit
