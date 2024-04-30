#!/bin/bash

set -x 

# Parámetros
logsFiles=10
LIMSPath=('/mnt/c/Users/Usuario/Desktop/ClearLogs/J2EE/IBM/WebSphere/AppServer/profiles/PROFILE_APP_001/sdplogs'; '/mnt/c/Users/Usuario/Desktop/ClearLogs/J2EE/IBM/WebSphere/AppServer/profiles/PROFILE_APP_001/aelogs')
AEHistoricPath="/mnt/c/Users/Usuario/Desktop/ClearLogs/J2EE/IBM/WebSphere/AppServer/profiles/PROFILE_APP_001/rotated/ae"
SDPHistoricPath="/mnt/c/Users/Usuario/Desktop/ClearLogs/J2EE/IBM/WebSphere/AppServer/profiles/PROFILE_APP_001/rotated/sdp"
archiveDays=1
logDays=2

### INICIO

fechaCorta=$(date +%Y%m%d)
fechaLarga=$(date +%F-%H-%M)

limspLogsNames=()
logFiles=()

# Recorremos los directorios en LIMSPath
for logPath in "${LIMSPath[@]}"; do

  echo "Procesando logs en ${logPath}:"

  # Comprobamos la ruta
  cd "$logPath" || { echo "Error: No se pudo acceder al directorio de logs ${logPath}."; exit 1; }

  # Obtenemos el nombre del directorio actual
  dirName=$(basename "$logPath")

  # Creamos array con los diferentes logs:
  for archivo in $(ls -1 limsp*.log ltimers*.log 2> /dev/null); do
    # Elimina del nombre todo a partir del último _
    nombre_base=${archivo%_*}

    # Comprobamos si el nombre ya está en el array
    if [[ ! "${limspLogsNames[@]}" =~ "$nombre_base" ]]; then
      # Si no está, lo añadimos al array
      limspLogsNames+=("$nombre_base")
    fi
  done

  # Creamos array con logs a rotar:
  for limspLog in "${limspLogsNames[@]}"; do
    # Obtenemos la rotación actual y la rotación máxima hasta la que vamos a rotar los logs.
    temp=$(ls -1 ${limspLog}*.log | awk -F _ '{print $NF}' | sort -n | tail -1)
    currentRotation=$(echo ${temp%????})
    maxRotation=$((currentRotation - logsFiles))
    test $maxRotation -gt 0 || continue

    for logFile in $(ls -1 ${limspLog}*.log  | sort -n); do
      logRotation=$(echo ${logFile%????} | awk -F _ '{print $NF}')
      if [[ "logRotation" -lt "$maxRotation" ]]; then
        logFiles+=("$logFile")
      fi
    done
  done

  # Mover logs al histórico, si aplica, o eliminarlos
  logsDate=$(date -d "now -${logDays} days" +%Y%m%d)
  cd "${logPath}"
  find . -maxdepth 1 -type d -name "20??????" -exec basename {} \; | while read dayPath; do
    if [ "${dayPath}" -lt "${logsDate}" ]; then
      if [ "${logArchiveDays}" -eq 0 ]; then
        echo "Eliminando directorio de logs ${dayPath}"
        rm -rf "${dayPath}"
      else
        echo "Moviendo al histórico directorio de logs ${dayPath}"
        historicPath="${SDPHistoricPath}"
        if [ "${dirName}" == "ae" ]; then
          historicPath="${AEHistoricPath}"
        fi
        mv "${dayPath}" "${historicPath}"/"${dayPath}"
      fi
    fi
  done

  # Rotamos los logs.
  if [[ ${#logFiles[@]} -gt 0 ]]; then
    tar czf "${logsArchivePath}/limsp-logs-${fechaLarga}-${dirName}.tgz" "${logFiles[@]}"
    if [[ $? -eq 0 ]]; then
      rm -f "${logFiles[@]}"
    fi
  fi

done

# Purgado del histórico
if [ "${archiveDays}" ]; then
  find "$logsArchivePath" -iname "limsp-logs-*.tgz" -mtime +${archiveDays} -delete
fi

echo
echo "Proceso finalizado."
date
exit
