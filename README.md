# Proyecto Banco Futura - Base de Datos (PostgreSQL + Docker)

## 📝 Descripción General

Proyecto de base de datos relacional implementado en **PostgreSQL**, normalizado hasta **3FN** y desplegado mediante **Docker Compose**.

El sistema modela la gestión integral de:
- Regiones y Sucursales
- Gerentes y Ejecutivos
- Clientes y Productos
- Canales de Venta
- Ventas y Metas de Cumplimiento

La lógica de negocio está implementada directamente en la base de datos mediante:
- **Stored Procedures (SP)**
- **Triggers**
- **Funciones auxiliares**
- **Vistas con cálculo automático de avance**

Todo corre dentro de un contenedor Docker (`camiones_db`) y puede poblarse automáticamente desde archivos **CSV**.

---

## ⚙️ Estructura del Proyecto

| Archivo | Descripción |
|----------|-------------|
| `init_camiones.sql` | Crea tablas, claves, restricciones e índices |
| `init_banco.sql` | Datos base: regiones, sucursales, ejecutivos, etc. |
| `logica_camiones.sql` | Funciones, triggers, SP y vistas |
| `import_data.sql` | Carga masiva desde CSV en `/data` |
| `docker-compose.yml` | Servicios de Postgres y pgAdmin |
| `test_logic.sql` | Pruebas de lógica y validaciones |

## 🚀 Requisitos

- [Docker](https://www.docker.com)
- [Docker-compose](https://docs.docker.com/compose/)

## 🔧 Configuración

### Variables de Entorno
Crear archivo `.env`:
```bash
<<<<<<< HEAD
cat > .env << EOF
# Postgres
=======
POSTGRES_PASSWORD=1234
>>>>>>> b150ab1 (feat: Actualización de README y validación de sistema completo)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=1234
POSTGRES_DB=camiones
POSTGRES_PORT=5432

# pgAdmin (opcional)
PGADMIN_EMAIL=admin@localhost.com
PGADMIN_PASSWORD=admin123
PGADMIN_PORT=5050
<<<<<<< HEAD
```

## Instalación y Ejecución

1. Levantar Servicios

```bash
docker compose up -d
```
2. Cargar Estructura
```bash
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/init_camiones.sql

# Datos iniciales
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/init_banco.sql

# Lógica de negocio
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/logica_camiones.sql
```

3. Poblar Base de Datos

```bash
# Copiar datos
docker cp ./data camiones_db:/data

# Importar
docker exec -it camiones_db psql -U postgres -d camiones -f /data/import_data.sql
```

## Pruebas y Validaciones

1. Pruebas de Restricciones

```bash
-- Prueba de fechas inválidas (debe fallar)
INSERT INTO meta (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, 
    peso_ponderado, id_ejecutivo, id_categoria)
VALUES ('2025-10-31', '2025-09-01', 10, 1000000.00, 60.00, 1, 1);

-- Prueba de monto negativo (debe fallar)
INSERT INTO venta (fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal)
VALUES ('2025-10-15', -150000.00, 1, 1, 1, 1);

-- Prueba de peso ponderado inválido (debe fallar)
INSERT INTO meta (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, 
    peso_ponderado, id_ejecutivo, id_categoria)
VALUES ('2025-09-01', '2025-10-31', 10, 1000000.00, 101.00, 1, 1);
```

2. Verificación de Metas
```bash
SELECT 
    m.id_meta,
    m.id_ejecutivo,
    m.periodo_inicio,
    m.periodo_fin,
    m.cantidad_meta,
    m.monto_meta,
    COUNT(v.id_venta) as ventas_cantidad,
    COALESCE(SUM(v.monto), 0) as ventas_monto,
    ROUND(COUNT(v.id_venta)::numeric / m.cantidad_meta, 4) as avance_cantidad_pct,
    ROUND(COALESCE(SUM(v.monto), 0) / m.monto_meta, 4) as avance_monto_pct
FROM meta m
LEFT JOIN venta v ON 
    v.id_ejecutivo = m.id_ejecutivo AND
    v.fecha BETWEEN m.periodo_inicio AND m.periodo_fin
GROUP BY m.id_meta;
```

3. Verificación de Integridad

```bash
-- Intentar eliminar ejecutivo con ventas
DELETE FROM ejecutivo WHERE id_ejecutivo = 1;

-- Intentar eliminar categoría con productos
DELETE FROM productocategoria WHERE id_categoria = 1;
```

## Funcionalidades Implementada
✓ Tablas normalizadas hasta 3FN
✓ Claves foráneas con integridad referencial
✓ Triggers para validación de metas y ventas
✓ Vista de avance de metas automática
✓ Importación masiva desde CSV
✓ Despliegue automatizado con Docker


## Que se encontrara al ejecutar
Creación automática de todas las tablas del modelo:
region, sucursal, ejecutivo, cliente, producto, venta, meta, canal, etc.

Relaciones activas y claves foráneas correctamente aplicadas.

Triggers y stored procedures funcionando para validar metas y ventas.

Vista vw_metas_con_avance que muestra el progreso de cumplimiento.

Carga masiva funcional con datos desde archivos CSV en /data.

Ejecución 100 % reproducible dentro de contenedores Docker.
