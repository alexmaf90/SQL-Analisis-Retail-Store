-- Este script SQL forma parte del proyecto [nombre del proyecto].
-- El objetivo es realizar análisis de datos sobre las ventas de la empresa y generar insights útiles para la empresa.

-- Activar la base de datos como la base de datos por defecto para trabajar.
USE caso;


-- Consulta inicial para revisar el contenido de las 4 tablas principales.
SELECT * FROM canales;
SELECT * FROM productos;
SELECT distinct producto, color FROM productos ORDER BY producto;
SELECT * FROM tiendas;
SELECT * FROM ventas;

-- Cuántos registros tiene la tabla 'ventas'.
SELECT COUNT(*) AS total_ventas FROM ventas;

-- Revisar el tipo de los datos en la columna 'fecha' de la tabla 'ventas'.
-- Observamos que la fecha está almacenada como texto, consideraremos convertirla a tipo date.

-- Identificar y contar registros duplicados en la tabla 'ventas' por combinación de tienda, producto, canal y fecha.
SELECT COUNT(*) AS conteo
FROM ventas
GROUP BY id_tienda, id_prod, id_canal, fecha
HAVING conteo > 1;
-- La presencia de duplicados indica la necesidad de una revisión y acción posterior.

-- Mostrar los registros duplicados para análisis detallado.
SELECT id_tienda, id_prod, id_canal, fecha, COUNT(*) AS conteo
FROM ventas
GROUP BY id_tienda, id_prod, id_canal, fecha
HAVING conteo > 1
ORDER BY id_tienda, id_prod, id_canal, fecha;

-- Ejemplos específicos de registros duplicados para mayor entendimiento.
SELECT * FROM ventas
WHERE id_tienda = 1115 
AND id_prod = 127110
AND id_canal = 5
AND fecha = '22/12/2016';

SELECT * FROM ventas
WHERE id_tienda = 1133 
AND id_prod = 152110
AND id_canal = 5
AND fecha = '14/04/2017';

-- Creación de una nueva tabla 'ventas_agr' para agregar datos a un nivel específico y mejorar la estructura:
-- - Cambio del tipo de dato de la columna 'fecha' a tipo date 
-- - Agregación de datos como suma de cantidad, promedio de precios oficiales y oferta, y cálculo de facturación.
CREATE TABLE ventas_agr AS 
SELECT str_to_date(fecha,'%d/%m/%Y') AS fecha, id_prod, id_tienda, id_canal, 
       SUM(cantidad) AS cantidad, AVG(precio_oficial) AS precio_oficial, AVG(precio_oferta) AS precio_oferta, 
       ROUND(SUM(cantidad) * AVG(precio_oferta), 2) AS facturacion
FROM ventas
GROUP BY fecha, id_prod, id_tienda, id_canal;

-- Verificación de la nueva tabla 'ventas_agr' creada.
SELECT * FROM ventas_agr;

-- Contar el número de registros en la nueva tabla 'ventas_agr'.
SELECT COUNT(*) AS total_registros FROM ventas_agr;


-- Mejora de la tabla 'ventas_agr' para incluir claves foráneas (FK) adecuadas y un campo clave incremental 'id_venta'.
ALTER TABLE ventas_agr 
ADD COLUMN id_venta INT PRIMARY KEY AUTO_INCREMENT, 
ADD CONSTRAINT fk_producto FOREIGN KEY (id_prod) REFERENCES productos (id_prod) ON DELETE CASCADE, 
ADD CONSTRAINT fk_tienda FOREIGN KEY (id_tienda) REFERENCES tiendas (id_tienda) ON DELETE CASCADE, 
ADD CONSTRAINT fk_canal FOREIGN KEY (id_canal) REFERENCES canales (id_canal) ON DELETE CASCADE;

-- Crear una vista 'v_ventas_agr_pedido' que incluya la noción de pedido basada en fecha, tienda y canal.
-- Consideramos que un pedido es el mismo si ocurre en la misma fecha, en la misma tienda y a través del mismo canal.

