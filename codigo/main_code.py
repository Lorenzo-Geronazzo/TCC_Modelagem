# %%
# ==============================================================================
# CÉLULA 1: EXTRAÇÃO E LIMPEZA DA BASE FINANCEIRA (SICONFI)
# ==============================================================================
import basedosdados as bd
import pandas as pd
import numpy as np
import os

# Caminhos dos arquivos do projeto (ver codigo/caminhos.py).
# Procura a pasta codigo/ subindo a partir da pasta atual, para funcionar
# tanto no terminal (raiz do projeto) quanto nas células do VS Code.
import sys
from pathlib import Path
for _pasta in [Path.cwd(), *Path.cwd().parents]:
    if (_pasta / "codigo" / "caminhos.py").exists():
        sys.path.insert(0, str(_pasta / "codigo"))
        break
from caminhos import SICONFI_DESPESAS, PREFEITOS, GOV_PRES, GOV_PRES_2010, IBGE_ANUAL, URB_2022, URB_2010, IDADE_2022, IDADE_2010, PAINEL_ELEICOES

caminho_arquivo = SICONFI_DESPESAS

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
# Essas linhas não têm código (id_conta_bd e portaria vazios), então o filtro é pelo
# nome, que muda de grafia: "Despesas (Intra-Orçamentárias)" em 2013 e
# "Despesas Intraorçamentárias" de 2014 em diante. Tira acentos e caixa, e procura
# "intra" sem "exceto" (as linhas "Despesas Exceto Intraorçamentárias" são o total
# SEM as intra e devem ficar).
nome_conta = df['conta_bd'].str.normalize('NFKD').str.encode('ascii', 'ignore').str.decode('ascii').str.lower()
eh_intra = nome_conta.str.contains('intra') & ~nome_conta.str.contains('exceto')
print(f"Linhas intraorçamentárias removidas: {eh_intra.sum()}")
df_final = df[~eh_intra]

# Vamos chamar nosso DataFrame principal de df_painel a partir daqui
df_painel = df_final.copy()


# %%
# ==============================================================================
# CÉLULA 2: PARTIDO DOS PREFEITOS E STATUS DE REELEIÇÃO
# ==============================================================================
# v2: inclui tipo e data da eleição, para tratar as eleições suplementares.
# A Base dos Dados registra a suplementar sob o ano da ordinária (ex.: suplementar
# de fev/2023 aparece com ano 2020), então um município-eleição pode ter mais de
# um "eleito": no máximo 1 ordinária + 0 a 2 suplementares.
# v3: traz também título, CPF e nome da tabela de candidatos (ligada pelo
# sequencial do candidato), para identificar o prefeito quando o título falta.
caminho_prefeitos = PREFEITOS

if os.path.exists(caminho_prefeitos):
    df_prefeitos = pd.read_parquet(caminho_prefeitos)
    print("Dados dos prefeitos carregados do arquivo local!")
else:
    print("Baixando dados dos Prefeitos...")
    query_prefeitos = """
    SELECT
        r.ano AS ano_eleicao_municipal,
        r.id_municipio,
        r.tipo_eleicao,
        CAST(r.data_eleicao AS STRING) AS data_eleicao,
        r.sigla_partido AS partido_prefeito,
        NULLIF(TRIM(r.titulo_eleitoral_candidato), '') AS titulo_eleitoral_candidato,
        NULLIF(TRIM(c.titulo_eleitoral), '') AS titulo_eleitoral_cand,
        NULLIF(TRIM(c.cpf), '') AS cpf,
        r.nome_candidato
    FROM `basedosdados.br_tse_eleicoes.resultados_candidato` AS r
    LEFT JOIN `basedosdados.br_tse_eleicoes.candidatos` AS c
        ON c.ano = r.ano
        AND c.id_municipio = r.id_municipio
        AND c.cargo = 'prefeito'
        AND c.sequencial = r.sequencial_candidato
    WHERE r.cargo = 'prefeito' AND r.resultado = 'eleito' AND r.ano IN (2008, 2012, 2016, 2020, 2024)
    """
    df_prefeitos = bd.read_sql(query=query_prefeitos, billing_project_id="monografia-508123")
    df_prefeitos.to_parquet(caminho_prefeitos, index=False)

