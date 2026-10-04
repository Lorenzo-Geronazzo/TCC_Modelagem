# %%
# TESTE DE TODAS AS CONTAS MÃES DE UMA VEZ, POR MUNICÍPIO E ANO
# Pergunta: em cada município-ano, cada conta mãe é igual à soma das suas filhas diretas?
# Usa só a coluna id_conta_bd. Linhas sem id_conta_bd (nulo ou vazio) ficam de fora.
import basedosdados as bd
import pandas as pd
import os

ESTAGIO = "Receitas Brutas Realizadas"
ANO_INICIAL = 2013

# %%
# 1) Baixa todas as contas com id_conta_bd desse estágio, somadas por município-ano-conta
caminho = "teste_todas_maes.parquet"
if os.path.exists(caminho):
    df = pd.read_parquet(caminho)
    print("Carregado do arquivo local!")
else:
    query = f"""
    SELECT ano, id_municipio, id_conta_bd, SUM(valor) AS valor
    FROM `basedosdados.br_me_siconfi.municipio_receitas_orcamentarias`
    WHERE ano >= {ANO_INICIAL}
      AND estagio_bd = '{ESTAGIO}'
      AND id_conta_bd IS NOT NULL
      AND TRIM(id_conta_bd) != ''
    GROUP BY ano, id_municipio, id_conta_bd
    """
    df = bd.read_sql(query=query, billing_project_id="monografia-508123")
    df.to_parquet(caminho, index=False)
    print("Baixado e salvo localmente!")

# Remove id_conta_bd vazio (caso o cache antigo ainda tenha essas linhas)
vazios = df["id_conta_bd"].isna() | (df["id_conta_bd"].str.strip() == "")
print(f"Linhas com id_conta_bd vazio removidas: {vazios.sum()}")
df = df[~vazios].copy()

# %%
# 2) Para cada conta, descobre a mãe: zera o último bloco diferente de zero
#    ex.: 1.1.1.2.0.00.00.00 -> mãe 1.1.1.0.0.00.00.00
def mae_de(codigo):
    blocos = codigo.split(".")
    nao_zeros = [i for i, x in enumerate(blocos) if int(x) != 0]
    if len(nao_zeros) <= 1:          # 1.0.0.0... é o topo, não tem mãe
        return None
    i = nao_zeros[-1]
    blocos[i] = "0" * len(blocos[i])
    return ".".join(blocos)

codigos = pd.Series(df["id_conta_bd"].unique())
mapa_mae = dict(zip(codigos, codigos.map(mae_de)))
df["mae"] = df["id_conta_bd"].map(mapa_mae)

# %%
# 3) Soma das filhas, por município-ano-mãe, e compara com o valor da própria mãe
soma_filhas = (df[df["mae"].notna()]
               .groupby(["ano", "id_municipio", "mae"], as_index=False)["valor"].sum()
               .rename(columns={"valor": "soma_filhas"}))

valor_mae = df[["ano", "id_municipio", "id_conta_bd", "valor"]].rename(
    columns={"id_conta_bd": "mae", "valor": "valor_mae"})

# inner = só mães que existem na base e têm pelo menos uma filha naquele município-ano
r = valor_mae.merge(soma_filhas, on=["ano", "id_municipio", "mae"], how="inner")
r["diferenca"] = r["valor_mae"] - r["soma_filhas"]
r["bate"] = r["diferenca"].abs() < 1                            # diferença menor que R$ 1

# %%
# 4) Resumo: uma linha por conta mãe
pd.set_option("display.width", 250)
pd.set_option("display.max_rows", 200)
pd.set_option("display.float_format", "{:,.2f}".format)

resumo = r.groupby("mae").agg(
    municipio_anos=("bate", "size"),
    batem=("bate", "sum"),
    maior_diferenca=("diferenca", lambda x: x.abs().max()),
)
resumo["%_batem"] = resumo["batem"] / resumo["municipio_anos"] * 100
resumo["n_filhas"] = df[df["mae"].notna()].groupby("mae")["id_conta_bd"].nunique()
print(resumo.sort_index())

# Contas cuja mãe calculada não existe na base (filhas "órfãs", não entram no teste)
orfas = sorted(c for c, m in mapa_mae.items() if pd.notna(m) and m not in mapa_mae)
print(f"\nContas cuja mãe não existe na base ({len(orfas)}):")
for c in orfas:
    print("  ", c, "-> mãe esperada", mapa_mae[c])

# Salva tudo que não bate para abrir no Excel
r[~r["bate"]].to_csv("nao_batem_todas_maes.csv", index=False, sep=";", decimal=",", encoding="utf-8-sig")
resumo.to_csv("resumo_todas_maes.csv", sep=";", decimal=",", encoding="utf-8-sig")
print("\nSalvos: resumo_todas_maes.csv e nao_batem_todas_maes.csv")

# %%
# 5) HIPÓTESE PARA A RECEITA TRIBUTÁRIA (1.1.1.0.0.00.00.00)
#    A filha "Contribuição de Melhoria" não tem id_conta_bd, então ficou fora da soma das filhas.
#    Se somarmos ela às filhas, a mãe passa a bater?
#    Filtra pelo CÓDIGO da linha total (coluna portaria), não pelo nome: a partir de 2019
#    existem mais de uma linha chamada "Contribuição de Melhoria" no mesmo ano
#    (2019-21: 1.1.3.0.00.1.0; 2022+: 1.1.3.1.00.0.0), e somar todas contava em dobro.
#    2013-2017 usam o código 1.1.3.0.00.00.00; 2018 em diante, 1.1.3.0.00.0.0.
caminho_cm = "contribuicao_melhoria_v2.parquet"
if os.path.exists(caminho_cm):
    cm = pd.read_parquet(caminho_cm)
    print("Contribuição de Melhoria carregada do arquivo local!")