CREATE VIEW v_ventas_agr_pedido AS
WITH maestro_pedidos AS (
    SELECT fecha, id_tienda, id_canal, ROW_NUMBER() OVER() AS id_pedido
    FROM ventas_agr
    GROUP BY fecha, id_tienda, id_canal
)
SELECT v.id_venta, m.id_pedido, v.fecha, v.id_prod, v.id_tienda, v.id_canal, v.cantidad, v.precio_oficial, v.precio_oferta, v.facturacion
FROM ventas_agr v
LEFT JOIN maestro_pedidos m ON v.fecha = m.fecha AND v.id_tienda = m.id_tienda AND v.id_canal = m.id_canal;

-- Consulta de ejemplo sobre la vista 'v_ventas_agr_pedido'.
SELECT * FROM v_ventas_agr_pedido;

------------------------------------------------

-- ¿Cuántos pedidos diferentes tenemos en nuestro histórico?
SELECT COUNT(DISTINCT id_pedido) AS numero_pedidos FROM v_ventas_agr_pedido;

-- ¿Desde qué fecha a qué fecha tenemos datos en la tabla 'ventas_agr'?
SELECT MIN(fecha) AS primer_dia, MAX(fecha) AS ultimo_dia FROM ventas_agr;

-- ¿Cuántos productos distintos tenemos en nuestro catálogo?
SELECT COUNT(DISTINCT id_prod) AS numero_productos_distintos FROM productos;

-- ¿A cuántas tiendas distintas distribuimos nuestros productos?
SELECT COUNT(DISTINCT id_tienda) AS numero_tiendas_distintas FROM tiendas;

-- ¿A través de qué canales pueden realizarse pedidos según los registros de 'ventas_agr'?
SELECT DISTINCT c.id_canal, c.canal
FROM ventas_agr v
INNER JOIN canales c ON v.id_canal = c.id_canal;



-- Cuáles son los 3 canales en los que más facturamos

SELECT c.canal, ROUND(SUM(v.facturacion), 2) AS facturacion_canal
FROM ventas_agr v
INNER JOIN canales c ON v.id_canal = c.id_canal
GROUP BY c.canal
ORDER BY facturacion_canal DESC
LIMIT 3;

-- Cuál ha sido la evolución mensual de la facturación por canal en los últimos 12 meses completos

SELECT c.canal, MONTH(fecha) AS mes, ROUND(SUM(v.facturacion), 2) AS facturacion_mensual
FROM ventas_agr v
INNER JOIN canales c ON v.id_canal = c.id_canal
WHERE fecha BETWEEN '2017-07-01' AND '2018-06-30'
GROUP BY v.id_canal, mes
ORDER BY v.id_canal, mes;


-- 50 mejores clientes (tiendas con mayor facturación)

SELECT t.nombre_tienda, ROUND(SUM(v.facturacion), 2) AS total_facturacion
FROM ventas_agr v
INNER JOIN tiendas t ON v.id_tienda = t.id_tienda
GROUP BY v.id_tienda
ORDER BY total_facturacion DESC
LIMIT 50;

-- Analiza la evolución de la facturación de cada país por trimestre desde 2017

SELECT t.pais, YEAR(fecha) AS año, QUARTER(fecha) AS trimestre, ROUND(SUM(v.facturacion), 2) AS facturacion_trimestre
FROM ventas_agr v
INNER JOIN tiendas t ON v.id_tienda = t.id_tienda
WHERE fecha BETWEEN '2017-01-01' AND '2018-06-30'
GROUP BY t.pais, año, trimestre
ORDER BY t.pais, año, trimestre;


-- Los 20 productos en los que se obtiene mayor margen ((precio - coste) / coste * 100) en cada línea

WITH tabla_margen AS (
    SELECT id_prod, linea, producto, ROUND(((precio - coste) / coste * 100), 2) AS margen,
           ROW_NUMBER() OVER(PARTITION BY linea ORDER BY ((precio - coste) / coste * 100) DESC) AS Ranking
    FROM productos
)
SELECT *
FROM tabla_margen
WHERE Ranking <= 20;

-- Encuentra aquellos productos (su identificador) en los que se están haciendo descuentos (en porcentaje) superiores al valor de descuento que deja por debajo al 90% de los descuentos

