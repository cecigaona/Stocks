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

El middleware obtiene las instancias saludables desde Consul (`/v1/health/service/<servicio>?passing=true`). Los servicios se registran al iniciar y publican un health check HTTP. El middleware conserva una cache local con TTL de 3 segundos y sirve valores stale si Consul deja de responder. `middleware/services.json` es solo el fallback cuando Consul no esta disponible o no hay instancias saludables:

```json
{
  "exchanges_service": ["http://exchanges_service:4001"],
  "prices_service": ["http://prices_service:4002"],
  "operations_service": ["http://operations_service:4003"]
}
```

Cada clave puede tener una o varias direcciones HTTP. El archivo no se carga como fuente primaria al iniciar; `Middleware.Discovery` lo consulta bajo demanda solo como fallback.

### Balanceo de carga

Hay balanceo de carga en dos niveles:

1. **Nginx (`loadbalancer/`)**: hace round robin entre dos instancias identicas del middleware (`middleware1` y `middleware2`). Es el punto de entrada de todas las peticiones de la API, en el puerto 8080.
2. **Middleware (`Middleware.Grpc.Client`)**: el gateway usa round robin sobre las instancias gRPC indicadas por `EXCHANGES_GRPC_INSTANCES`, `PRICES_GRPC_INSTANCES` y `OPERATIONS_GRPC_INSTANCES`. Si una llamada falla al conectar, intenta la siguiente instancia configurada. En Compose cada variable contiene una instancia por servicio.

`Middleware.Discovery` aplica round robin a las direcciones HTTP del archivo fallback. Esta ruta se usa para los paths que no tienen un RPC gRPC dedicado; no es el mecanismo de descubrimiento para las llamadas gRPC conocidas.

### Enrutamiento del middleware

El middleware (`Middleware.Router`, un `Plug.Router`) mira el path de la peticion y decide a que servicio reenviarla:

| Path                  | Servicio destino     |
|------------------------|----------------------|
| `/api/exchanges*`      | exchanges_service    |
| `/api/stocks*`         | exchanges_service    |
| `/api/prices*`         | prices_service       |
| `/api/operations*`     | operations_service   |
| `/api/portfolio*`      | operations_service   |

Para las rutas conocidas, el middleware invoca el RPC gRPC correspondiente. Las rutas no cubiertas por esos RPC conservan el reenvio HTTP mediante `:httpc` como fallback.

## 6. Flujo completo de una peticion

Ejemplo: el usuario hace clic en "Comprar" en el frontend.

1. **Frontend**: React arma un `POST` a `http://localhost:8080/api/operations` con `{symbol, operation_type, quantity, price}`.
2. **Load balancer (Nginx, puerto 8080)**: recibe la peticion y la manda, por round robin, a `middleware1` o `middleware2`.
3. **Middleware**: identifica `/api/operations` y convierte la peticion HTTP en `Operations.CreateOperation`; el cliente gRPC conecta con `operations_service`.
4. **operations_service**: valida el simbolo consultando `exchanges_service` por gRPC, obtiene el precio de `prices_service` si la peticion no lo incluye y llama a `OperationsService.Trading.create_operation/1`.
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

## 9. gRPC, Protobuf y mensajeria GenStage

### Contratos y flujo gRPC

Los contratos estan en `proto/` y los modulos protobuf usados para compilar estan versionados bajo `lib/*/proto/` en cada aplicacion. Cada servicio escucha gRPC sin TLS en el puerto interno `50051`, `50052` o `50053`. El middleware actua como gateway gRPC en `50050` y como gateway REST en `4000`; Nginx balancea las peticiones HTTP externas de `8080` entre las dos instancias del middleware. La ruta gRPC hacia los servicios es middleware -> servicio; Nginx no termina ni balancea HTTP/2 gRPC.

`operations_service` llama a `exchanges_service` para validar acciones y a `prices_service` cuando una operacion no incluye precio. Los RPC conocidos de REST tambien atraviesan el middleware y se traducen a gRPC; las rutas REST no implementadas por esos RPC usan el proxy HTTP de fallback.

| Contrato | RPC |
|---|---|
| `exchanges.ExchangesService` | `ListExchanges`, `ListStocks`, `ListStocksByExchange`, `GetStock` |
| `prices.PricesService` | `ListPrices`, `GetPrice`, `FluctuatePrices` |
| `operations.OperationsService` | `ListOperations`, `CreateOperation`, `GetPortfolio` |

### Mensajeria asíncrona

La alternativa elegida es `GenStage`, ya incluido como dependencia en las cuatro aplicaciones. Cada aplicacion mantiene sus propios productores y consumidores locales; no es un broker distribuido entre nodos y los mensajes no sobreviven al reinicio del proceso.

