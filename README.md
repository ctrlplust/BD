# Proyecto Banco Futura - Base de Datos (PostgreSQL + Docker)

##  Descripción General

Proyecto de base de datos relacional implementado en **PostgreSQL**, normalizado hasta **3FN** y desplegado mediante **Docker Compose**.  
El sistema modela la gestión de **sucursales, ejecutivos, clientes, productos, ventas y metas de cumplimiento**, integrando **lógica de negocios directamente en la base de datos** mediante:

- **Stored Procedures (SP)**
- **Triggers**
- **Funciones auxiliares**
- **Vistas con cálculo automático de avance**

##  Descripción General

Proyecto de base de datos relacional implementado en **PostgreSQL**, normalizado hasta **3FN** y desplegado mediante **Docker Compose**.

El sistema modela la gestión integral de **regiones, sucursales, gerentes, ejecutivos, clientes, productos, canales, ventas y metas de cumplimiento**, integrando **lógica de negocio directamente en la base de datos** mediante:

-  **Stored Procedures (SP)**
-  **Triggers**
-  **Funciones auxiliares**
-  **Vistas con cálculo automático de avance**

Todo corre dentro de un contenedor Docker (`camiones_db`) y puede poblarse automáticamente desde archivos **Excel / Google Sheets exportados como CSV**.

---

## ⚙️ Estructura del Proyecto

| Archivo | Descripción |
|----------|-------------|
| `init_camiones.sql` | Crea todas las tablas, claves primarias y foráneas, restricciones e índices. |
| `init_banco.sql` | Inserta datos base: regiones, sucursales, ejecutivos, clientes, productos, canales y metas iniciales. |
| `logica_camiones.sql` | Implementa funciones, triggers, stored procedures y vistas para la lógica de negocio. |
| `import_data.sql` | Carga masiva de datos desde archivos CSV montados en `/data`. |
| `sigcob_datos.xlsx` | Planilla maestra (editable en Excel o Google Sheets) para poblar todas las entidades. |
| `.env` | Variables de entorno utilizadas por Docker. |
| `docker-compose.yml` | Define los servicios de Postgres y pgAdmin. |
| `test_logic.sql` | Pruebas automáticas para verificar la lógica y validaciones. |

---

## 🧩 Variables de Entorno

Crea el archivo `.env` en la raíz del proyecto con el siguiente contenido:

```bash
cat > .env << EOF
# Postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=1234
POSTGRES_DB=camiones
POSTGRES_PORT=5432

# pgAdmin (opcional)
PGADMIN_EMAIL=admin@localhost.com
PGADMIN_PASSWORD=admin123
PGADMIN_PORT=5050
```

## Requisitos

- [Docker](https://www.docker.com)
- [Docker-compose](https://docs.docker.com/compose/)

## Ejecutar Proyecto

```bash
docker compose up -d
```
Este levantara:
  -PostgreSQL
  -pgAdmin

## Cargar los scripts SQL(Estructura)

```bash
# Crear estructura de tablas
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/init_camiones.sql

# Insertar datos iniciales (Banco Futura)
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/init_banco.sql

# Cargar lógica de negocio (SP, triggers y vistas)
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/logica_camiones.sql
```

## Poblar la base
desde CSV:

```bash
# Copiar carpeta data al contenedor
docker cp ./data camiones_db:/data

# Ejecutar script de importación
docker exec -it camiones_db psql -U postgres -d camiones -f /data/import_data.sql
```

Verificacion:
```bash
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM region;"
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM canal;"
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM producto;"
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM venta;"
```

## Que se encontrara al ejecutar
Creación automática de todas las tablas del modelo:
region, sucursal, ejecutivo, cliente, producto, venta, meta, canal, etc.

Relaciones activas y claves foráneas correctamente aplicadas.

Triggers y stored procedures funcionando para validar metas y ventas.

Vista vw_metas_con_avance que muestra el progreso de cumplimiento.

Carga masiva funcional con datos desde archivos CSV en /data.

Ejecución 100 % reproducible dentro de contenedores Docker.
