# %%
# ==============================================================================
# EXPLORAÇÃO DAS RECEITAS ORÇAMENTÁRIAS (SICONFI) - FORA DO PAINEL PRINCIPAL
# ==============================================================================
# Objetivo: gerar arquivos separados para decidir quais contas de receita
# (ex.: receita tributária, transferências correntes) entram no painel.
# Nada aqui é juntado ao painel_final_eleicoes.
import basedosdados as bd
import pandas as pd
import os

ANO_INICIAL = 2013  # mesmo recorte do painel de despesas

# %%
# ==============================================================================
# CÉLULA 1: CATÁLOGO DE CONTAS (AGREGADO NO BIGQUERY, LEVE)
# ==============================================================================
# Uma linha por estágio x conta x ano, com nº de municípios e soma dos valores.
# Serve para enxergar a hierarquia de contas e a cobertura antes de baixar tudo.
caminho_catalogo = "catalogo_receitas.parquet"

if os.path.exists(caminho_catalogo):
    df_cat_ano = pd.read_parquet(caminho_catalogo)
    print("Catálogo de receitas carregado do arquivo local!")
else:
    print("Baixando catálogo de contas de receita via Base dos Dados...")
    query_catalogo = f"""
    SELECT
        dados.ano,
        dados.estagio,
        dados.estagio_bd,
        dados.portaria,
        dados.conta,
        dados.id_conta_bd,
        dados.conta_bd,
        COUNT(DISTINCT dados.id_municipio) AS n_municipios,
        SUM(dados.valor) AS soma_valor
    FROM `basedosdados.br_me_siconfi.municipio_receitas_orcamentarias` AS dados
    WHERE dados.ano >= {ANO_INICIAL}
    GROUP BY 1, 2, 3, 4, 5, 6, 7
    """
    df_cat_ano = bd.read_sql(query=query_catalogo, billing_project_id="monografia-508123")
    df_cat_ano.to_parquet(caminho_catalogo, index=False)
    print("Catálogo salvo localmente!")

# Estágios disponíveis (ex.: receita bruta realizada e as deduções)
print("\nEstágios disponíveis:")
print(df_cat_ano.groupby(['estagio', 'estagio_bd'], dropna=False)['n_municipios'].max())

# Resumo por conta compatibilizada (id_conta_bd), que é estável entre anos
chaves_conta = ['estagio_bd', 'id_conta_bd', 'conta_bd']
df_cat = (
    df_cat_ano.groupby(chaves_conta, dropna=False)
    .agg(
        ano_min=('ano', 'min'),
        ano_max=('ano', 'max'),
        n_anos=('ano', 'nunique'),
        media_municipios_ano=('n_municipios', 'mean'),
        soma_valor=('soma_valor', 'sum'),
        portarias_originais=('portaria', lambda x: ' | '.join(sorted(x.dropna().astype(str).unique()))),
    )
    .reset_index()
)

# Cobertura: nº de municípios com a conta em cada ano (colunas = anos)
df_cobertura = df_cat_ano.pivot_table(
    index=chaves_conta, columns='ano', values='n_municipios', aggfunc='sum'
).reset_index()
df_cobertura.columns = [str(c) for c in df_cobertura.columns]

# Contas originais que não têm correspondência compatibilizada
sem_bd = df_cat_ano[df_cat_ano['id_conta_bd'].isna()]
print(f"\nLinhas do catálogo sem id_conta_bd: {len(sem_bd)}")

# Exporta em formato amigável para Excel (separador ; e vírgula decimal)
# Se o .xlsx estiver aberto no Excel, o Windows bloqueia a escrita (PermissionError).
# Nesse caso só avisa e segue, sem travar as próximas etapas.
try:
    with pd.ExcelWriter("catalogo_receitas.xlsx") as writer:
        df_cat.sort_values(chaves_conta).to_excel(writer, sheet_name='resumo_conta_bd', index=False)
        df_cobertura.to_excel(writer, sheet_name='municipios_por_ano', index=False)
        df_cat_ano.sort_values(['estagio', 'ano', 'portaria']).to_excel(writer, sheet_name='original_por_ano', index=False)
    print("Catálogo exportado para catalogo_receitas.xlsx")
