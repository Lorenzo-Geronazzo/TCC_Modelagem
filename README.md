# Modelagem

Pipeline de construcao do painel municipal com dados do SICONFI, TSE, IBGE e Censo.

## Execução

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python codigo/main_code.py
python codigo/explora_receitas.py
```

Os scripts consultam a Base dos Dados só quando o cache em `dados/cache/` não existe.
A base final é `dados/finais/painel_final_real.parquet`. Os painéis
`dados/finais/painel_final_*.parquet` são ignorados pelo Git (são grandes e podem ser
recriados pelo pipeline); os caches são versionados via Git LFS.

## Pastas

- `codigo/`: pipeline (`main_code.py`, `explora_receitas.py`) e `caminhos.py`, com todos os caminhos de arquivo.
- `codigo/exploracao/`: testes e explorações fora do pipeline.
- `dados/externos/`, `dados/cache/`, `dados/finais/`: CSVs do SIDRA, caches das consultas e bases geradas.
- `saidas/exploracao/`: planilhas e CSVs de conferência.
- `backups/`, `obsoletos/`, `referencia/`, `regressao/` (scripts de R).
