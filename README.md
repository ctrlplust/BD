# 🏦 Proyecto Banco Futura - Base de Datos (PostgreSQL + Docker)

**Autor:** Tomás Núñez Yañéz  
**Asignatura:** Base de Datos  
**Universidad Diego Portales**  
**Proyecto:** SIGCOB (Sistema Integral de Gestión y Control de Metas de Ejecutivos Comerciales)

---

<<<<<<< HEAD
## 📦 Descripción General

Proyecto de base de datos relacional implementado en **PostgreSQL**, normalizado hasta **3FN** y desplegado mediante **Docker Compose**.  
El sistema modela la gestión de **sucursales, ejecutivos, clientes, productos, ventas y metas de cumplimiento**, integrando **lógica de negocios directamente en la base de datos** mediante:

- **Stored Procedures (SP)**
- **Triggers**
- **Funciones auxiliares**
- **Vistas con cálculo automático de avance**
=======
## 📘 Descripción General

Proyecto de base de datos relacional implementado en **PostgreSQL**, normalizado hasta **3FN** y desplegado mediante **Docker Compose**.  

El sistema modela la gestión integral de **regiones, sucursales, gerentes, ejecutivos, clientes, productos, canales, ventas y metas de cumplimiento**, incorporando **lógica de negocio directamente en la base de datos** mediante:

- 🔹 **Stored Procedures (SP)**
- 🔹 **Triggers**
- 🔹 **Funciones auxiliares**
- 🔹 **Vistas de avance automático**

Todo corre dentro de un contenedor Docker (`camiones_db`) y puede poblarse automáticamente desde archivos **Excel / Google Sheets exportados como CSV**.
>>>>>>> 50191c5 (Update)

---

## ⚙️ Estructura del Proyecto

| Archivo | Descripción |
|----------|-------------|
<<<<<<< HEAD
| `init_camiones.sql` | Crea el esquema base: tablas, claves foráneas, índices y datos mínimos. |
| `init_banco.sql` | Inserta información adicional del contexto Banco Futura (sucursales, ejecutivos, metas, etc.). |
| `logica_camiones.sql` | Implementa toda la lógica de negocio en la BD: triggers, funciones, SP y vistas. |
| `test_logic.sql` | Ejecuta pruebas unitarias para verificar el correcto funcionamiento de la lógica. |
| `.env` | Variables de entorno necesarias para levantar la base en Docker. |
=======
| `init_camiones.sql` | Crea todas las tablas, claves primarias y foráneas, restricciones e índices. |
| `init_banco.sql` | Inserta datos base: regiones, sucursales, ejecutivos, clientes, productos, canales y metas iniciales. |
| `logica_camiones.sql` | Implementa funciones, triggers, stored procedures y vistas para la lógica de negocio. |
| `import_data.sql` | Carga masiva de datos desde archivos CSV montados en `/data`. |
| `sigcob_datos.xlsx` | Planilla maestra (editable en Excel o Google Sheets) para poblar todas las entidades. |
| `.env` | Variables de entorno utilizadas por Docker. |
| `docker-compose.yml` | Define los servicios de Postgres y pgAdmin. |
>>>>>>> 50191c5 (Update)

---

## 🧩 Variables de Entorno

<<<<<<< HEAD
Crea el archivo `.env` en la raíz del proyecto con el siguiente contenido:
=======
Crea el archivo `.env` en la raíz del proyecto con:
>>>>>>> 50191c5 (Update)

```bash
cat > .env << EOF
POSTGRES_PASSWORD=1234
POSTGRES_USER=postgres
POSTGRES_DB=camiones
POSTGRES_PORT=5432
PGADMIN_EMAIL=tu_email@ejemplo.com
PGADMIN_PASSWORD=1234
PGADMIN_PORT=5050
EOF
```
<<<<<<< HEAD

## Cómo Ejecutar el Proyecto?
# 1️⃣ Iniciar el entorno con Docker

``` bash
Asegúrate de tener Docker y Docker Compose instalados en tu equipo local
```
Esto levanta los servicios:

PostgreSQL → contenedor camiones_db

## Cargar los cripts SQL
Ejecuta los siguientes comandos en orden (asumiendo que estás dentro de ~/ProyectoBD/init):
=======
>>>>>>> 50191c5 (Update)

```bash
<<<<<<< HEAD
# Ejecutar script de creación de tablas
docker exec -i camiones_db psql -U postgres -d camiones < /workspaces/BD/init/init_camiones.sql

# Insertar datos adicionales del contexto Banco Futura
docker exec -i camiones_db psql -U postgres -d camiones < /workspaces/BD/init/init_banco.sql

# Cargar la lógica de negocio (SP, triggers y vistas)
docker exec -i camiones_db psql -U postgres -d camiones < /workspaces/BD/init/logica_camiones.sql
```

## Testear la lógica de negocio
Ejecuta las pruebas automáticas para verificar la integridad del modelo y el correcto funcionamiento de los triggers:
```bash
docker exec -i camiones_db psql -U postgres -d camiones < /workspaces/BD/init/test_logic.sql
```

Si esta bien compilado deberias ver esto:

```yaml
Meta solapada para ejecutivo 1 y categoría 1 en [2025-10-15 - 2025-11-15]
El cliente 2 está asignado al ejecutivo 1, no al 2
No hay meta vigente para ejecutivo 1 y categoría 1 en la fecha 2025-09-01
```

Y un cambio automático reflejado en la vista vw_metas_con_avance:
```cpp
Antes del delete → ventas_cantidad = 4, cumplimiento_ponderado = 0.3900  
Después del delete → ventas_cantidad = 3, cumplimiento_ponderado = 0.2850
=======
docker compose up -d
```

### Scripts

# Ejecutar script de creación de tablas - Estructura
```bash
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/init_camiones.sql
```

```bash
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/init_banco.sq
```

```bash
docker exec -i camiones_db psql -U postgres -d camiones < ~/ProyectoBD/init/logica_camiones.sql
```
# 4. IMPORTO (este es el paso que muestras al profe)
docker exec -it camiones_db psql -U postgres -d camiones -f /data/import_data.sql

### conectar
```bash
docker exec -it camiones_db psql -U postgres -d camiones
```
# Carga de Datos Masiva desde Excel/CSV

Copia la carpeta al contenedor:
```bash
docker cp ~/ProyectoBD/data camiones_db:/data
```
Ejecuta el script de importación:
```bash
docker cp ~/ProyectoBD/import_data.sql camiones_db:/data/import_data.sql
```
Verifica los datos:
```bash
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM region;"
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM canal;"
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM producto;"
docker exec -it camiones_db psql -U postgres -d camiones -c "SELECT * FROM venta;"

>>>>>>> 50191c5 (Update)
```