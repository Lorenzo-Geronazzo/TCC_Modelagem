# ==============================================================================
# CAMINHOS DO PROJETO
# ==============================================================================
# Todos os arquivos que os scripts leem ou gravam, a partir da raiz do projeto.
# Assim os scripts funcionam rodando de qualquer pasta (terminal na raiz ou
# células do VS Code, que rodam na pasta do próprio script).
# Para mudar um arquivo de lugar, mude só aqui.
from pathlib import Path

# Raiz do projeto = pasta acima de codigo/ (onde este arquivo está)
RAIZ = Path(__file__).resolve().parents[1]

# Pastas
DADOS = RAIZ / "dados"
EXTERNOS = DADOS / "externos"           # CSVs baixados à mão (SIDRA/IBGE)
CACHE = DADOS / "cache"                 # caches das consultas (BigQuery, TSE, IPCA)
FINAIS = DADOS / "finais"               # painéis e bases geradas pelo pipeline
SAIDAS_EXPLORACAO = RAIZ / "saidas" / "exploracao"   # xlsx e csv de testes
BACKUPS = RAIZ / "backups"              # cópias "antes" de mudanças de regra
OBSOLETOS = RAIZ / "obsoletos"          # caches que não são mais usados

# ------------------------------------------------------------------------------
# Externos (Censo, SIDRA)
# ------------------------------------------------------------------------------
URB_2022 = EXTERNOS / "tabela9923.csv"     # urbanização 2022
URB_2010 = EXTERNOS / "tabela202.csv"      # urbanização 2010
IDADE_2022 = EXTERNOS / "tabela9514.csv"   # idade 2022
IDADE_2010 = EXTERNOS / "tabela200.csv"    # idade 2010

# ------------------------------------------------------------------------------
# Caches do pipeline (apague o arquivo para forçar novo download)
# ------------------------------------------------------------------------------
SICONFI_DESPESAS = CACHE / "base_siconfi_despesas.parquet"
PREFEITOS = CACHE / "base_prefeitos_v3.parquet"
GOV_PRES = CACHE / "base_gov_pres_v2.parquet"
GOV_PRES_2010 = CACHE / "base_gov_pres_2010.parquet"
IBGE_ANUAL = CACHE / "base_ibge_anual.parquet"
CATALOGO_RECEITAS = CACHE / "catalogo_receitas.parquet"
SICONFI_RECEITAS = CACHE / "base_siconfi_receitas.parquet"
IPCA_MENSAL = CACHE / "ipca_mensal.csv"

# Caches dos testes de hierarquia das receitas (codigo/exploracao/teste_mae_filho.py)
TESTE_TODAS_MAES = CACHE / "teste_todas_maes.parquet"
CONTRIBUICAO_MELHORIA = CACHE / "contribuicao_melhoria_v2.parquet"
TRANSFERENCIAS_FILHAS = CACHE / "transferencias_filhas.parquet"

# ------------------------------------------------------------------------------
# Bases finais (ordem do pipeline)
# ------------------------------------------------------------------------------
PAINEL_ELEICOES = FINAIS / "painel_final_eleicoes.parquet"                     # main_code.py
RECEITAS_MUNICIPIO_ANO = FINAIS / "receitas_municipio_ano.parquet"             # explora_receitas.py, Célula 2
RECEITAS_MUNICIPIO_ANO_CSV = FINAIS / "receitas_municipio_ano.csv"
PAINEL_ELEICOES_RECEITAS = FINAIS / "painel_final_eleicoes_receitas.parquet"   # explora_receitas.py, Célula 3
PAINEL_FINAL_REAL = FINAIS / "painel_final_real.parquet"                       # explora_receitas.py, Célula 4 (BASE FINAL)

# ------------------------------------------------------------------------------
# Saídas de exploração
# ------------------------------------------------------------------------------
CATALOGO_RECEITAS_XLSX = SAIDAS_EXPLORACAO / "catalogo_receitas.xlsx"
CATALOGO_CONTAS_DESPESAS_XLSX = SAIDAS_EXPLORACAO / "catalogo_contas_despesas.xlsx"
NAO_BATEM_TODAS_MAES = SAIDAS_EXPLORACAO / "nao_batem_todas_maes.csv"
RESUMO_TODAS_MAES = SAIDAS_EXPLORACAO / "resumo_todas_maes.csv"
TRIB_AINDA_NAO_BATEM = SAIDAS_EXPLORACAO / "trib_ainda_nao_batem.csv"
TRANSF_NAO_BATEM = SAIDAS_EXPLORACAO / "transf_nao_batem.csv"

# ------------------------------------------------------------------------------
# Obsoletos (só usados por codigo/exploracao/teste_nomemclatura_partidos.py)
# ------------------------------------------------------------------------------
PREFEITOS_V1 = OBSOLETOS / "base_prefeitos.parquet"
GOV_PRES_V1 = OBSOLETOS / "base_gov_pres.parquet"
