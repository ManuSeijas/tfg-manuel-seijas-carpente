import os
import pandas as pd
import numpy as np

def process_household_type(household_type, household_type_2):
    """
    Se encarga de asignar los nuevos valores a la variable
    demográfica "type of household" o "tipo de hogar"
    """
    household_type_values = household_type.values
    household_type_2_values = household_type_2.values

    for index in range(len(household_type_values)):
        if household_type_values[index] == 'Pareja con hijos':
            if household_type_2_values[index] != '-':
                household_type_values[index] = 'Pareja con hijos menores'
        elif not household_type_values[index] == 'Hogar unipersonal':
            household_type_values[index] = 'Otro tipo de hogar'

    return household_type

def process_housing_type(housing_type, housing_type_2):
    """
    Se encarga de asignar los nuevos valores a la variable
    demográfica "type of housing" o "tipo de vivienda"
    """
    housing_type_values = housing_type.values
    housing_type_2_values = housing_type_2.values

    for index in range(len(housing_type_values)):
        if housing_type_values[index] == 'Casa con jardín' or housing_type_values[index] == 'Otro':
            if housing_type_2_values[index] >= 80:
                housing_type_values[index] = 'Vivienda con jardín +80m2'
            else:
                housing_type_values[index] = 'Vivienda con jardín -80m2'
        else:
            if housing_type_2_values[index] >= 80:
                housing_type_values[index] = 'Vivienda sin jardín +80m2'
            else:
                housing_type_values[index] = 'Vivienda sin jardín -80m2'

    return housing_type

def process_work_state(work_state):
    """
    Se encarga de asignar los nuevos valores a la variable
    demográfica "work state" o "estado laboral"
    """
    work_state_values = work_state.values

    for index in range(len(work_state_values)):
        if work_state_values[index] == 'Labores de hogar' \
            or work_state_values[index] == 'Desempleado ERE' \
            or work_state_values[index] == 'Desempleado larga duración (más de 9 meses)' \
            or work_state_values[index] == 'Demandante de empleo':
                work_state_values[index] = 'Desempleado'
        elif work_state_values[index] == 'Jubilado o pensionista' \
            or work_state_values[index] == 'Empleado en ERTE' \
            or work_state_values[index] == 'Otro':
                work_state_values[index] = 'Inactivo'
        else:
            work_state_values[index] = 'Activo'

    return work_state

def process_variables_51(data):
    """
    Función para normalizar el rango de valores del cuestionario.
    En este caso, el 1 del cuestionario será equivalente al -1 en csv, y el 5 del 
    cuestionario será equivalente al 1 del csv. El resto de valores se ajustan en este rango.
    """
    data_values = data.astype(np.float).values
    values_list = []

    for index in range(len(data_values)):
        if (data_values[index] == 1):
            values_list.append(-1)
        elif (data_values[index] == 2):
            values_list.append(-0.5)
        elif (data_values[index] == 3):
            values_list.append(0)
        elif (data_values[index] == 4):
            values_list.append(0.5)
        elif (data_values[index] == 5):
            values_list.append(1)

    return pd.Series(values_list)

def process_variables_15(data):
    """
    Función para normalizar el rango de valores del cuestionario en orden inverso.
    En este caso, el 1 del cuestionario será equivalente al 1 en csv, y el 5 del 
    cuestionario será equivalente al -1 del csv. El resto de valores se ajustan en este rango.
    """
    data_values = data.astype(np.float).values
    values_list = []

    for index in range(len(data_values)):
        if (data_values[index] == 5):
            values_list.append(-1)
        elif (data_values[index] == 4):
            values_list.append(-0.5)
        elif (data_values[index] == 3):
            values_list.append(0)
        elif (data_values[index] == 2):
            values_list.append(0.5)
        elif (data_values[index] == 1):
            values_list.append(1)

    return pd.Series(values_list)

if __name__ == "__main__":
    # carga de la base de datos en excel
    data = pd.read_excel(
        'formOblig.xlsx',
        engine = 'openpyxl',
    )

    # generación del diccionario con los datos procesadosGeneration of the dictionary with the processed data
    data_dictionary = {
        # variables referentes a la demografía
        'Género': data['Género'],
        'Edad': data['Edad'],
        'Tipo_Hogar': process_household_type(
            data['Tipo_Hogar'],
            data['Tipo_Hogar_2']
        ),
        'Tipo_Vivienda': process_housing_type(
            data['Tipo_Vivienda'],
            data['Tipo_Vivienda_3']
        ),
        
        'Estado_Laboral': process_work_state(
            data['Estado_Laboral']
        ),
        'Trabajo_Esencial': data['Trabajo_Esencial'],
        'Ingreso_Neto_Mensual': data['Ingreso_Neto_Mensual'],

        # variables referentes a la satisfacción experiencial
        'Dificultad_Confinamiento_Completo': process_variables_15(data['Dificultad_Confinamiento_Completo ']),
        'Dificultad_Salir_Trabajar': process_variables_15(data['Dificultad_Salir_Trabajar']),
        'Dificultad_Trabajar_Casa': process_variables_15(data['Dificultad_Trabajar_Casa']),
        'Dificultad_Sin_Trabajar': process_variables_15(data['Dificultad_Sin_Trabajar']),
        'Dificultad_Ocio': process_variables_15(data['Dificultad_Ocio']),
        'Dificultad_Espacios_Cerrados': process_variables_15(data['Dificultad_Espacios_Cerrados']),
        'Dificultad_Controles_Temperatura': process_variables_15(data['Dificultad_Controles_Temperatura']),
        'Dificultad_Equipos_Protección': process_variables_15(data['Dificultad_Equipos_Proteccion']),

        # variables referentes a la satisfacción de relación social
        'Dificultad_Desplazamiento': process_variables_15(data['Dificultad_Desplazamiento']),
        'Dificultad_Amigos': process_variables_15(data['Dificultad_Amigos']),
        'Dificultad_Aislamiento': process_variables_15(data['Dificultad_Aislamiento']),
        'Dificultad_Distancia_Social': process_variables_15(data['Dificultad_Distancia_Social']),

        # variables referentes a la satisfacción de valores
        'Acuerdo_Cumplimiento_Medidas': process_variables_51(data['Acuerdo_Cumplimiento_Medidas']),

        # variables referentes a la importancia de los valores
        'Acuerdo_Deber_Civico': process_variables_51(data['Acuerdo_Deber_Civico']),
        'Acuerdo_Respestar_Medidas': process_variables_51(data['Acuerdo_Respestar_Medidas']),

        # variables referentes a la importancia de la necesidad experiencial
        'Acuerdo_Proteccion': process_variables_51(data['Acuerdo_Proteccion']),

        # variables referentes a la importancia de la necesidad social
        'Acuerdo_Presion_Social': process_variables_51(data['Acuerdo_Presion_Social']),
    }

    # crea un dataframe a partir del diccionario
    processed_data = pd.DataFrame(data_dictionary)

    # crea la nueva base de datos a partir del dataframe (se pasa a csv por necesidad del proyecto)
    processed_data.to_csv('data.csv', header=False)