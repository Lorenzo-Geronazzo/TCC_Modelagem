# %%
# ==============================================================================
# EXPLORAÇÃO DAS CONTAS DE DESPESA (SICONFI, ANEXO 1-E, DESPESAS PAGAS)
# ==============================================================================
# Objetivo: montar a árvore de contas de despesa para escolher quais usar.
# Usa só o cache base_siconfi_despesas.parquet (não baixa nada) e não altera
# o painel. Gera catalogo_contas_despesas.xlsx.
#
# Estrutura verificada com código (não suposta):
#   id_conta_bd: "3.00.000" = total (exceto intraorçamentárias), "3.FF.000" =
#     função FF, "3.FF.SSS" = subfunção SSS da função FF.
#   portaria: "F" ou "FF" = função, "F.SSS"/"FF.SSS" = subfunção. O total não tem
#     código de portaria (nulo até 2021, vazio de 2022 em diante). O formato é
#     o mesmo em todos os anos de 2013 a 2025.
#   Em todos os anos, cada portaria corresponde a um único id_conta_bd, e
#     id_conta_bd = "3." + função com 2 dígitos + "." + subfunção (ou "000").
import pandas as pd
import numpy as np

# Caminhos dos arquivos do projeto (ver codigo/caminhos.py).
# Procura a pasta codigo/ subindo a partir da pasta atual, para funcionar
# tanto no terminal (raiz do projeto) quanto nas células do VS Code.
import sys
from pathlib import Path
for _pasta in [Path.cwd(), *Path.cwd().parents]:
    if (_pasta / "codigo" / "caminhos.py").exists():
        sys.path.insert(0, str(_pasta / "codigo"))
        break
from caminhos import SICONFI_DESPESAS, CATALOGO_CONTAS_DESPESAS_XLSX

pd.set_option("display.width", 250)
pd.set_option("display.max_rows", 200)

df = pd.read_parquet(SICONFI_DESPESAS,
                     columns=['ano', 'id_municipio', 'portaria', 'conta', 'id_conta_bd', 'conta_bd', 'valor'])

# Códigos nulos e vazios ('') viram NaN, para tratar os dois do mesmo jeito
for col in ['portaria', 'id_conta_bd']:
    df[col] = df[col].where(df[col].fillna('').str.strip() != '')

anos = sorted(df['ano'].unique())
print(f"Linhas: {len(df)} | anos: {anos[0]}-{anos[-1]}")
print(f"Linhas sem id_conta_bd: {df['id_conta_bd'].isna().sum()} | sem portaria: {df['portaria'].isna().sum()}")


# %%
# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================
def nivel_id_bd(codigo):
    """Nível na árvore do id_conta_bd: 1 = total, 2 = função, 3 = subfunção."""
    _, funcao, subfuncao = codigo.split('.')
    if funcao == '00':
        return 1
    return 2 if subfuncao == '000' else 3


def mae_id_bd(codigo):
    """Conta imediatamente acima no id_conta_bd."""
    _, funcao, subfuncao = codigo.split('.')
    if funcao == '00':
        return np.nan                  # o total não tem mãe
    if subfuncao == '000':
        return '3.00.000'              # função -> total
    return f"3.{funcao}.000"           # subfunção -> função


def nivel_portaria(codigo):
    """Nível na árvore da portaria: 1 = função, 2 = subfunção (o total não tem código)."""
    return 2 if '.' in codigo else 1


def mae_portaria(codigo):
    """Conta imediatamente acima na portaria (a função, para as subfunções)."""
    return codigo.split('.')[0] if '.' in codigo else np.nan


def chave_portaria(codigo):
    """Ordem numérica (1, 2, ..., 10) em vez de alfabética (1, 10, 11, ..., 2)."""
    funcao, _, subfuncao = codigo.partition('.')
    return (int(funcao), int(subfuncao) if subfuncao else -1)


def resumo_por_conta(dados, chave):
    """Anos, municípios e soma de valor por conta."""
    por_ano = dados.groupby([chave, 'ano']).agg(n_municipios=('id_municipio', 'nunique')).reset_index()
    resumo = por_ano.groupby(chave).agg(
        ano_min=('ano', 'min'),
        ano_max=('ano', 'max'),
        n_anos=('ano', 'nunique'),
        media_municipios_ano=('n_municipios', 'mean'),
    )
    resumo['soma_valor'] = dados.groupby(chave)['valor'].sum()
    # Nomes originais (coluna conta) que a conta teve ao longo dos anos
    resumo['nomes_originais'] = dados.groupby(chave)['conta'].agg(lambda x: ' | '.join(sorted(x.unique())))
    return resumo


