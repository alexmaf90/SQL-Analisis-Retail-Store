# SQL - Análisis de Datos para una Tienda Distribuidora de Equipamiento de Montaña y Aventura

## Descripción
Este proyecto consiste en el análisis de datos de una tienda distribuidora de equipamiento de montaña y aventura, que incluye ropa y accesorios de aventura. El análisis se enfoca en los principales ejes del negocio: ventas, clientes (tiendas), productos y canales.

## Objetivos del Proyecto
- Identificar productos de alto margen y aquellos que están en tendencia.
- Optimizar la gestión de clientes mediante segmentación y análisis de potencial de desarrollo.
- Analizar la evolución de la facturación y la contribución de diferentes canales y productos.
- Análisis de los ingresos y gastos
- Implementar un sistema de recomendación de productos.

## Herramientas y Tecnologías
El análisis se ha realizado utilizando SQL para la manipulación y análisis de datos y Power BI para la creación de los gráficos. 

## Metodología
El análisis se realizó a través de varias etapas, que incluyen la revisión y limpieza de datos, la creación de tablas agregadas, y el análisis detallado de los pedidos, productos y clientes.

### Punto de partida
- La tabla de ventas contiene 149,257 registros.
- Revisión de los registros duplicados en la tabla de ventas por combinación de tienda, producto, canal y fecha.
- A partir de la tabla ventas, se crea la tabla ventas agregadas, agrupando por fecha, id_producto, id_tienda, y id_canal. Se incluye en esta tabla la facturación como multiplicación de la cantidad por el precio de oferta. La tabla ventas agregadas tiene un total de 134.688 registros. Con esta tabla realizamos gran parte del análisis. 

![Tabla_ventas_agr](Tabla_ventas_agr.png)