except PermissionError:
    print("AVISO: catalogo_receitas.xlsx está aberto em outro programa (Excel?). Feche e rode de novo para atualizar o .xlsx.")

print("\nPrévia das contas compatibilizadas:")
print(df_cat.sort_values(chaves_conta).head(40).to_string())


# %%
# ==============================================================================
# CÉLULA 2: BASE MUNICÍPIO-ANO DAS CONTAS ESCOLHIDAS (DOWNLOAD COMPLETO)
# ==============================================================================
# A tabela completa é grande (todas as contas x estágios x municípios x anos).
# Preencha os filtros abaixo depois de olhar o catálogo. Se mudar os filtros,
# apague base_siconfi_receitas.parquet para forçar novo download.
ESTAGIOS_BD = ['Receitas Brutas Realizadas']   # ex.: ['Receitas Brutas Realizadas'] (valores de estagio_bd)
CONTAS_BD = ['1.1.1.0.0.00.00.00', '1.1.7.0.0.00.00.00']     # ex.: ['1.1.0.0.00.0.0', '1.7.0.0.00.0.0'] (valores de id_conta_bd); vazio = todas

caminho_receitas = "base_siconfi_receitas.parquet"

if not ESTAGIOS_BD:
    print("Defina ESTAGIOS_BD (e opcionalmente CONTAS_BD) a partir do catálogo antes de rodar esta célula.")
elif os.path.exists(caminho_receitas):
    df_receitas = pd.read_parquet(caminho_receitas)
    print("Base de receitas carregada do arquivo local!")
else:
    print("Baixando receitas orçamentárias via Base dos Dados...")
    lista_estagios = ', '.join(f"'{e}'" for e in ESTAGIOS_BD)
    filtro_contas = ''
    if CONTAS_BD:
        lista_contas = ', '.join(f"'{c}'" for c in CONTAS_BD)
        filtro_contas = f"AND dados.id_conta_bd IN ({lista_contas})"

    query_receitas = f"""
    SELECT
        dados.ano,
        dados.sigla_uf,
        dados.id_municipio,
        diretorio_id_municipio.nome AS id_municipio_nome,
        dados.estagio,
        dados.portaria,
        dados.conta,
        dados.estagio_bd,
        dados.id_conta_bd,
        dados.conta_bd,
        dados.valor
    FROM `basedosdados.br_me_siconfi.municipio_receitas_orcamentarias` AS dados
    LEFT JOIN (SELECT DISTINCT id_municipio, nome FROM `basedosdados.br_bd_diretorios_brasil.municipio`) AS diretorio_id_municipio
        ON dados.id_municipio = diretorio_id_municipio.id_municipio
    WHERE dados.ano >= {ANO_INICIAL}
      AND dados.estagio_bd IN ({lista_estagios})
      {filtro_contas}
    """
    df_receitas = bd.read_sql(query=query_receitas, billing_project_id="monografia-508123")
    df_receitas.to_parquet(caminho_receitas, index=False)
    print("Download das receitas concluído e salvo localmente!")

if ESTAGIOS_BD:
    # Formato largo: uma linha por município-ano, uma coluna por estágio x conta
    df_receitas_largo = df_receitas.pivot_table(
        index=['ano', 'sigla_uf', 'id_municipio', 'id_municipio_nome'],
        columns=['estagio_bd', 'id_conta_bd'],
        values='valor',
        aggfunc='sum',
    )
    df_receitas_largo.columns = [f"{e} | {c}" for e, c in df_receitas_largo.columns]
    df_receitas_largo = df_receitas_largo.reset_index()

    df_receitas_largo.to_parquet("receitas_municipio_ano.parquet", index=False)
    df_receitas_largo.to_csv("receitas_municipio_ano.csv", index=False, sep=';', decimal=',', encoding='utf-8-sig')
    print(f"Base larga gerada: {df_receitas_largo.shape[0]} município-anos, {df_receitas_largo.shape[1]} colunas")
    print(df_receitas_largo.head(10).to_string())
    print(df_receitas.groupby(["ano", "id_municipio"]).ngroups, len(df_receitas_largo))


