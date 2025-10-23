# 🏦 Proyecto Banco Futura - Base de Datos (PostgreSQL + Docker)

**Autor:** Tomás Núñez Yañéz  
**Asignatura:** Base de Datos  
**Universidad Diego Portales**

---

## 📦 Descripción General

Proyecto de base de datos relacional implementado en **PostgreSQL**, normalizado hasta **3FN** y desplegado mediante **Docker Compose**.  
El sistema modela la gestión de **sucursales, ejecutivos, clientes, productos, ventas y metas de cumplimiento**, integrando **lógica de negocios directamente en la base de datos** mediante:

- **Stored Procedures (SP)**
- **Triggers**
- **Funciones auxiliares**
- **Vistas con cálculo automático de avance**

---

## ⚙️ Estructura del Proyecto

| Archivo | Descripción |
|----------|-------------|
| `init_camiones.sql` | Crea el esquema base: tablas, claves foráneas, índices y datos mínimos. |
| `init_banco.sql` | Inserta información adicional del contexto Banco Futura (sucursales, ejecutivos, metas, etc.). |
| `logica_camiones.sql` | Implementa toda la lógica de negocio en la BD: triggers, funciones, SP y vistas. |
| `test_logic.sql` | Ejecuta pruebas unitarias para verificar el correcto funcionamiento de la lógica. |
| `.env` | Variables de entorno necesarias para levantar la base en Docker. |

---

## 🧩 Variables de Entorno

Crea el archivo `.env` en la raíz del proyecto con el siguiente contenido:

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

## Cómo Ejecutar el Proyecto?
# 1️⃣ Iniciar el entorno con Docker

``` bash
Asegúrate de tener Docker y Docker Compose instalados en tu equipo local
```
Esto levanta los servicios:

PostgreSQL → contenedor camiones_db

## Cargar los cripts SQL
Ejecuta los siguientes comandos en orden (asumiendo que estás dentro de ~/ProyectoBD/init):

```bash
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
```