# Confere: o JOIN com candidatos não pode repetir eleitos
print(f"Eleitos: {len(df_prefeitos)}  (eram 28185 sem o JOIN; têm que ser iguais)")

# Título completo: o de resultados_candidato; se faltar, o da tabela de candidatos
df_prefeitos['titulo_eleitoral_candidato'] = df_prefeitos['titulo_eleitoral_candidato'].fillna(df_prefeitos['titulo_eleitoral_cand'])

# Nome padronizado (sem acento, maiúsculas, espaços simples), usado só quando falta título
df_prefeitos['nome_padronizado'] = (
    df_prefeitos['nome_candidato'].fillna('')
    .str.normalize('NFKD').str.encode('ascii', 'ignore').str.decode('ascii')
    .str.upper().str.split().str.join(' ')
    .replace('', np.nan)
)

df_prefeitos['data_eleicao'] = pd.to_datetime(df_prefeitos['data_eleicao'])
df_prefeitos['prefeito_suplementar'] = (df_prefeitos['tipo_eleicao'] != 'eleicao ordinaria').astype(int)

# 1. Data em que cada eleito assume:
#    ordinária -> 1º de janeiro do ano seguinte à eleição;
#    suplementar -> data da eleição suplementar (aproximação: a posse costuma vir
#    poucas semanas depois), nunca antes daquele 1º de janeiro.
posse_ordinaria = pd.to_datetime((df_prefeitos['ano_eleicao_municipal'] + 1).astype(str) + '-01-01')
inicio_suplementar = df_prefeitos['data_eleicao'].where(df_prefeitos['data_eleicao'] > posse_ordinaria, posse_ordinaria)
df_prefeitos['inicio'] = inicio_suplementar.where(df_prefeitos['prefeito_suplementar'] == 1, posse_ordinaria)

# 2. Ordena cronologicamente dentro de cada mandato
#    (empate na data: a suplementar substituiu a ordinária, então vem depois)
df_prefeitos = df_prefeitos.sort_values(by=['id_municipio', 'ano_eleicao_municipal', 'inicio', 'prefeito_suplementar'])

# 3. Segundo Mandato (1): o prefeito é o mesmo que estava no cargo ao fim do
#    mandato anterior (o último a assumir naquele mandato, ordinário ou tampão)
fim_mandato = df_prefeitos.drop_duplicates(['id_municipio', 'ano_eleicao_municipal'], keep='last')
fim_mandato = fim_mandato[['id_municipio', 'ano_eleicao_municipal', 'titulo_eleitoral_candidato', 'cpf', 'nome_padronizado']]
fim_mandato = fim_mandato.rename(columns={'titulo_eleitoral_candidato': 'titulo_anterior',
                                          'cpf': 'cpf_anterior',
                                          'nome_padronizado': 'nome_anterior'})
fim_mandato['ano_eleicao_municipal'] = fim_mandato['ano_eleicao_municipal'] + 4   # vira o "anterior" do mandato seguinte
df_prefeitos = df_prefeitos.merge(fim_mandato, on=['id_municipio', 'ano_eleicao_municipal'], how='left')

# Mesma pessoa se: o título bate, OU o CPF bate, OU (só quando falta o título
# de um dos lados) o nome padronizado bate. Valores vazios nunca contam como iguais.
mesmo_titulo = df_prefeitos['titulo_eleitoral_candidato'].notna() & (df_prefeitos['titulo_eleitoral_candidato'] == df_prefeitos['titulo_anterior'])
mesmo_cpf = df_prefeitos['cpf'].notna() & (df_prefeitos['cpf'] == df_prefeitos['cpf_anterior'])
falta_titulo = df_prefeitos['titulo_eleitoral_candidato'].isna() | df_prefeitos['titulo_anterior'].isna()
mesmo_nome = falta_titulo & df_prefeitos['nome_padronizado'].notna() & (df_prefeitos['nome_padronizado'] == df_prefeitos['nome_anterior'])
df_prefeitos['segundo_mandato'] = (mesmo_titulo | mesmo_cpf | mesmo_nome).astype(int)

