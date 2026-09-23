# %%
# ==============================================================================
# CÉLULA 1: EXTRAÇÃO E LIMPEZA DA BASE FINANCEIRA (SICONFI)
# ==============================================================================
import basedosdados as bd
import pandas as pd
import numpy as np
import os

caminho_arquivo = "base_siconfi_despesas.parquet"

if os.path.exists(caminho_arquivo):
    df = pd.read_parquet(caminho_arquivo)
    print("Base do Siconfi carregada do arquivo local com sucesso!")
else:
    print("Iniciando download do Siconfi via Base dos Dados...")
    query = """
    SELECT
        dados.ano as ano,
        dados.sigla_uf AS sigla_uf,
        diretorio_sigla_uf.nome AS sigla_uf_nome,
        dados.id_municipio AS id_municipio,
        diretorio_id_municipio.nome AS id_municipio_nome,
        dados.estagio as estagio,
        dados.portaria as portaria,
        dados.conta as conta,
        dados.estagio_bd as estagio_bd,
        dados.id_conta_bd as id_conta_bd,
        dados.conta_bd as conta_bd,
        dados.valor as valor
    FROM `basedosdados.br_me_siconfi.municipio_despesas_funcao` AS dados
    LEFT JOIN (SELECT DISTINCT sigla,nome FROM `basedosdados.br_bd_diretorios_brasil.uf`) AS diretorio_sigla_uf
        ON dados.sigla_uf = diretorio_sigla_uf.sigla
    LEFT JOIN (SELECT DISTINCT id_municipio,nome FROM `basedosdados.br_bd_diretorios_brasil.municipio`) AS diretorio_id_municipio
        ON dados.id_municipio = diretorio_id_municipio.id_municipio
    WHERE dados.estagio = 'Despesas Pagas'
    """
    df = bd.read_sql(query=query, billing_project_id="monografia-508123")
    df.to_parquet(caminho_arquivo, index=False)
    print("Download do Siconfi concluído e salvo localmente!")

# Retira Despesas Intraorçamentárias
df_final = df[df['conta_bd'] != 'Despesas Intraorçamentárias']

# Vamos chamar nosso DataFrame principal de df_painel a partir daqui
df_painel = df_final.copy()


# %%
# ==============================================================================
# CÉLULA 2: PARTIDO DOS PREFEITOS E STATUS DE REELEIÇÃO
# ==============================================================================
caminho_prefeitos = "base_prefeitos.parquet"

if os.path.exists(caminho_prefeitos):
    df_prefeitos = pd.read_parquet(caminho_prefeitos)
    print("Dados dos prefeitos carregados do arquivo local!")
else:
    print("Baixando dados dos Prefeitos...")
    query_prefeitos = """
    SELECT 
        ano AS ano_eleicao_municipal, 
        id_municipio, 
        sigla_partido AS partido_prefeito,
        titulo_eleitoral_candidato
    FROM `basedosdados.br_tse_eleicoes.resultados_candidato`
    WHERE cargo = 'prefeito' AND resultado = 'eleito' AND ano IN (2008, 2012, 2016, 2020, 2024)
    """
    df_prefeitos = bd.read_sql(query=query_prefeitos, billing_project_id="monografia-508123")
    df_prefeitos.to_parquet(caminho_prefeitos, index=False)

# 1. Ordena cronologicamente
df_prefeitos = df_prefeitos.sort_values(by=['id_municipio', 'ano_eleicao_municipal'])

# 2. Puxa o título de eleitor do vencedor da eleição anterior
df_prefeitos['id_prefeito_anterior'] = df_prefeitos.groupby('id_municipio')['titulo_eleitoral_candidato'].shift(1)

# 3. Cria a dummy: se o título atual for igual ao anterior, é Segundo Mandato (1).
df_prefeitos['segundo_mandato'] = (df_prefeitos['titulo_eleitoral_candidato'] == df_prefeitos['id_prefeito_anterior']).astype(int)

# Mapeia qual eleição vale para qual ano financeiro (2008 ignorado no merge)
mapeamento_mun = pd.DataFrame({
    'ano': [2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025],
    'ano_eleicao_municipal': [2012, 2012, 2012, 2012, 2016, 2016, 2016, 2016, 2020, 2020, 2020, 2020, 2024]
})