def fechamento(dados, chave, func_mae):
    """Compara o valor de cada mãe com a soma das filhas.
    - soma_filhas_sobre_valor: nacional, todos os anos, só nos município-anos em que a mãe existe;
    - pct_municipio_anos_fecha: % dos município-anos (com a mãe) em que |mãe - soma das filhas| <= R$ 1."""
    filhas = dados.assign(mae=dados[chave].map(func_mae)).dropna(subset=['mae'])
    soma_filhas = filhas.groupby(['ano', 'id_municipio', 'mae'])['valor'].sum().rename('soma_filhas')
    valor_mae = dados.groupby(['ano', 'id_municipio', chave])['valor'].sum().rename('valor_mae')
    valor_mae.index = valor_mae.index.set_names(['ano', 'id_municipio', 'mae'])
    comp = pd.concat([valor_mae, soma_filhas], axis=1, join='inner').reset_index()
    comp['fecha'] = (comp['valor_mae'] - comp['soma_filhas']).abs() <= 1
    resultado = comp.groupby('mae').agg(valor_mae=('valor_mae', 'sum'), soma_filhas=('soma_filhas', 'sum'),
                                        pct_municipio_anos_fecha=('fecha', 'mean'))
    resultado['soma_filhas_sobre_valor'] = resultado['soma_filhas'] / resultado['valor_mae']
    resultado['pct_municipio_anos_fecha'] = (resultado['pct_municipio_anos_fecha'] * 100).round(2)
    return resultado[['soma_filhas_sobre_valor', 'pct_municipio_anos_fecha']]


# %%
# ==============================================================================
# ABA "arvore": ÁRVORE PELO id_conta_bd
# ==============================================================================
com_id = df.dropna(subset=['id_conta_bd'])

arvore = resumo_por_conta(com_id, 'id_conta_bd')

# Nome padronizado mais recente da conta (alguns mudam, ex.: "Defesa Área" -> "Defesa Aérea")
ultimo_nome = com_id.sort_values('ano').groupby('id_conta_bd')['conta_bd'].last()
arvore.insert(0, 'conta_bd', ultimo_nome)

arvore['nivel'] = arvore.index.map(nivel_id_bd)
arvore['mae'] = arvore.index.map(mae_id_bd)
arvore['nome_mae'] = arvore['mae'].map(ultimo_nome)
arvore['n_filhas'] = arvore.index.map(arvore['mae'].value_counts()).fillna(0).astype(int)
arvore['conta_indentada'] = ['    ' * (n - 1) + nome for n, nome in zip(arvore['nivel'], arvore['conta_bd'])]

# % do total geral: denominador = soma das funções (nível 2) em todos os anos.
# (Não uso o 3.00.000 porque ele não existe em 2013; ver aba sem_id_conta_bd.)
total_geral = arvore.loc[arvore['nivel'] == 2, 'soma_valor'].sum()
arvore['pct_total_geral'] = (arvore['soma_valor'] / total_geral * 100).round(4)

arvore = arvore.join(fechamento(com_id, 'id_conta_bd', mae_id_bd))

arvore = arvore.reset_index().sort_values('id_conta_bd')   # a ordem do código já põe cada filha sob a mãe
arvore = arvore[['id_conta_bd', 'conta_bd', 'nivel', 'mae', 'nome_mae', 'n_filhas', 'conta_indentada',
                 'ano_min', 'ano_max', 'n_anos', 'media_municipios_ano', 'soma_valor', 'pct_total_geral',
                 'soma_filhas_sobre_valor', 'pct_municipio_anos_fecha', 'nomes_originais']]
print(f"Árvore id_conta_bd: {len(arvore)} contas | por nível: {arvore['nivel'].value_counts().sort_index().to_dict()}")


# %%
# ==============================================================================
# ABA "municipios_por_ano": nº de municípios por conta e ano
# ==============================================================================
municipios_por_ano = com_id.pivot_table(index='id_conta_bd', columns='ano', values='id_municipio', aggfunc='nunique')
municipios_por_ano.columns = [str(c) for c in municipios_por_ano.columns]
municipios_por_ano = municipios_por_ano.reset_index()
municipios_por_ano.insert(1, 'conta_bd', municipios_por_ano['id_conta_bd'].map(ultimo_nome))
municipios_por_ano = municipios_por_ano.sort_values('id_conta_bd')