WITH tabla_descuentos AS (
    SELECT id_prod, ROUND(((precio_oficial_medio - precio_oferta_medio) / precio_oficial_medio) * 100, 2) AS descuento_pct
    FROM (
        SELECT id_prod, AVG(precio_oficial) AS precio_oficial_medio, AVG(precio_oferta) AS precio_oferta_medio
        FROM ventas_agr
        GROUP BY id_prod
    ) AS nivel_producto
)
SELECT *
FROM (
    SELECT id_prod, descuento_pct, CUME_DIST() OVER(ORDER BY descuento_pct) AS distrib_acum
    FROM tabla_descuentos
) AS acumulados
WHERE distrib_acum >= 0.9;





-- ¿Cuántos productos diferentes estamos vendiendo?
SELECT COUNT(DISTINCT producto) AS productos_distintos FROM productos;

-- ¿Con qué productos necesitaríamos quedarnos para mantener el 90% de la facturación actual?

USE caso;
WITH tabla_facturacion_productos_porcentaje AS (
	WITH tabla_facturacion AS (
	SELECT id_prod,
		   facturacion_producto,
		   round(sum(facturacion_producto) OVER(ORDER BY facturacion_producto DESC),2) AS facturacion_acum,
		   round(sum(facturacion_producto) OVER(),2) AS facturacion_prod_total
	FROM (SELECT id_prod, round(SUM(facturacion),2) AS facturacion_producto
		  FROM ventas_agr
		  GROUP BY id_prod
		  ORDER BY facturacion_producto DESC) AS tabla_facturacion_prod)
		  SELECT *, 
				 round((facturacion_acum/facturacion_prod_total),3) AS fact_prod_acum_pct
		  FROM tabla_facturacion )
SELECT * FROM tabla_facturacion_productos_porcentaje
WHERE fact_prod_acum_pct <= 0.9;

-- Y por tanto ¿qué productos concretos podríamos eliminar y seguir manteniendo el 90% de la facturación?
USE caso;
WITH productos_a_mantener AS (
	WITH tabla_facturacion_productos_porcentaje AS (
		WITH tabla_facturacion AS (
		SELECT id_prod,
			   facturacion_producto,
			   round(sum(facturacion_producto) OVER(ORDER BY facturacion_producto DESC),2) AS facturacion_acum,
			   round(sum(facturacion_producto) OVER(),2) AS facturacion_prod_total
		FROM (SELECT id_prod, round(SUM(facturacion),2) AS facturacion_producto
			  FROM ventas_agr
			  GROUP BY id_prod
			  ORDER BY facturacion_producto DESC) AS tabla_facturacion_prod)
			  SELECT *, 
					 round((facturacion_acum/facturacion_prod_total),3) AS fact_prod_acum_pct
			  FROM tabla_facturacion )
	SELECT * FROM tabla_facturacion_productos_porcentaje
	WHERE fact_prod_acum_pct <= 0.9
    )
    SELECT distinct v.id_prod
    FROM ventas_agr v 
    LEFT JOIN productos_a_mantener m 
    ON v.id_prod = m.id_prod
    WHERE m.id_prod IS NULL;

---------------------------------------------

-- ¿Qué líneas de producto diferentes estamos vendiendo?
SELECT DISTINCT linea FROM productos;

-- ¿Cuál es la contribución (en porcentaje) de cada línea al total de facturación?

WITH tabla_linea_prod_facturacion AS (
    WITH tabla_linea_prod AS (
        SELECT p.linea, ROUND(SUM(v.facturacion), 2) AS facturacion_linea_prod
        FROM ventas_agr v
        INNER JOIN productos p ON v.id_prod = p.id_prod
        GROUP BY p.linea
    )
    SELECT *,
           ROUND(SUM(facturacion_linea_prod) OVER(), 2) AS facturacion_total
    FROM tabla_linea_prod
)
SELECT linea, facturacion_linea_prod, 
       ROUND((facturacion_linea_prod / facturacion_total) * 100, 2) AS pct_facturacion_linea
