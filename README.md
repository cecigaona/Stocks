# Simulador de Bolsa de Valores

## 1. Descripcion

Plataforma web para consultar bolsas de valores, ver el precio de sus acciones (con datos simulados que cambian cada pocos segundos) y simular compras y ventas. El sistema esta dividido en un frontend, un middleware con balanceo de carga, y tres microservicios de backend escritos en Elixir con Phoenix, cada uno con su propia base de datos en PostgreSQL.

## 2. Estructura de carpetas

```
.
├── docker-compose.yml
├── .env
├── install.sh
├── scripts/
│   └── init-multi-db.sh          # crea las 3 bases de datos en Postgres
├── frontend/                     # React (Vite)
├── loadbalancer/                 # Nginx, balanceo round robin
├── middleware/                   # Elixir, service discovery + enrutamiento
│   └── services.json             # archivo de service discovery
└── services/
    ├── exchanges_service/        # bolsas y acciones
    ├── prices_service/           # precios simulados
    └── operations_service/       # compras y ventas
```

Cada servicio de `services/` sigue la misma organizacion interna (Phoenix API):

```
services/<nombre>_service/
├── lib/<nombre>_service/          # capa de dominio (schemas + servicio)
├── lib/<nombre>_service_web/      # capa web (router + controllers)
├── priv/repo/migrations/          # migraciones de Ecto
├── priv/repo/seeds.exs            # datos semilla
└── Dockerfile
```

## 3. Requisitos y como levantar el proyecto

Requisitos: Docker y Docker Compose (el script de instalacion los instala si hacen falta).

Pasos:

```bash
cd Proyecto
./install.sh
```

El script `install.sh`:
1. Revisa si Docker y Docker Compose estan instalados; si no, intenta instalarlos (Homebrew en macOS, script oficial en Linux).
2. Ejecuta `docker compose up --build -d`.

Al terminar:
- Frontend: http://localhost:3000
- API (a traves del load balancer): http://localhost:8080/api

Si prefieres hacerlo manualmente:

```bash
docker compose up --build
```

Para apagar todo:

```bash
docker compose down
```

Para borrar tambien los datos de Postgres:

```bash
docker compose down -v
```

## 4. Backend: como funciona cada servicio

Los tres servicios de backend son aplicaciones Phoenix en modo API (sin HTML, sin assets), conectadas a PostgreSQL con Ecto. Cada uno tiene su propia base de datos (`exchanges_db`, `prices_db`, `operations_db`) para mantenerlos independientes entre si.

**Patron de diseno usado: Controller - Service - Repository.**

- **Controller** (`lib/<servicio>_web/controllers/`): recibe la peticion HTTP, llama a la capa de servicio y arma la respuesta JSON. No contiene logica de negocio.
- **Service** (por ejemplo `Catalog`, `Prices`, `Trading` en `lib/<servicio>/`): contiene la logica de negocio (validaciones, calculos, agregaciones). Es el unico que le habla al repositorio.
- **Repository**: en este proyecto el rol de repositorio lo cumple el `Repo` de Ecto (`ExchangesService.Repo`, `PricesService.Repo`, `OperationsService.Repo`), que es la unica capa que ejecuta consultas SQL contra Postgres.

### 4.1 exchanges_service (puerto interno 4001)

Administra el catalogo de bolsas de valores y las acciones que pertenecen a cada una.

- `GET /api/exchanges` - lista las bolsas.
- `GET /api/exchanges/:id/stocks` - lista las acciones de una bolsa.
- `GET /api/stocks` - lista todas las acciones.

Tablas: `exchanges` (nombre, codigo) y `stocks` (simbolo, nombre, bolsa a la que pertenece).

### 4.2 prices_service (puerto interno 4002)

Guarda el precio actual de cada accion y lo actualiza automaticamente. Un `GenServer` (`PricesService.Simulator`) corre cada 5 segundos y mueve cada precio de forma aleatoria (+/- 1%), simulando el movimiento del mercado.

- `GET /api/prices` - lista todos los precios.
- `GET /api/prices/:symbol` - precio de una accion especifica.

Tabla: `stock_prices` (simbolo, precio, fecha de actualizacion).

### 4.3 operations_service (puerto interno 4003)

Registra las compras y ventas simuladas y calcula el portafolio resultante.

- `GET /api/operations` - historial de operaciones.
- `POST /api/operations` - registra una compra o venta.
- `GET /api/portfolio` - cantidad neta e inversion neta por accion, calculada a partir del historial de operaciones.

Tabla: `operations` (simbolo, tipo, cantidad, precio, total).

## 5. Service discovery y load balancer

### Service discovery

El middleware no tiene las direcciones de los tres servicios de backend escritas en el codigo. Las lee de un archivo estatico, `middleware/services.json`:

```json
{
  "exchanges_service": ["http://exchanges_service:4001"],
  "prices_service": ["http://prices_service:4002"],
  "operations_service": ["http://operations_service:4003"]
}
```

