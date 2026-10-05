# TCC – Ciclos Políticos Orçamentários nos Municípios Brasileiros

Pipeline de construção do painel município-ano (2013–2025) com dados do Siconfi, TSE, IBGE e Censo, para a monografia de Ciências Econômicas (UFPR).

## Requisitos
- Python 3 e as bibliotecas de `requirements.txt`.
- Conta Google com um projeto no Google Cloud (BigQuery) para baixar dados da Base dos Dados. Os scripts usam o projeto de cobrança `monografia-508123`; para rodar em outra conta, troque o `billing_project_id` nos scripts pelo seu projeto. No primeiro download, a biblioteca `basedosdados` pede login no Google.

## Execução (a partir da raiz do projeto)
```
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python codigo/main_code.py
python codigo/explora_receitas.py
```
Os scripts só consultam as fontes quando o arquivo de cache em `dados/cache/` não existe. Na primeira execução em outro computador, tudo é baixado de novo, o que gera custo de consulta no BigQuery.

A base final é `dados/finais/painel_final_real.parquet` (valores deflacionados pelo IPCA médio anual, R$ de 2025).

## Fontes de dados
- **Base dos Dados (BigQuery):** Siconfi (despesas por função e receitas orçamentárias), TSE (resultados, candidatos e partidos), IBGE (PIB e população).
- **TSE (arquivo oficial):** coligações de 2010 (`consulta_coligacao_2010`), baixado de cdn.tse.jus.br.
- **SIDRA/IBGE:** Censos 2010 e 2022 (CSVs em `dados/externos/`) e IPCA mensal (tabela 1737, em `dados/cache/ipca_mensal.csv`).

## O que está no Git
Só o código, a documentação e as entradas pequenas que não são baixadas automaticamente (CSVs do SIDRA e o IPCA). Caches e bases geradas (`dados/cache/`, `dados/finais/`, `backups/`, `obsoletos/`, `saidas/`) ficam fora do Git e são recriados pelo pipeline. Versões antigas de alguns parquet continuam no histórico/LFS do repositório.

## Pastas
- `codigo/`: pipeline (`main_code.py`, `explora_receitas.py`) e `caminhos.py`, com todos os caminhos de arquivo.
- `codigo/exploracao/`: testes e explorações fora do pipeline.
- `dados/externos/`: CSVs do SIDRA (Censo).
- `dados/cache/`: caches das consultas.
- `dados/finais/`: bases geradas.
- `saidas/exploracao/`: planilhas e CSVs de conferência.
- `backups/`, `obsoletos/`: cópias de conferência e caches não usados.
- `referencia/br_me_siconfi/`: código da Base dos Dados, só para consulta.
- `regressao/`: scripts de R (em construção).

Os detalhes metodológicos e as decisões estão em `CLAUDE.md`.