| Aplicacion | Topico de eventos | Cola de fallos |
|---|---|---|
| `middleware` | `middleware_events` | `dead_letter` |
| `exchanges_service` | `exchanges_events` | `dead_letter` |
| `prices_service` | `prices_events` | `dead_letter` |
| `operations_service` | `operations_events` | `dead_letter` |

Los handlers gRPC publican consultas de acciones, fluctuaciones y operaciones. El simulador tambien publica un evento de precios cada cinco segundos. Los consumidores reciben demanda entre 1 y 10 mensajes por lote; cada productor conserva como maximo 1,000 mensajes pendientes. Una publicacion llena devuelve `{:error, :overloaded}` y el mensaje rechazado se conserva en la DLQ ETS del proceso. Un handler fallido se reintenta hasta completar tres intentos totales; despues se publica en `dead_letter` y queda visible mediante `DeadLetterQueue.list_messages/0`. La DLQ es memoria local y se pierde al reiniciar.

### Pruebas con grpcurl

Desde la raiz del proyecto, levanta el stack y espera a que Postgres y los servicios esten healthy:

```bash
docker compose up --build -d
```

Los comandos siguientes llaman al gateway gRPC del middleware, publicado en `localhost:50050`. Requieren `grpcurl` instalado. En una base recien creada, los seeds incluyen ocho acciones, ocho precios y dos operaciones. El simulador cambia los precios cada cinco segundos, por lo que su valor y marca de tiempo pueden variar.

**Exchanges**

```bash
grpcurl -plaintext -import-path ./proto -proto exchanges.proto -d '{}' localhost:50050 exchanges.ExchangesService/ListExchanges
grpcurl -plaintext -import-path ./proto -proto exchanges.proto -d '{}' localhost:50050 exchanges.ExchangesService/ListStocks
grpcurl -plaintext -import-path ./proto -proto exchanges.proto -d '{"exchangeId":2}' localhost:50050 exchanges.ExchangesService/ListStocksByExchange
grpcurl -plaintext -import-path ./proto -proto exchanges.proto -d '{"symbol":"AAPL"}' localhost:50050 exchanges.ExchangesService/GetStock
```

Respuestas esperadas: `ListExchanges` contiene `NYSE`, `NASDAQ` y `BMV`; `ListStocks` devuelve ocho acciones; `ListStocksByExchange` para el id `2` devuelve `AAPL`, `MSFT` y `GOOGL`; `GetStock` devuelve la accion `AAPL`. Ejemplo de respuesta individual:

```json
{"stock":{"id":"1","symbol":"AAPL","name":"Apple Inc.","exchangeId":"2"}}
```

**Prices**

```bash
grpcurl -plaintext -import-path ./proto -proto prices.proto -d '{}' localhost:50050 prices.PricesService/ListPrices
grpcurl -plaintext -import-path ./proto -proto prices.proto -d '{"symbol":"AAPL"}' localhost:50050 prices.PricesService/GetPrice
grpcurl -plaintext -import-path ./proto -proto prices.proto -d '{}' localhost:50050 prices.PricesService/FluctuatePrices
```

Respuestas esperadas: `ListPrices` contiene ocho precios; `GetPrice` devuelve el precio actual de `AAPL`; `FluctuatePrices` devuelve `{"updatedCount":8}`. Ejemplo de `GetPrice` (el precio puede variar):

```json
{"price":{"id":"1","symbol":"AAPL","price":"227.50","updatedAt":"2026-10-28T12:00:00Z"}}
```

**Operations**

```bash
grpcurl -plaintext -import-path ./proto -proto operations.proto -d '{}' localhost:50050 operations.OperationsService/ListOperations
grpcurl -plaintext -import-path ./proto -proto operations.proto -d '{"symbol":"AAPL","operationType":"buy","quantity":2,"price":"227.50"}' localhost:50050 operations.OperationsService/CreateOperation
grpcurl -plaintext -import-path ./proto -proto operations.proto -d '{}' localhost:50050 operations.OperationsService/GetPortfolio
```

En una base recien creada, `ListOperations` devuelve las dos operaciones semilla. `CreateOperation` debe devolver una compra AAPL con cantidad `2`, precio `227.50` y total `455.00`; el id y la fecha dependen de la base. Ejecuta `GetPortfolio` despues de `CreateOperation`: AAPL debe pasar a cantidad `12` e inversion neta `2730.00`; MSFT permanece en cantidad `5` e inversion `2076.00`. Ejemplo de respuesta de `CreateOperation`:

```json
{"operation":{"id":"3","symbol":"AAPL","operationType":"buy","quantity":2,"price":"227.50","total":"455.00","insertedAt":"2026-10-28T12:00:00Z"}}
```

Para llamar directamente a un servicio en lugar del gateway, sustituye `localhost:50050` por `localhost:50051` para exchanges, `localhost:50052` para prices o `localhost:50053` para operations. El stack no estaba activo al preparar esta seccion; los comandos y respuestas esperadas quedan documentados, pero no se ejecutaron contra servicios vivos.