# Junta no painel
df_painel = pd.merge(df_painel, mapeamento_mun, on='ano', how='left')
df_painel = pd.merge(df_painel, df_prefeitos, on=['ano_eleicao_municipal', 'id_municipio'], how='left')

# Limpa colunas auxiliares do título de eleitor para manter o painel enxuto
df_painel = df_painel.drop(columns=['titulo_eleitoral_candidato', 'id_prefeito_anterior'])

# %%
# ==============================================================================
# CÉLULA 3: COLIGAÇÕES E ALINHAMENTO COM GOVERNADOR/PRESIDENTE
# ==============================================================================
print("Verificando cache de Governadores e Presidentes...")
caminho_gov_pres = "base_gov_pres.parquet"

if os.path.exists(caminho_gov_pres):
    df_gov_pres = pd.read_parquet(caminho_gov_pres)
    print("Dados de Governadores e Presidentes carregados do arquivo local!")
else:
    print("Baixando dados de Governadores e Presidentes via Base dos Dados...")
    query_gov_pres = """
    SELECT 
        r.ano AS ano_eleicao_geral, 
        r.sigla_uf, 
        r.cargo, 
        MAX(p.composicao_coligacao) AS composicao_coligacao
    FROM `basedosdados.br_tse_eleicoes.resultados_candidato` AS r
    INNER JOIN `basedosdados.br_tse_eleicoes.partidos` AS p
        ON r.ano = p.ano 
        AND r.cargo = p.cargo
        AND r.sigla_partido = p.sigla
        AND IFNULL(r.sigla_uf, 'BR') = IFNULL(p.sigla_uf, 'BR')
    WHERE r.cargo IN ('governador', 'presidente') 
      AND r.resultado = 'eleito' 
      AND r.ano IN (2010, 2014, 2018, 2022)
    GROUP BY 
        r.ano, 
        r.sigla_uf, 
        r.cargo
    """
    df_gov_pres = bd.read_sql(query=query_gov_pres, billing_project_id="monografia-508123")
    df_gov_pres.to_parquet(caminho_gov_pres, index=False)
    print("Download concluído e salvo localmente!")

# Separa Governador (precisa de sigla_uf) e Presidente (nacional)
df_gov = df_gov_pres[df_gov_pres['cargo'] == 'governador'].drop(columns=['cargo'])
df_gov = df_gov.rename(columns={'composicao_coligacao': 'coligacao_gov'})

df_pres = df_gov_pres[df_gov_pres['cargo'] == 'presidente'].drop(columns=['cargo', 'sigla_uf'])
df_pres = df_pres.rename(columns={'composicao_coligacao': 'coligacao_pres'})

# Mapeia qual eleição geral vale para qual ano financeiro
mapeamento_geral = pd.DataFrame({
    'ano': [2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025],
    'ano_eleicao_geral': [2010, 2010, 2014, 2014, 2014, 2014, 2018, 2018, 2018, 2018, 2022, 2022, 2022]
})

# Junta as tabelas no painel principal
df_painel = pd.merge(df_painel, mapeamento_geral, on='ano', how='left')
df_painel = pd.merge(df_painel, df_gov, on=['ano_eleicao_geral', 'sigla_uf'], how='left')
df_painel = pd.merge(df_painel, df_pres, on='ano_eleicao_geral', how='left')

# Cria esta função antes das validações
def verifica_alianca(partido, coligacao):
    if pd.isnull(partido) or pd.isnull(coligacao):
        return 0
    
    # Separa a string da coligação usando a barra e remove espaços em branco (strip)
    lista_partidos = [p.strip() for p in str(coligacao).split('/')]
    
    # Verifica a correspondência exata na lista
    return 1 if str(partido).strip() in lista_partidos else 0

# Aplica a nova função no painel
df_painel['coalizao_gov'] = df_painel.apply(
    lambda row: verifica_alianca(row['partido_prefeito'], row['coligacao_gov']), 
    axis=1
)

df_painel['coalizao_pres'] = df_painel.apply(
    lambda row: verifica_alianca(row['partido_prefeito'], row['coligacao_pres']), 
    axis=1
)

# %%
# ==============================================================================
# CÉLULA 4: CONTROLES ECONÔMICOS (PIB E POPULAÇÃO) - FREQUÊNCIA ANUAL
# ==============================================================================
print("Verificando cache dos dados anuais do IBGE...")
caminho_ibge_anual = "base_ibge_anual.parquet"