# %%                              
# ==============================================================================
# CÉLULA 3: JUNTA AS RECEITAS AO PAINEL
# ==============================================================================
# Pré-requisito: Célula 2 rodada com
#   ESTAGIOS_BD = ['Receitas Brutas Realizadas']
#   CONTAS_BD   = ['1.1.1.0.0.00.00.00', '1.1.7.0.0.00.00.00']
# Contas validadas por município-ano (teste_todas_maes.py):
#   1.1.1.0 = Impostos + Taxas + Contribuição de Melhoria (100%)
#   1.1.7.0 = soma das filhas diretas 1.7.X (100%, exceto ~2 casos em 2013)
import pandas as pd

# 1) Lê a base larga gerada pela Célula 2 e dá nomes curtos às colunas
receitas = pd.read_parquet("receitas_municipio_ano.parquet")
receitas = receitas.rename(columns={
    "Receitas Brutas Realizadas | 1.1.1.0.0.00.00.00": "receita_tributaria",
    "Receitas Brutas Realizadas | 1.1.7.0.0.00.00.00": "transf_correntes",
})
receitas = receitas[["ano", "id_municipio", "receita_tributaria", "transf_correntes"]]

# Confere: tem que ser uma linha por município-ano
duplicados = receitas.duplicated(["ano", "id_municipio"]).sum()
print(f"Município-anos repetidos nas receitas: {duplicados}  (tem que ser 0)")

# 2) Garante que as chaves têm o mesmo tipo nas duas tabelas (texto)
painel = pd.read_parquet("painel_final_eleicoes.parquet")
for tabela in (painel, receitas):
    tabela["id_municipio"] = tabela["id_municipio"].astype(str)
    tabela["ano"] = tabela["ano"].astype(int)

# 3) Junta (left: mantém todas as linhas do painel, mesmo sem receita)
linhas_antes = len(painel)
painel = painel.merge(receitas, on=["ano", "id_municipio"], how="left")
print(f"Linhas do painel: antes {linhas_antes}, depois {len(painel)}  (têm que ser iguais)")

# 4) Quanto ficou vazio, por ano (município sem dado de receita naquele ano)
print("\n% de linhas sem receita, por ano:")
print((painel.groupby("ano")[["receita_tributaria", "transf_correntes"]]
       .apply(lambda x: x.isna().mean() * 100).round(2)))

# 5) Per capita (valores ainda NOMINAIS: falta deflacionar pelo IPCA)
if "populacao" in painel.columns:
    painel["receita_tributaria_pc"] = painel["receita_tributaria"] / painel["populacao"]
    painel["transf_correntes_pc"] = painel["transf_correntes"] / painel["populacao"]
    print("\nColunas per capita criadas.")
else:
    print("\nColuna 'populacao' não encontrada. Colunas disponíveis:")
    print(list(painel.columns))

# 6) Salva em arquivo novo (não sobrescreve o painel original)
painel.to_parquet("painel_final_eleicoes_receitas.parquet", index=False)
print("\nSalvo: painel_final_eleicoes_receitas.parquet")

# %%
# ==============================================================================
# CÉLULA 4: DEFLACIONAR PELO IPCA MÉDIO ANUAL (PREÇOS DE 2025)
# ==============================================================================
# Fonte: SIDRA/IBGE, tabela 1737, variável 2266
#        "IPCA - Número-índice (base: dezembro de 1993 = 100)", mensal, Brasil.
# Regra: valores de receita, despesa e PIB são fluxos do ano inteiro
#        -> deflator = média dos 12 números-índice do ano.
# Fórmula: valor_real = valor_nominal * (média IPCA 2025 / média IPCA do ano)
import pandas as pd
import numpy as np
import requests
import os

ANO_BASE = 2025
ANO_INICIAL = 2013

# 1) Baixa o IPCA mensal (com cache em csv, como os outros blocos)
caminho_ipca = "ipca_mensal.csv"
if os.path.exists(caminho_ipca):
    ipca = pd.read_csv(caminho_ipca, dtype={"mes": str})
    print("IPCA carregado do arquivo local!")