FROM tabla_linea_prod_facturacion
ORDER BY pct_facturacion_linea DESC;

-- ¿Podríamos prescindir de alguna línea de productos sin que afecte mucho a la facturación?
# Sí, la línea de 'Outdoor Protection' supone un 1.41% de la facturación total.

-- Dentro de la línea que más factura, ¿hay algún producto concreto que esté en tendencia?
-- Definimos tendencia como el crecimiento de Q2-2018 sobre Q1-2018.

WITH facturacion_prod_trim AS (
	SELECT linea, producto, quarter(fecha) as trimestre,round(sum(facturacion),2) as facturacion_prod_trim
	FROM ventas_agr v
	INNER JOIN productos p
	ON v.id_prod = p.id_prod
	WHERE linea = 'Personal Accessories'AND fecha BETWEEN "2018/-01-01" AND "2018-06-30"
	GROUP BY 2,3
	ORDER BY 2,3
    )
    SELECT *
    FROM (SELECT producto,
		   round(facturacion_prod_trim / LAG(facturacion_prod_trim)  OVER(PARTITION BY producto),2) AS crecimiento_pct_trimestre
    FROM facturacion_prod_trim) AS subconsulta
    WHERE crecimiento_pct_trimestre IS NOT NULL
    ORDER BY crecimiento_pct_trimestre DESC;



---------------------------------------------
-- Segmentación de clientes: 
-- Se crea una matriz de segmentación de clientes basada en el número de pedidos y la facturación de cada tienda. 
-- Esta matriz se divide en 4 segmentos, considerando si cada métrica está por encima o por debajo de la media correspondiente.

USE caso;

CREATE VIEW v_matriz_segmentacion_clientes AS (
    WITH tabla_facturacion_tienda AS (
        SELECT id_tienda, count(id_pedido) as num_pedidos, round(sum(facturacion), 2) as facturacion_tienda
        FROM v_ventas_agr_pedido
        GROUP BY id_tienda
        ORDER BY facturacion_tienda DESC
    ),
    tabla_medias AS (
        SELECT round(avg(num_pedidos), 2) AS media_num_pedidos, round(avg(facturacion_tienda), 2) AS media_facturacion
        FROM tabla_facturacion_tienda
    )
    SELECT *,
           CASE WHEN num_pedidos <= media_num_pedidos AND facturacion_tienda <= media_facturacion THEN "P- F-"
                WHEN num_pedidos <= media_num_pedidos AND facturacion_tienda > media_facturacion THEN "P- F+"
                WHEN num_pedidos > media_num_pedidos AND facturacion_tienda <= media_facturacion THEN "P+ F-"
                WHEN num_pedidos > media_num_pedidos AND facturacion_tienda > media_facturacion THEN "P+ F+"
                ELSE "ERROR"
           END as segmentacion_clientes
    FROM tabla_facturacion_tienda, tabla_medias
);
SELECT * FROM v_matriz_segmentacion_clientes;

-- Cuántos clientes hay en cada segmento de la matriz

SELECT segmentacion_clientes, count(*) AS clientes_segmento
FROM v_matriz_segmentacion_clientes
GROUP BY segmentacion_clientes
ORDER BY clientes_segmento DESC;

-- Potencial de desarrollo:
-- Se calcula el potencial de desarrollo de las tiendas segmentadas por tipo, basándose en el percentil 75 de la facturación. 
-- Este análisis identifica las tiendas que están por debajo del percentil 75 y calcula cuánto podrían aumentar su facturación para alcanzar dicho percentil.
    
-- Cálculo del potencial de desarrollo por tipo de tienda