if os.path.exists(caminho_ibge_anual):
    df_ibge_anual = pd.read_parquet(caminho_ibge_anual)
    print("Dados do IBGE carregados do arquivo local!")
else:
    print("Baixando PIB e População via Base dos Dados...")
    query_ibge = """
    SELECT 
        p.ano, 
        p.id_municipio, 
        p.pib, 
        pop.populacao
    FROM `basedosdados.br_ibge_pib.municipio` p
    INNER JOIN `basedosdados.br_ibge_populacao.municipio` pop
        ON p.ano = pop.ano AND p.id_municipio = pop.id_municipio
    """
    df_ibge_anual = bd.read_sql(query=query_ibge, billing_project_id="monografia-508123")
    df_ibge_anual.to_parquet(caminho_ibge_anual, index=False)
    print("Download do IBGE concluído!")

# Calcula o PIB per capita
df_ibge_anual['pib_per_capita'] = df_ibge_anual['pib'] / df_ibge_anual['populacao']

# Junta no painel
df_painel = pd.merge(df_painel, df_ibge_anual, on=['ano', 'id_municipio'], how='left')


# %%
# ==============================================================================
# CÉLULA 5: DADOS DOS CENSOS 2010 E 2022 (SIDRA - IBGE)
# ==============================================================================
print("Processando dados estruturais dos Censos 2010 e 2022...")

# ---------------------------------------------------------
# 1. Urbanização 2022 (Formato Largo)
# ---------------------------------------------------------
df_urb_2022 = pd.read_csv('tabela9923.csv', sep=';', dtype={'id_municipio': str})

# Força a conversão de texto para número antes do cálculo
df_urb_2022['Urbana'] = pd.to_numeric(df_urb_2022['Urbana'], errors='coerce')
df_urb_2022['Total'] = pd.to_numeric(df_urb_2022['Total'], errors='coerce')

df_urb_2022['grau_urb_2022'] = df_urb_2022['Urbana'] / df_urb_2022['Total']
df_urb_2022_clean = df_urb_2022[['id_municipio', 'grau_urb_2022']]

# ---------------------------------------------------------
# 2. Urbanização 2010 (Formato Longo)
# ---------------------------------------------------------
df_urb_2010 = pd.read_csv('tabela202.csv', sep=';', dtype={'id_municipio': str})
df_urb_2010_pivot = df_urb_2010.pivot(index='id_municipio', columns='Situação do domicílio', values='Total').reset_index()

# Força a conversão de texto para número antes do cálculo
df_urb_2010_pivot['Urbana'] = pd.to_numeric(df_urb_2010_pivot['Urbana'], errors='coerce')
df_urb_2010_pivot['Total'] = pd.to_numeric(df_urb_2010_pivot['Total'], errors='coerce')

df_urb_2010_pivot['grau_urb_2010'] = df_urb_2010_pivot['Urbana'] / df_urb_2010_pivot['Total']
df_urb_2010_clean = df_urb_2010_pivot[['id_municipio', 'grau_urb_2010']]

# ---------------------------------------------------------
# Definição das faixas etárias para as tabelas de Idade
# ---------------------------------------------------------
jovens = ['0 a 4 anos', '5 a 9 anos', '10 a 14 anos', '15 a 19 anos', '20 a 24 anos']
idosos = ['65 a 69 anos', '70 a 74 anos', '75 a 79 anos', '80 a 84 anos', '85 a 89 anos', '90 a 94 anos', '95 a 99 anos', '100 anos ou mais']

# ---------------------------------------------------------
# 3. Idade 2022 (Formato Largo)
# ---------------------------------------------------------
df_idade_2022 = pd.read_csv('tabela9514.csv', sep=';', dtype={'id_municipio': str})
# Substitui o "-" do IBGE por "0" e converte todas as colunas necessárias para número
for col in jovens + idosos + ['Total']:
    df_idade_2022[col] = pd.to_numeric(df_idade_2022[col].astype(str).str.replace('-', '0'), errors='coerce')

df_idade_2022['perc_jovens_2022'] = df_idade_2022[jovens].sum(axis=1) / df_idade_2022['Total']
df_idade_2022['perc_idosos_2022'] = df_idade_2022[idosos].sum(axis=1) / df_idade_2022['Total']
df_idade_2022_clean = df_idade_2022[['id_municipio', 'perc_jovens_2022', 'perc_idosos_2022']]