else:
    url = (f"https://apisidra.ibge.gov.br/values/t/1737/n1/all/v/2266/"
           f"p/{ANO_INICIAL}01-{ANO_BASE}12")
    resposta = requests.get(url, timeout=60)
    resposta.raise_for_status()
    dados = resposta.json()                 # a 1ª linha é o cabeçalho
    ipca = pd.DataFrame(dados[1:])[["D3C", "V"]].rename(columns={"D3C": "mes", "V": "indice"})
    ipca.to_csv(caminho_ipca, index=False)
    print("IPCA baixado do SIDRA e salvo localmente!")

ipca["indice"] = pd.to_numeric(ipca["indice"], errors="coerce")
ipca["ano"] = ipca["mes"].str[:4].astype(int)

# 2) Média anual do índice e fator para levar a preços de 2025
ipca_anual = ipca.groupby("ano").agg(meses=("indice", "count"), ipca_medio=("indice", "mean"))
ipca_anual["fator_2025"] = ipca_anual.loc[ANO_BASE, "ipca_medio"] / ipca_anual["ipca_medio"]

# Confere: todo ano precisa ter 12 meses, senão a média está incompleta
incompletos = ipca_anual[ipca_anual["meses"] != 12]
if len(incompletos):
    print("ATENÇÃO: anos com menos de 12 meses de IPCA:", list(incompletos.index))
print("\nIPCA médio anual e fator de correção (preços de 2025):")
print(ipca_anual.round(4))

# %%
# 3) Aplica o fator às colunas monetárias do painel
painel = pd.read_parquet("painel_final_eleicoes_receitas.parquet")

# Colunas em R$ nominais. CONFIRA E COMPLETE com as colunas de despesa do seu painel
# (use print(list(painel.columns)) para ver os nomes).
# Coloque só valores TOTAIS (não per capita): o per capita é recalculado abaixo.
# Não inclua pib_per_capita nem *_pc; eles serão substituídos por pib_real_pc etc.
COLUNAS_MONETARIAS = [
    "receita_tributaria",
    "transf_correntes",
    "pib",
    "valor"
]

faltando = [c for c in COLUNAS_MONETARIAS if c not in painel.columns]
if faltando:
    print("Colunas não encontradas no painel (corrija a lista):", faltando)
    print("Colunas disponíveis:", list(painel.columns))

painel = painel.merge(ipca_anual[["fator_2025"]], left_on="ano", right_index=True, how="left")
print(f"\nLinhas sem fator de IPCA: {painel['fator_2025'].isna().sum()}  (tem que ser 0)")

for col in COLUNAS_MONETARIAS:
    if col in painel.columns:
        painel[f"{col}_real"] = painel[col] * painel["fator_2025"]

# 4) Per capita e logs a partir dos valores reais
#    (dividir pela população antes ou depois de deflacionar dá o mesmo resultado;
#     o que importa é tirar o log só no final, sobre o valor real)
def log_seguro(x):
    """log natural; zero ou negativo vira vazio (NaN) em vez de -infinito."""
    return np.log(x.where(x > 0))

if "populacao" in painel.columns:
    for col in COLUNAS_MONETARIAS:
        if f"{col}_real" in painel.columns:
            painel[f"{col}_real_pc"] = painel[f"{col}_real"] / painel["populacao"]
            painel[f"ln_{col}_real_pc"] = log_seguro(painel[f"{col}_real_pc"])
    if "pib_real" in painel.columns:
        painel["ln_pib_real"] = log_seguro(painel["pib_real"])
else:
    print("Coluna 'populacao' não encontrada: per capita e logs não foram criados.")

# 5) Conferência rápida: médias nominal x real por ano
for col in [c for c in COLUNAS_MONETARIAS if c in painel.columns][:2]:
    print(f"\nMédia por ano de {col}: nominal x real (R$ de {ANO_BASE})")
    print(painel.groupby("ano")[[col, f"{col}_real"]].mean().round(0))

painel.to_parquet("painel_final_real.parquet", index=False)
print("\nSalvo: painel_final_real.parquet")

# %%