else:
    query_cm = f"""
    SELECT ano, id_municipio, SUM(valor) AS contrib_melhoria
    FROM `basedosdados.br_me_siconfi.municipio_receitas_orcamentarias`
    WHERE ano >= {ANO_INICIAL}
      AND estagio_bd = '{ESTAGIO}'
      AND portaria IN ('1.1.3.0.00.00.00', '1.1.3.0.00.0.0')
    GROUP BY ano, id_municipio
    """
    cm = bd.read_sql(query=query_cm, billing_project_id="monografia-508123")
    cm.to_parquet(caminho_cm, index=False)
    print("Contribuição de Melhoria baixada e salva localmente!")

trib = r[r["mae"] == "1.1.1.0.0.00.00.00"].merge(cm, on=["ano", "id_municipio"], how="left")
trib["contrib_melhoria"] = trib["contrib_melhoria"].fillna(0)
trib["sobra"] = trib["diferenca"] - trib["contrib_melhoria"]
trib["bate_com_cm"] = trib["sobra"].abs() < 1

print(f"\nReceita tributária - município-anos testados: {len(trib)}")
print(f"Batem só com Impostos + Taxas:                    {trib['bate'].mean():.2%}")
print(f"Batem com Impostos + Taxas + Contrib. de Melhoria: {trib['bate_com_cm'].mean():.2%}")

print("\nPor ano (% que batem com a Contribuição de Melhoria):")
print((trib.groupby("ano")["bate_com_cm"].mean() * 100).round(2))

# Casos que ainda não batem, para abrir no Excel
trib[~trib["bate_com_cm"]].to_csv("trib_ainda_nao_batem.csv", index=False,
                                  sep=";", decimal=",", encoding="utf-8-sig")
print("\nCasos que ainda não batem salvos em trib_ainda_nao_batem.csv")

# %%
# 6) TESTE DAS TRANSFERÊNCIAS CORRENTES (1.1.7.0.0.00.00.00)
#    As filhas diretas não têm id_conta_bd, então são buscadas pelo CÓDIGO original (coluna portaria):
#    1.7.X.0.00.00.00 (2013-2017) ou 1.7.X.0.00.0.0 (2018 em diante), com X de 1 a 9.
#    O filtro exige zeros depois do X, então netas (ex.: 1.7.2.1...) ficam de fora.
caminho_tc = "transferencias_filhas.parquet"
if os.path.exists(caminho_tc):
    tc = pd.read_parquet(caminho_tc)
    print("Filhas das Transferências Correntes carregadas do arquivo local!")
else:
    query_tc = f"""
    SELECT ano, id_municipio, portaria, conta, SUM(valor) AS valor
    FROM `basedosdados.br_me_siconfi.municipio_receitas_orcamentarias`
    WHERE ano >= {ANO_INICIAL}
      AND estagio_bd = '{ESTAGIO}'
      AND REGEXP_CONTAINS(portaria, r'^1\\.7\\.[1-9]\\.0\\.00\\.0{{1,2}}\\.0{{1,2}}$')
    GROUP BY ano, id_municipio, portaria, conta
    """
    tc = bd.read_sql(query=query_tc, billing_project_id="monografia-508123")
    tc.to_parquet(caminho_tc, index=False)
    print("Filhas das Transferências Correntes baixadas e salvas localmente!")

# Mostra quais filhas foram encontradas em cada ano (para conferir no olho)
print("\nFilhas encontradas por ano:")
print(tc.groupby(["ano", "portaria", "conta"])["id_municipio"].nunique()
        .rename("municipios").reset_index().to_string(index=False))

# Valor da mãe (pelo id_conta_bd, que é o que vai para o painel) x soma das filhas
mae_tc = (df[df["id_conta_bd"] == "1.1.7.0.0.00.00.00"]
          [["ano", "id_municipio", "valor"]].rename(columns={"valor": "valor_mae"}))
filhas_tc = (tc.groupby(["ano", "id_municipio"], as_index=False)["valor"].sum()
               .rename(columns={"valor": "soma_filhas"}))

transf = mae_tc.merge(filhas_tc, on=["ano", "id_municipio"], how="left")
transf["soma_filhas"] = transf["soma_filhas"].fillna(0)
transf["diferenca"] = transf["valor_mae"] - transf["soma_filhas"]
transf["bate"] = transf["diferenca"].abs() < 1

print(f"\nTransferências Correntes - município-anos testados: {len(transf)}")
print(f"Batem (diferença < R$ 1): {transf['bate'].mean():.2%}")

print("\nPor ano (% que batem):")
print((transf.groupby("ano")["bate"].mean() * 100).round(2))

transf[~transf["bate"]].to_csv("transf_nao_batem.csv", index=False,
                               sep=";", decimal=",", encoding="utf-8-sig")
print("\nCasos que não batem salvos em transf_nao_batem.csv")