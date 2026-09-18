import { useEffect, useState } from 'react'
import {
  getExchanges,
  getStocks,
  getPrices,
  getOperations,
  getPortfolio,
  createOperation
} from './api'

function App() {
  const [exchanges, setExchanges] = useState([])
  const [stocks, setStocks] = useState([])
  const [prices, setPrices] = useState([])
  const [operations, setOperations] = useState([])
  const [portfolio, setPortfolio] = useState([])
  const [selectedExchange, setSelectedExchange] = useState('all')
  const [quantities, setQuantities] = useState({})
  const [message, setMessage] = useState('')

  async function loadAll() {
    try {
      const [ex, st, pr, ops, port] = await Promise.all([
        getExchanges(),
        getStocks(),
        getPrices(),
        getOperations(),
        getPortfolio()
      ])
      setExchanges(ex.data)
      setStocks(st.data)
      setPrices(pr.data)
      setOperations(ops.data)
      setPortfolio(port.data)
    } catch (err) {
      setMessage(err.message)
    }
  }

  useEffect(() => {
    loadAll()
    const interval = setInterval(loadAll, 5000)
    return () => clearInterval(interval)
  }, [])

  function priceFor(symbol) {
    const found = prices.find((p) => p.symbol === symbol)
    return found ? Number(found.price) : null
  }

  function quantityFor(symbol) {
    return quantities[symbol] || 1
  }

  function setQuantity(symbol, value) {
    const parsed = Number(value)
    setQuantities({ ...quantities, [symbol]: parsed > 0 ? parsed : 1 })
  }

  async function trade(symbol, operationType) {
    const price = priceFor(symbol)
    if (!price) return

    try {
      await createOperation({
        symbol,
        operation_type: operationType,
        quantity: quantityFor(symbol),
        price
      })
      setMessage(
        `${operationType === 'buy' ? 'Compra' : 'Venta'} de ${symbol} registrada`
      )
      await loadAll()
    } catch (err) {
      setMessage(err.message)
    }
  }

  const visibleStocks =
    selectedExchange === 'all'
      ? stocks
      : stocks.filter((s) => String(s.exchange_id) === selectedExchange)

  return (
    <div className="container">
      <h1>Simulador de Bolsa de Valores</h1>

      {message && <div className="message">{message}</div>}

      <section>
        <h2>Bolsas de valores</h2>
        <div className="exchange-list">
          <button
            className={selectedExchange === 'all' ? 'active' : ''}
            onClick={() => setSelectedExchange('all')}
          >
            Todas
          </button>
          {exchanges.map((e) => (
            <button
              key={e.id}
              className={selectedExchange === String(e.id) ? 'active' : ''}
              onClick={() => setSelectedExchange(String(e.id))}
            >
              {e.code} - {e.name}
            </button>
          ))}
        </div>
      </section>

      <section>
        <h2>Acciones</h2>
        <table>
          <thead>
            <tr>
              <th>Simbolo</th>
              <th>Nombre</th>
              <th>Precio</th>
              <th>Cantidad</th>
              <th>Operar</th>
            </tr>
          </thead>
          <tbody>
            {visibleStocks.map((s) => (
              <tr key={s.id}>
                <td>{s.symbol}</td>
                <td>{s.name}</td>
                <td>{priceFor(s.symbol) ?? '-'}</td>
                <td>
                  <input
                    type="number"
                    min="1"
                    value={quantityFor(s.symbol)}
                    onChange={(e) => setQuantity(s.symbol, e.target.value)}
                  />
                </td>
                <td>
                  <button onClick={() => trade(s.symbol, 'buy')}>Comprar</button>
                  <button onClick={() => trade(s.symbol, 'sell')}>Vender</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section>
        <h2>Portafolio</h2>
        <table>
          <thead>
            <tr>
              <th>Simbolo</th>
              <th>Cantidad neta</th>
              <th>Invertido neto</th>
            </tr>
          </thead>
          <tbody>
            {portfolio.map((p) => (
              <tr key={p.symbol}>
                <td>{p.symbol}</td>
                <td>{p.quantity}</td>
                <td>{p.net_invested}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section>
        <h2>Historial de operaciones</h2>
        <table>
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Simbolo</th>
              <th>Tipo</th>
              <th>Cantidad</th>
              <th>Precio</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            {operations.map((op) => (
              <tr key={op.id}>
                <td>{new Date(op.inserted_at).toLocaleString()}</td>
                <td>{op.symbol}</td>
                <td>{op.operation_type === 'buy' ? 'Compra' : 'Venta'}</td>
                <td>{op.quantity}</td>
                <td>{op.price}</td>
                <td>{op.total}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  )
}

export default App