Cada clave puede tener una o varias direcciones. Al iniciar, el middleware carga este archivo en memoria (modulo `Middleware.Discovery`, un `GenServer`).

### Balanceo de carga

Hay balanceo de carga en dos niveles:

1. **Nginx (`loadbalancer/`)**: hace round robin entre dos instancias identicas del middleware (`middleware1` y `middleware2`). Es el punto de entrada de todas las peticiones de la API, en el puerto 8080.
2. **Middleware (`Middleware.Discovery`)**: cuando una direccion en `services.json` tiene mas de un elemento, el middleware tambien reparte las peticiones entre ellas en round robin (mismo mecanismo: un contador por servicio que avanza en cada peticion).

### Enrutamiento del middleware

El middleware (`Middleware.Router`, un `Plug.Router`) mira el path de la peticion y decide a que servicio reenviarla:

| Path                  | Servicio destino     |
|------------------------|----------------------|
| `/api/exchanges*`      | exchanges_service    |
| `/api/stocks*`         | exchanges_service    |
| `/api/prices*`         | prices_service       |
| `/api/operations*`     | operations_service   |
| `/api/portfolio*`      | operations_service   |

Para reenviar la peticion usa el cliente HTTP incluido en Erlang (`:httpc`), sin depender de una libreria externa.

## 6. Flujo completo de una peticion

Ejemplo: el usuario hace clic en "Comprar" en el frontend.

1. **Frontend**: React arma un `POST` a `http://localhost:8080/api/operations` con `{symbol, operation_type, quantity, price}`.
2. **Load balancer (Nginx, puerto 8080)**: recibe la peticion y la manda, por round robin, a `middleware1` o `middleware2`.
3. **Middleware**: identifica que el path empieza con `/api/operations`, busca en `services.json` la direccion de `operations_service` (con round robin si hay varias) y reenvia la peticion tal cual.
4. **operations_service**: el `OperationController` recibe la peticion, llama a `OperationsService.Trading.create_operation/1`, que calcula el total y valida los datos con un changeset de Ecto.
5. **Base de datos**: `Trading` usa `OperationsService.Repo` para insertar la fila en la tabla `operations` de `operations_db` (PostgreSQL).
6. La respuesta (JSON con la operacion creada) regresa por el mismo camino: servicio -> middleware -> load balancer -> frontend, que actualiza la tabla de operaciones y el portafolio en pantalla.

Para una consulta de solo lectura (por ejemplo `GET /api/prices`) el flujo es el mismo, solo que sin el paso de escritura.

## 7. Endpoints principales

Todos se consultan a traves del load balancer: `http://localhost:8080`.

**Bolsas y acciones**
```bash
curl http://localhost:8080/api/exchanges
curl http://localhost:8080/api/exchanges/1/stocks
curl http://localhost:8080/api/stocks
```

**Precios**
```bash
curl http://localhost:8080/api/prices
curl http://localhost:8080/api/prices/AAPL
```

**Operaciones y portafolio**
```bash
curl http://localhost:8080/api/operations

curl -X POST http://localhost:8080/api/operations \
  -H "Content-Type: application/json" \
  -d '{"symbol": "AAPL", "operation_type": "buy", "quantity": 10, "price": 227.50}'

curl http://localhost:8080/api/portfolio
```

## 8. Problemas comunes y soluciones

**Docker Compose falla al construir un servicio de Elixir.**
La primera compilacion descarga dependencias de Hex y puede tardar varios minutos. Vuelve a intentar con `docker compose build <servicio>`.

**Un servicio de backend se reinicia en bucle al arrancar.**
Casi siempre es porque Postgres todavia no esta listo. Los servicios dependen de `postgres` con `condition: service_healthy`, pero si el healthcheck falla revisa los logs con `docker compose logs postgres`.

**El frontend no puede conectarse a la API (error de red o CORS).**
Verifica que el load balancer este arriba en `http://localhost:8080`. Los encabezados de CORS se agregan en `loadbalancer/nginx.conf`; si cambiaste el puerto del frontend, revisa que siga apuntando a ese origen.

**`mix ecto.create` falla porque la base de datos ya existe.**
No es un error real: el comando esta en el `CMD` del contenedor para que funcione tanto en el primer arranque como en los siguientes; si la base ya existe, Ecto simplemente continua.

**Quiero reiniciar todo desde cero (borrar datos).**
```bash
docker compose down -v
docker compose up --build
```

**Cambie el codigo de un servicio y no se refleja.**
Los contenedores no tienen hot-reload. Reconstruye con:
```bash
docker compose up --build <servicio>
```

**Puerto ocupado (3000, 8080 o 5432).**
Cambia el mapeo de puertos en `docker-compose.yml` (por ejemplo `"3001:80"`) o libera el puerto que ya esta en uso en tu maquina.