# ---------------------------------------------------------
# 4. Idade 2010 (Formato Longo)
# ---------------------------------------------------------
df_idade_2010 = pd.read_csv('tabela200.csv', sep=';', dtype={'id_municipio': str})
df_idade_2010['Total'] = pd.to_numeric(df_idade_2010['Total'].astype(str).str.replace('-', '0'), errors='coerce')

# Isola os totais gerais de cada município
df_totais_2010 = df_idade_2010[df_idade_2010['Grupo de idade'] == 'Total'][['id_municipio', 'Total']].rename(columns={'Total': 'pop_total'})

# Agrupa e soma as linhas que correspondem aos jovens e aos idosos
df_jovens_2010 = df_idade_2010[df_idade_2010['Grupo de idade'].isin(jovens)].groupby('id_municipio')['Total'].sum().reset_index(name='jovens')
df_idosos_2010 = df_idade_2010[df_idade_2010['Grupo de idade'].isin(idosos)].groupby('id_municipio')['Total'].sum().reset_index(name='idosos')

# Une as contagens e calcula as percentagens de 2010
df_idade_2010_clean = df_totais_2010.merge(df_jovens_2010, on='id_municipio').merge(df_idosos_2010, on='id_municipio')
df_idade_2010_clean['perc_jovens_2010'] = df_idade_2010_clean['jovens'] / df_idade_2010_clean['pop_total']
df_idade_2010_clean['perc_idosos_2010'] = df_idade_2010_clean['idosos'] / df_idade_2010_clean['pop_total']
df_idade_2010_clean = df_idade_2010_clean[['id_municipio', 'perc_jovens_2010', 'perc_idosos_2010']]

# ---------------------------------------------------------
# 5. Consolidação e Interpolação Anual (2010 a 2025)
# ---------------------------------------------------------
# Padroniza os dados de 2010 e insere a marcação de tempo
df_2010 = df_urb_2010_clean.merge(df_idade_2010_clean, on='id_municipio')
df_2010['ano'] = 2010
df_2010 = df_2010.rename(columns={
    'grau_urb_2010': 'grau_urb', 
    'perc_jovens_2010': 'perc_jovens', 
    'perc_idosos_2010': 'perc_idosos'
})

# Padroniza os dados de 2022 e insere a marcação de tempo
df_2022 = df_urb_2022_clean.merge(df_idade_2022_clean, on='id_municipio')
df_2022['ano'] = 2022
df_2022 = df_2022.rename(columns={
    'grau_urb_2022': 'grau_urb', 
    'perc_jovens_2022': 'perc_jovens', 
    'perc_idosos_2022': 'perc_idosos'
})

# Empilha os dois censos verticalmente
df_censo_base = pd.concat([df_2010, df_2022], ignore_index=True)

# Cria um grid temporal exaustivo para todos os municípios (de 2010 até 2025)
municipios_unicos = df_censo_base['id_municipio'].unique()
anos_completos = range(2010, 2026) 
grid_censo = pd.MultiIndex.from_product(
    [municipios_unicos, anos_completos], 
    names=['id_municipio', 'ano']
).to_frame(index=False)

# Encaixa os dados conhecidos (2010 e 2022) no grid. Os outros anos ficarão como NaN
df_censo_anual = grid_censo.merge(df_censo_base, on=['id_municipio', 'ano'], how='left')

# Ordenação rigorosa para que a matemática linear respeite a seta do tempo
df_censo_anual = df_censo_anual.sort_values(by=['id_municipio', 'ano'])

# Aplica a interpolação linear (preenchendo 2011-2021) seguida do Forward Fill (preenchendo 2023-2025)
colunas_demograficas = ['grau_urb', 'perc_jovens', 'perc_idosos']
df_censo_anual[colunas_demograficas] = df_censo_anual.groupby('id_municipio')[colunas_demograficas].transform(
    lambda x: x.interpolate(method='linear').ffill()
)

# Junta a malha anual completa ao painel de finanças/eleições
df_painel = df_painel.merge(df_censo_anual, on=['id_municipio', 'ano'], how='left')

# ==============================================================================
# SALVAMENTO 
# ==============================================================================
df_painel.to_parquet("painel_final_eleicoes.parquet", index=False)
print("Painel final gerado com sucesso!")

# Exibição rápida no terminal/notebook
print(df_painel[['ano', 'sigla_uf', 'id_municipio_nome', 'partido_prefeito', 'coalizao_gov', 'coalizao_pres']].head(20))