# Mapeia qual eleição vale para qual ano financeiro (2008 ignorado no merge)
mapeamento_mun = pd.DataFrame({
    'ano': [2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025],
    'ano_eleicao_municipal': [2012, 2012, 2012, 2012, 2016, 2016, 2016, 2016, 2020, 2020, 2020, 2020, 2024]
})

# 4. Um prefeito por município-ano: o que governou a maior parte do ano,
#    isto é, o último a assumir até 1º de julho daquele ano.
#    Se ninguém do mandato assumiu até essa data (só houve suplementar depois),
#    o município-ano fica sem prefeito (vazio).
df_prefeito_ano = mapeamento_mun.merge(df_prefeitos, on='ano_eleicao_municipal')
meio_do_ano = pd.to_datetime(df_prefeito_ano['ano'].astype(str) + '-07-01')
df_prefeito_ano = df_prefeito_ano[df_prefeito_ano['inicio'] <= meio_do_ano]
df_prefeito_ano = df_prefeito_ano.sort_values(by=['id_municipio', 'ano', 'inicio', 'prefeito_suplementar'])
df_prefeito_ano = df_prefeito_ano.drop_duplicates(['id_municipio', 'ano'], keep='last')
df_prefeito_ano = df_prefeito_ano[['ano', 'id_municipio', 'partido_prefeito', 'segundo_mandato', 'prefeito_suplementar']]

# Junta no painel
df_painel = pd.merge(df_painel, mapeamento_mun, on='ano', how='left')
df_painel = pd.merge(df_painel, df_prefeito_ano, on=['ano', 'id_municipio'], how='left')