WITH facturacion_tipo_tienda AS (
    SELECT v.id_tienda, tipo, round(sum(facturacion), 2) as facturacion_tiendas
    FROM ventas_agr v
    LEFT JOIN tiendas t ON v.id_tienda = t.id_tienda
    GROUP BY v.id_tienda, tipo
),
p75_tiendas AS (
    SELECT tipo, facturacion_tiendas AS facturacion_objetivo 
    FROM (
        SELECT *, row_number() OVER(PARTITION BY tipo ORDER BY percentil) AS ranking
        FROM (
            SELECT *, round(percent_rank() OVER(PARTITION BY tipo ORDER BY facturacion_tiendas) * 100, 2) AS percentil
            FROM facturacion_tipo_tienda
        ) AS percentil_tienda
        WHERE percentil >= 75
    ) AS ranking
    WHERE ranking = 1
)
SELECT id_tienda, t.tipo, facturacion_tiendas, facturacion_objetivo,
       CASE 
           WHEN facturacion_tiendas >= facturacion_objetivo THEN 0
           WHEN facturacion_tiendas < facturacion_objetivo THEN round((facturacion_objetivo - facturacion_tiendas), 2)
           ELSE -99999999
       END AS potencial_tienda
FROM facturacion_tipo_tienda t
INNER JOIN p75_tiendas p ON t.tipo = p.tipo
ORDER BY potencial_tienda DESC;

-- Reactivación de clientes
-- Se identifican las tiendas que tienen más de 3 meses sin realizar compras, utilizando la fecha más reciente de ventas disponible. 
-- Esto ayuda a identificar oportunidades de reactivación de clientes inactivos.

USE caso;
-- Identificación de tiendas con más de 3 meses sin compras
USE caso;
WITH ultima_fecha AS (
		SELECT max(fecha) AS ultima_fecha_total
		FROM ventas_agr),
	 ultima_fecha_tienda AS 
		(SELECT id_tienda, max(fecha) AS ultima_fecha_tienda
		FROM ventas_agr
		GROUP BY id_tienda)
SELECT *
FROM (SELECT *, datediff(ultima_fecha_total,ultima_fecha_tienda) dias_sin_comprar
	  FROM ultima_fecha_tienda, ultima_fecha) AS tabla_fechas
WHERE dias_sin_comprar >=90
ORDER BY dias_sin_comprar DESC;

# 15 tiendas no han realizado compras en los ultimos 3 meses 



---------------------------------------------
-- Sistemas de Recomendacion: 
-- Generar un sistema de recomendación item-item que localice aquellos productos que son comprados frecuentemente en el mismo pedido y 
-- recomiende a cada tienda según su propio historial de productos comprados. 

-- Pasos a seguir:
-- Crear una tabla con el maestro de recomendaciones item-item

# A nivel cliente quitamos problemas de tendencias o estacionalidad

SELECT *
FROM v_ventas_agr_pedido AS v1
INNER JOIN v_ventas_agr_pedido v2
ON v1.id_pedido = v2.id_pedido LIMIT 15; #Comprobacion de como queda al unir la tabla consigo misma. 

CREATE TABLE recomendador
SELECT v1.id_prod AS prod_antecedente, v2.id_prod AS consecuente, count(v1.id_pedido) AS frecuencia_compra
FROM v_ventas_agr_pedido AS v1
INNER JOIN v_ventas_agr_pedido v2
ON v1.id_pedido = v2.id_pedido #Identifica productos que se compran en el mismo pedido
AND v1.id_prod != v2.id_prod # Quitamos los registros de cada producto consigo mismo (producto 1 con producto 1)
AND v1.id_prod < v2.id_prod # Evitamos la matriz simetrica (si el prod 1 esta relacionado con el 2, es lo mismo decir que el 2 esta relacionado con el 1, quitamos duplicados)
GROUP BY v1.id_prod, v2.id_prod;

Select * FROM recomendador
ORDER BY prod_antecedente, frecuencia_compra DESC;

#A nivel pedido: Que productos han comprado otros clientes en el mismo pedido(sino productos que se compraron hace 3 años en el mismo pedido pueden no tener relevancia ahora)

-- Consulta que genere las recomendaciones para cada cliente concreto
-- que sea capaz de eliminar los productos ya comprados por ese cliente concreto
USE caso;
WITH input_cliente AS (
	SELECT id_tienda, id_prod
	FROM ventas_agr a
	WHERE id_tienda = "1201")
SELECT * 
FROM input_cliente i
LEFT JOIN recomendador r 
ON i.id_prod = r.prod_antecedente;

SELECT * FROM recomendador;
