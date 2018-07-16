Herramientas cuantitativas para la optimización de la política de precios
==========================================================================
El objetivo de este notebook es emplear SAS para llevar a cabo un análisis cuantitativo de la política de precios, explorar las opciones de modelado predictivo y aplicar a la optimización del precio el popular algoritmo de Gradient Descent implementado en el lenguaje matricial SAS IML.

El lector encontrará las siguientes partes:

1. Introducción: Presentación de los datos, motivación y primeros conceptos clave del análisis y del desarrollo.
2. Análisis Exploratorio de Datos: Empleo de las herramientas de visualización del lenguaje SAS para dar forma a los modelos predictivos.
3. Construcción del modelo lineal y determinación del precio P mediante Gradient Descent: Esta es la parte más cuantitaviva del notebook, en la que aborda el ajuste del modelos lineales y en base al modelo elegido se aplica el algoritmo de optimización para hallar el precio óptimo P que maximiza los ingresos.
4.  Análisis de los resultados: Discusión sobre la solución hallada y contextualización de la misma.
5. Comentarios finales: Ideas sobre la base matemática, estadística y capacidad de generalizar el planteamiento.
6. Addemdum: Selección de parámetros del algoritmo Gradient Descent y análisis de convergencia

Se a acompañado el código SAS con visualización de resultados y el desarrollo matemático asociado. 

Prerrequisitos:
--------------
Instalación de SAS University Edition:
https://www.sas.com/en_us/software/university-edition/download-software.html

Puesta en marcha:
------------------
Copiar el notebook y la tabla sas inputData.sas7bdat en la misma carpeta, ya que la sentencia de declaración de librería tiene una ruta relativa.

> libname lab ".";

También se adjutan los datos en .csv
