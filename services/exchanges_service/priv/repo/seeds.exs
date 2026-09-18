alias ExchangesService.Repo
alias ExchangesService.Catalog.{Exchange, Stock}

if Repo.aggregate(Exchange, :count, :id) == 0 do
  nyse = Repo.insert!(%Exchange{name: "New York Stock Exchange", code: "NYSE"})
  nasdaq = Repo.insert!(%Exchange{name: "NASDAQ", code: "NASDAQ"})
  bmv = Repo.insert!(%Exchange{name: "Bolsa Mexicana de Valores", code: "BMV"})

  Repo.insert!(%Stock{symbol: "AAPL", name: "Apple Inc.", exchange_id: nasdaq.id})
  Repo.insert!(%Stock{symbol: "MSFT", name: "Microsoft Corp.", exchange_id: nasdaq.id})
  Repo.insert!(%Stock{symbol: "GOOGL", name: "Alphabet Inc.", exchange_id: nasdaq.id})
  Repo.insert!(%Stock{symbol: "KO", name: "The Coca-Cola Company", exchange_id: nyse.id})
  Repo.insert!(%Stock{symbol: "JPM", name: "JPMorgan Chase & Co.", exchange_id: nyse.id})
  Repo.insert!(%Stock{symbol: "WMT", name: "Walmart Inc.", exchange_id: nyse.id})
  Repo.insert!(%Stock{symbol: "AMXL", name: "America Movil", exchange_id: bmv.id})
  Repo.insert!(%Stock{symbol: "GFNORTEO", name: "Grupo Financiero Banorte", exchange_id: bmv.id})
end