# %%
# ==============================================================================
# ABA "sem_id_conta_bd": contas que só existem no código/nome original
# ==============================================================================
sem_id = df[df['id_conta_bd'].isna()].copy()
sem_id['portaria'] = sem_id['portaria'].fillna('(sem código)')
sem_id_resumo = sem_id.groupby(['portaria', 'conta', 'conta_bd']).agg(
    anos=('ano', lambda x: ', '.join(str(a) for a in sorted(x.unique()))),
    n_linhas=('ano', 'size'),
    n_municipios=('id_municipio', 'nunique'),
    soma_valor=('valor', 'sum'),
).reset_index()


# %%
# ==============================================================================
# ABA "arvore_portaria": ÁRVORE PELO CÓDIGO ORIGINAL DO TESOURO
# ==============================================================================
com_portaria = df.dropna(subset=['portaria'])

arv_por = resumo_por_conta(com_portaria, 'portaria')
arv_por.insert(0, 'periodo', [f"{a}-{b}" + ("" if n == b - a + 1 else f" ({n} anos)")
                              for a, b, n in zip(arv_por['ano_min'], arv_por['ano_max'], arv_por['n_anos'])])

# Nome original mais recente e id_conta_bd correspondente (vazio se não houver)
ultimo_nome_por = com_portaria.sort_values('ano').groupby('portaria')['conta'].last()
arv_por.insert(1, 'conta', ultimo_nome_por)
arv_por['id_conta_bd'] = com_portaria.groupby('portaria')['id_conta_bd'].agg(
    lambda x: ' | '.join(sorted(x.dropna().unique())))

arv_por['nivel'] = arv_por.index.map(nivel_portaria)
arv_por['mae'] = arv_por.index.map(mae_portaria)
arv_por['n_filhas'] = arv_por.index.map(arv_por['mae'].value_counts()).fillna(0).astype(int)
arv_por['conta_indentada'] = ['    ' * (n - 1) + nome for n, nome in zip(arv_por['nivel'], arv_por['conta'])]
arv_por = arv_por.join(fechamento(com_portaria, 'portaria', mae_portaria))

arv_por = arv_por.reset_index()
arv_por = arv_por.iloc[sorted(range(len(arv_por)), key=lambda i: chave_portaria(arv_por.loc[i, 'portaria']))]
arv_por = arv_por[['periodo', 'portaria', 'id_conta_bd', 'conta', 'nivel', 'mae', 'n_filhas', 'conta_indentada',
                   'ano_min', 'ano_max', 'n_anos', 'media_municipios_ano', 'soma_valor',
                   'soma_filhas_sobre_valor', 'pct_municipio_anos_fecha', 'nomes_originais']]
print(f"Árvore portaria: {len(arv_por)} contas | por nível: {arv_por['nivel'].value_counts().sort_index().to_dict()}")
print(f"Portarias sem id_conta_bd: {(arv_por['id_conta_bd'] == '').sum()}")


# %%
# ==============================================================================
# SALVA O EXCEL
# ==============================================================================
with pd.ExcelWriter(CATALOGO_CONTAS_DESPESAS_XLSX) as writer:
    arvore.to_excel(writer, sheet_name='arvore', index=False)
    municipios_por_ano.to_excel(writer, sheet_name='municipios_por_ano', index=False)
    sem_id_resumo.to_excel(writer, sheet_name='sem_id_conta_bd', index=False)
    arv_por.to_excel(writer, sheet_name='arvore_portaria', index=False)
print("Salvo: catalogo_contas_despesas.xlsx")


# %%
# ==============================================================================
# CONFERÊNCIAS PARA O RESUMO
# ==============================================================================
funcoes = arvore[arvore['nivel'] == 2]
print("\nFunções (nível 2):")
print(funcoes[['id_conta_bd', 'conta_bd', 'ano_min', 'ano_max', 'n_anos', 'media_municipios_ano',
               'pct_total_geral', 'soma_filhas_sobre_valor', 'pct_municipio_anos_fecha']].round(3).to_string(index=False))

print("\nTotal (nível 1):")
print(arvore[arvore['nivel'] == 1][['id_conta_bd', 'conta_bd', 'ano_min', 'ano_max', 'n_anos',
                                     'soma_filhas_sobre_valor', 'pct_municipio_anos_fecha']].to_string(index=False))

print("\nSubfunções que não aparecem em todos os anos:")
sub = arvore[(arvore['nivel'] == 3) & (arvore['n_anos'] < len(anos))]
print(sub[['id_conta_bd', 'conta_bd', 'ano_min', 'ano_max', 'n_anos', 'media_municipios_ano']].to_string(index=False))

print("\nContas sem id_conta_bd:")
print(sem_id_resumo.to_string(index=False))