# %%
# ==============================================================================
# CÉLULA 3: COLIGAÇÕES E ALINHAMENTO COM GOVERNADOR/PRESIDENTE
# ==============================================================================
print("Verificando cache de Governadores e Presidentes...")
# v2: só eleição ordinária. A Base dos Dados grava as suplementares de governador
# sob o ano da ordinária (AM 2017 e TO 2018 aparecem como 2014); sem o filtro, o
# partido do vencedor da suplementar puxava a coligação que esse partido tinha em
# 2014, e o MAX escolhia entre dois textos (em TO, a chapa derrotada).
# Verificado: a tabela partidos só tem o 1º turno, então o MAX nunca escolhe entre turnos;
# com o filtro há 1 texto por ano/UF/cargo.
caminho_gov_pres = GOV_PRES

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
      AND r.tipo_eleicao = 'eleicao ordinaria'
      AND r.ano IN (2010, 2014, 2018, 2022)
    GROUP BY 
        r.ano, 
        r.sigla_uf, 
        r.cargo
    """
    df_gov_pres = bd.read_sql(query=query_gov_pres, billing_project_id="monografia-508123")
    df_gov_pres.to_parquet(caminho_gov_pres, index=False)
    print("Download concluído e salvo localmente!")

# ------------------------------------------------------------------------------
# Complemento da eleição de 2010
# Na Base dos Dados, a tabela partidos tem composicao_coligacao nula em 2010 e
# não tem linha de presidente em 2010. A composição vem do arquivo oficial do
# TSE (consulta_coligacao_2010); o partido eleito vem de resultados_candidato.
# Validado: para os 27 governadores, a composição do TSE é igual à reconstruída
# pela Base dos Dados (partidos com o mesmo sequencial_coligacao).
# ------------------------------------------------------------------------------
caminho_gov_pres_2010 = GOV_PRES_2010

if os.path.exists(caminho_gov_pres_2010):
    df_gov_pres_2010 = pd.read_parquet(caminho_gov_pres_2010)
    print("Coligações de 2010 carregadas do arquivo local!")
else:
    import io
    import zipfile
    import requests

    # 1) Partido eleito em 2010: governador (resultado = 'eleito') e presidente
    #    (o resultado vem nulo em 2010; o eleito é o mais votado no 2º turno)
    query_eleitos_2010 = """
    SELECT sigla_uf, cargo, sigla_partido
    FROM `basedosdados.br_tse_eleicoes.resultados_candidato`
    WHERE ano = 2010 AND cargo = 'governador' AND resultado = 'eleito'
    UNION ALL
    (SELECT sigla_uf, cargo, sigla_partido
     FROM `basedosdados.br_tse_eleicoes.resultados_candidato`
     WHERE ano = 2010 AND cargo = 'presidente'
     ORDER BY turno DESC, votos DESC
     LIMIT 1)
    """
    df_eleitos_2010 = bd.read_sql(query=query_eleitos_2010, billing_project_id="monografia-508123")

    # 2) Composição das coligações de 2010 (arquivo do TSE, todas as UFs)
    print("Baixando coligações de 2010 do TSE...")
    url_tse = "https://cdn.tse.jus.br/estatistica/sead/odsele/consulta_coligacao/consulta_coligacao_2010.zip"
    resposta = requests.get(url_tse, timeout=120)
    resposta.raise_for_status()
    with zipfile.ZipFile(io.BytesIO(resposta.content)) as arquivo_zip:
        with arquivo_zip.open("consulta_coligacao_2010_BRASIL.csv") as arquivo_csv:
            df_tse_2010 = pd.read_csv(arquivo_csv, sep=';', encoding='latin1', dtype=str)

    df_tse_2010 = df_tse_2010[df_tse_2010['DS_CARGO'].isin(['GOVERNADOR', 'PRESIDENTE'])]
    df_tse_2010 = df_tse_2010.rename(columns={'SG_UF': 'sigla_uf', 'SG_PARTIDO': 'sigla_partido',
                                              'DS_COMPOSICAO_COLIGACAO': 'composicao_coligacao'})
    df_tse_2010['cargo'] = df_tse_2010['DS_CARGO'].str.lower()
    df_tse_2010['sigla_uf'] = df_tse_2010['sigla_uf'].where(df_tse_2010['cargo'] == 'governador')  # presidente: sem UF
    df_tse_2010 = df_tse_2010[['sigla_uf', 'cargo', 'sigla_partido', 'composicao_coligacao']].drop_duplicates()

    # 3) Junta: coligação do partido eleito em cada UF (e no Brasil, para presidente)
    df_gov_pres_2010 = df_eleitos_2010.merge(df_tse_2010, on=['sigla_uf', 'cargo', 'sigla_partido'], how='left')
    df_gov_pres_2010['ano_eleicao_geral'] = 2010
    df_gov_pres_2010 = df_gov_pres_2010[['ano_eleicao_geral', 'sigla_uf', 'cargo', 'composicao_coligacao']]
    df_gov_pres_2010.to_parquet(caminho_gov_pres_2010, index=False)
    print("Coligações de 2010 salvas localmente!")

# Confere: 27 governadores + 1 presidente, todos com coligação
print(f"2010: {len(df_gov_pres_2010)} linhas, {df_gov_pres_2010['composicao_coligacao'].isna().sum()} sem coligação (tem que ser 28 e 0)")

# Troca as linhas de 2010 (nulas) pelas do complemento
df_gov_pres = pd.concat([df_gov_pres[df_gov_pres['ano_eleicao_geral'] != 2010], df_gov_pres_2010], ignore_index=True)

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

# Anos em que, pela regra de 1º de julho, o governador no cargo NÃO era o eleito
# na ordinária (coalizao_gov continua usando a coligação da ordinária; a coluna
# serve para teste de robustez). Datas conferidas em fontes externas:
#   AM: José Melo cassado pelo TSE em 04/05/2017; David Almeida interino de 09/05/2017;
#       Amazonino Mendes (suplementar de ago/2017) toma posse em 04/10/2017 -> 2017 e 2018
#   TO: Marcelo Miranda cassado em 22/03/2018; Mauro Carlesse interino e depois
#       eleito na suplementar de 24/06/2018 -> 2018
anos_governador_suplementar = pd.DataFrame({
    'sigla_uf': ['AM', 'AM', 'TO'],
    'ano': [2017, 2018, 2018],
    'governador_suplementar': [1, 1, 1],
})
df_painel = pd.merge(df_painel, anos_governador_suplementar, on=['sigla_uf', 'ano'], how='left')
df_painel['governador_suplementar'] = df_painel['governador_suplementar'].fillna(0).astype(int)

# ------------------------------------------------------------------------------
# Padronização das siglas partidárias (fonte: TSE, "Fusões, incorporações e
# mudanças de nomenclatura"). Aplicada nos DOIS lados: sigla do prefeito e cada
# sigla da coligação. Ver decisão registrada no CLAUDE.md.
# ------------------------------------------------------------------------------
# (a) Renomeações: mesmo partido com outro nome/sigla. Aplicadas sempre.
RENOMEACOES = {
    'PMDB': 'MDB',
    'PTN': 'PODE',
    'PT do B': 'AVANTE',
    'PEN': 'PATRIOTA',
    'PATRI': 'PATRIOTA',
    'PSDC': 'DC',
    'SD': 'SOLIDARIEDADE',
    'PR': 'PL',
    'PRB': 'REPUBLICANOS',
    'PPS': 'CIDADANIA',
    'PTC': 'AGIR',
    'PMN': 'MOBILIZA',
}

# (b) Fusões e incorporações: sigla antiga -> (sigla nova, ano da fusão).
# Só valem quando o ano da fusão cai entre as duas eleições comparadas.
# Se as duas eleições são anteriores à fusão, os partidos ainda eram
# separados (ex.: DEM e PSL em 2018) e não podem ser tratados como um só.
FUSOES = {
    'PRP': ('PATRIOTA', 2019),
    'PPL': ('PC do B', 2019),
    'PHS': ('PODE', 2019),
    'DEM': ('UNIÃO', 2022),
    'PSL': ('UNIÃO', 2022),
    'PROS': ('SOLIDARIEDADE', 2023),
    'PSC': ('PODE', 2023),
    'PTB': ('PRD', 2023),
    'PATRIOTA': ('PRD', 2023),
}

def padroniza_sigla(sigla, ano_eleicao_municipal, ano_eleicao_geral, usar_fusoes):
    # Tira espaços e os parênteses das federações de 2022, ex.: "(PT" e "PV)"
    sigla = sigla.strip().strip('()').strip()
    ano_min = min(ano_eleicao_municipal, ano_eleicao_geral)
    ano_max = max(ano_eleicao_municipal, ano_eleicao_geral)
    # Repete para resolver cadeias (ex.: PEN -> PATRIOTA -> PRD)
    while True:
        if sigla in RENOMEACOES:
            sigla = RENOMEACOES[sigla]
        elif usar_fusoes and sigla in FUSOES and ano_min < FUSOES[sigla][1] <= ano_max:
            sigla = FUSOES[sigla][0]
        else:
            return sigla

# Cria esta função antes das validações
def verifica_alianca(partido, coligacao, ano_eleicao_municipal, ano_eleicao_geral, usar_fusoes):
    # Sem prefeito no ano (ou sem coligação): alinhamento desconhecido -> vazio, não 0
    if pd.isnull(partido) or pd.isnull(coligacao):
        return np.nan

    # Separa a string da coligação usando a barra e padroniza cada sigla
    lista_partidos = [padroniza_sigla(p, ano_eleicao_municipal, ano_eleicao_geral, usar_fusoes)
                      for p in str(coligacao).split('/')]

    # Verifica a correspondência exata na lista
    partido = padroniza_sigla(str(partido), ano_eleicao_municipal, ano_eleicao_geral, usar_fusoes)
    return 1 if partido in lista_partidos else 0

# Calcula a dummy só nas combinações distintas (o painel tem milhões de linhas)
# e junta de volta no painel
def cria_dummy(df, col_coligacao, usar_fusoes):
    chaves = ['partido_prefeito', col_coligacao, 'ano_eleicao_municipal', 'ano_eleicao_geral']
    combos = df[chaves].drop_duplicates()
    combos['dummy'] = combos.apply(
        lambda row: verifica_alianca(row['partido_prefeito'], row[col_coligacao],
                                     row['ano_eleicao_municipal'], row['ano_eleicao_geral'], usar_fusoes),
        axis=1
    )
    return df[chaves].merge(combos, on=chaves, how='left')['dummy'].to_numpy()

# Versão principal: renomeações + fusões/incorporações
df_painel['coalizao_gov'] = cria_dummy(df_painel, 'coligacao_gov', usar_fusoes=True)
df_painel['coalizao_pres'] = cria_dummy(df_painel, 'coligacao_pres', usar_fusoes=True)

# Robustez: só renomeações (sem fusões/incorporações)
df_painel['coalizao_gov_sem_fusao'] = cria_dummy(df_painel, 'coligacao_gov', usar_fusoes=False)
df_painel['coalizao_pres_sem_fusao'] = cria_dummy(df_painel, 'coligacao_pres', usar_fusoes=False)

# %%
# ==============================================================================
# CÉLULA 4: CONTROLES ECONÔMICOS (PIB E POPULAÇÃO) - FREQUÊNCIA ANUAL
# ==============================================================================
print("Verificando cache dos dados anuais do IBGE...")
caminho_ibge_anual = IBGE_ANUAL

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
df_urb_2022 = pd.read_csv(URB_2022, sep=';', dtype={'id_municipio': str})

# O CSV do SIDRA tem dois blocos (valores absolutos e percentuais, com vírgula) e
# lista também as concentrações urbanas sob o código do município-sede
# (ex.: "Belém/PA" com a população da região). Fica só o bloco absoluto e só as
# linhas de município, cujo nome termina com "(UF)": uma linha por município.
eh_municipio = df_urb_2022['Concentração Urbana e Município'].str.contains(r'\([A-Z]{2}\)$', na=False)
eh_absoluto = ~df_urb_2022['Total'].astype(str).str.contains(',')
df_urb_2022 = df_urb_2022[eh_municipio & eh_absoluto]
print(f"Urbanização 2022: {len(df_urb_2022)} linhas, {df_urb_2022['id_municipio'].nunique()} municípios (têm que ser iguais)")

# Força a conversão de texto para número antes do cálculo
df_urb_2022['Urbana'] = pd.to_numeric(df_urb_2022['Urbana'], errors='coerce')
df_urb_2022['Total'] = pd.to_numeric(df_urb_2022['Total'], errors='coerce')

df_urb_2022['grau_urb_2022'] = df_urb_2022['Urbana'] / df_urb_2022['Total']
df_urb_2022_clean = df_urb_2022[['id_municipio', 'grau_urb_2022']]

# ---------------------------------------------------------
# 2. Urbanização 2010 (Formato Longo)
# ---------------------------------------------------------
df_urb_2010 = pd.read_csv(URB_2010, sep=';', dtype={'id_municipio': str})
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
df_idade_2022 = pd.read_csv(IDADE_2022, sep=';', dtype={'id_municipio': str})
# Substitui o "-" do IBGE por "0" e converte todas as colunas necessárias para número
for col in jovens + idosos + ['Total']:
    df_idade_2022[col] = pd.to_numeric(df_idade_2022[col].astype(str).str.replace('-', '0'), errors='coerce')

df_idade_2022['perc_jovens_2022'] = df_idade_2022[jovens].sum(axis=1) / df_idade_2022['Total']
df_idade_2022['perc_idosos_2022'] = df_idade_2022[idosos].sum(axis=1) / df_idade_2022['Total']
df_idade_2022_clean = df_idade_2022[['id_municipio', 'perc_jovens_2022', 'perc_idosos_2022']]

# ---------------------------------------------------------
# 4. Idade 2010 (Formato Longo)
# ---------------------------------------------------------
df_idade_2010 = pd.read_csv(IDADE_2010, sep=';', dtype={'id_municipio': str})
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
# Confere: os merges não podem duplicar linhas da base do Siconfi
print(f"Linhas do painel: {len(df_painel)} | linhas do Siconfi: {len(df_final)}  (têm que ser iguais)")

df_painel.to_parquet(PAINEL_ELEICOES, index=False)
print("Painel final gerado com sucesso!")

# Exibição rápida no terminal/notebook
print(df_painel[['ano', 'sigla_uf', 'id_municipio_nome', 'partido_prefeito', 'coalizao_gov', 'coalizao_pres']].head(20))