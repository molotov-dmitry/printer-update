#!/bin/bash

contains()
{
    local e
    local match="$1"
    shift
  
    for e
    do
        if [[ "$e" == "$match" ]]
        then
            return 0
        fi
    done
    
    return 1
}

readonly -a PRINTERS_OLD=('HP_Laserjet_1320')
readonly -a PRINTERS=('Kyocera_Dev')

declare -A PRINTER_DESCRIPTIONS
declare -A PRINTER_LOCATIONS
declare -A PRINTER_URI
declare -A PRINTER_MODEL
declare -A PRINTER_DRIVER

declare -a printers

PRINTER_DESCRIPTIONS['Kyocera_Dev']='Kyocera Dev'
PRINTER_LOCATIONS['Kyocera_Dev']='Комната 310'
PRINTER_URI['Kyocera_Dev']='socket://10.0.0.165'
PRINTER_MODEL['Kyocera_Dev']='Generic PCL 6/PCL XL Printer Foomatic/pxlcolor (recommended)'
PRINTER_DRIVER['Kyocera_Dev']='foomatic-db-compressed-ppds:0/ppd/foomatic-ppd/Generic-PCL_6_PCL_XL_Printer-pxlcolor.ppd'

printers=( $(LC_ALL=C lpstat -v | awk '{ print $3 }' | tr ':' ' ') )

for printer in "${printers[@]}"
do
    #### Remove old printers ===================================================
    
    if contains "${printer}" "${PRINTERS_OLD[@]}"
    then
        /usr/sbin/lpadmin -x "${printer}"
        echo "Removed '${printer}'"
    fi
    
    #### Update printer configuration ==========================================
    
    if contains "${printer}" "${PRINTERS[@]}"
    then
        printer_description="$(LC_ALL=C lpstat -l -p "${printer}" | grep 'Description:' | cut -d ':' -f 2- | sed 's/^[ ]*//;s/[ ]*$//')"
        printer_location="$(LC_ALL=C lpstat -l -p "${printer}" | grep 'Location:' | cut -d ':' -f 2- | sed 's/^[ ]*//;s/[ ]*$//')"
        printer_uri="$(LC_ALL=C lpstat -v "${printer}" | cut -d ':' -f 2- | sed 's/^[ ]*//;s/[ ]*$//')"
        printer_model="$(lpoptions -p "${printer}" | grep -o "printer-make-and-model='[^']*" | cut -d "'" -f 2-)"
        
        ### Description --------------------------------------------------------
        
        if [[ "${printer_description}" != "${PRINTER_DESCRIPTIONS["${printer}"]}" ]]
        then
            /usr/sbin/lpadmin -p "$printer" -D "${PRINTER_DESCRIPTIONS["${printer}"]}" && \
            echo "Updated '${printer}' description '${printer_description}' -> '${PRINTER_DESCRIPTIONS["${printer}"]}'"
        fi
        
        ### Location -----------------------------------------------------------
        
        if [[ "${printer_location}" != "${PRINTER_LOCATIONS["${printer}"]}" ]]
        then
            /usr/sbin/lpadmin -p "$printer" -L "${PRINTER_LOCATIONS["${printer}"]}" && \
            echo "Updated '${printer}' location '${printer_location}' -> '${PRINTER_LOCATIONS["${printer}"]}'"
        fi
        
        ### URI ----------------------------------------------------------------
        
        if [[ "${printer_uri}" != "${PRINTER_URI["${printer}"]}" ]]
        then
            /usr/sbin/lpadmin -p "$printer" -v "${PRINTER_URI["${printer}"]}" && \
            echo "Updated '${printer}' URI '${printer_uri}' -> '${PRINTER_URI["${printer}"]}'"
        fi
        
        ### Driver/model -------------------------------------------------------
        
        if [[ "${printer_model}" != "${PRINTER_MODEL["${printer}"]}" ]]
        then
            /usr/sbin/lpadmin -p "$printer" -m "${PRINTER_DRIVER["${printer}"]}" && \
            echo "Updated '${printer}' model '${printer_model}' -> '${PRINTER_MODEL["${printer}"]}'"
        fi
    fi
done

#### Add new printers ==========================================================

for printer in "${PRINTERS[@]}"
do
    if ! contains "$printer" "${printers[@]}"
    then
        /usr/sbin/lpadmin -p 'Kyocera_Dev' -E              \
                -D "${PRINTER_DESCRIPTIONS["${printer}"]}" \
                -L "${PRINTER_LOCATIONS["${printer}"]}"    \
                -v "${PRINTER_URI["${printer}"]}"          \
                -m "${PRINTER_DRIVER["${printer}"]}"       \
                -o printer-is-shared=false              && \
        echo "Added '${printer}'"
    fi
done

