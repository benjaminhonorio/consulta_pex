# Contribuir a ConsultaPex

Las contribuciones son bienvenidas. Para cambios grandes, abre un issue primero para discutir qué te gustaría cambiar.

## Proceso

1. Fork del repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit de tus cambios (`git commit -m 'Agrega nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## Desarrollo local

```bash
# Instalar dependencias
mix deps.get
cd priv/playwright && npm ci && npm run build && cd ../..

# Instalar Firefox para Playwright
cd priv/playwright && npx playwright install firefox && cd ../..

# Iniciar Redis
redis-server

# Ejecutar
source .env && mix run --no-halt
```

## Estilo de código

- Sigue las convenciones de Elixir estándar
- Usa `mix format` antes de hacer commit
