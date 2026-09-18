const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080'

async function request(path, options) {
  const response = await fetch(`${API_URL}${path}`, options)
  const body = await response.json().catch(() => ({}))

  if (!response.ok) {
    throw new Error(body.error || 'la operacion fallo')
  }

  return body
}

export function getExchanges() {
  return request('/api/exchanges')
}

export function getStocks() {
  return request('/api/stocks')
}

export function getPrices() {
  return request('/api/prices')
}

export function getOperations() {
  return request('/api/operations')
}

export function getPortfolio() {
  return request('/api/portfolio')
}

export function createOperation(payload) {
  return request('/api/operations', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
}
