Contexto do projeto: TCC em Ciências Econômicas (UFPR)
Tema

Ciclos Políticos Orçamentários e finanças municipais no Brasil. Analisa como as despesas dos municípios respondem ao ciclo eleitoral e ao alinhamento político do prefeito com governador e presidente. Metodologia: regressão de efeitos fixos em painel município-ano. Referência de controles: Sakurai (2009): receita tributária e receita de transferências correntes.

Arquivos
main_code.py: pipeline em células (# %%) que gera painel_final_eleicoes.parquet e .csv.
Código de receitas (exploração + download): Célula 1 gera catalogo_receitas.parquet/.xlsx; Célula 2 gera base_siconfi_receitas.parquet e receitas_municipio_ano.parquet/.csv; Célula 3 (celula3_merge_receitas.py) junta ao painel e salva painel_final_eleicoes_receitas.parquet.
teste_todas_maes.py: teste de hierarquia de contas de receita (mãe = soma das filhas), por município-ano.
Caches locais em parquet (delete o arquivo para forçar novo download quando a query mudar): base_siconfi_despesas.parquet, base_prefeitos.parquet, base_gov_pres.parquet, base_ibge_anual.parquet, catalogo_receitas.parquet, base_siconfi_receitas.parquet, teste_todas_maes.parquet, contribuicao_melhoria_v2.parquet, transferencias_filhas.parquet.
CSVs do SIDRA/IBGE (Censo): tabela9923.csv (urbanização 2022), tabela202.csv (urbanização 2010), tabela9514.csv (idade 2022), tabela200.csv (idade 2010).
Fonte principal: Base dos Dados (BigQuery), projeto de cobrança monografia-508123.
Pipeline atual
Siconfi despesas: br_me_siconfi.municipio_despesas_funcao (Anexo 1-E), estágio "Despesas Pagas", Brasil inteiro (sem filtro de região). Remove conta_bd == 'Despesas Intraorçamentárias'.
Prefeitos: br_tse_eleicoes.resultados_candidato, cargo prefeito, resultado = 'eleito', anos 2008 a 2024. Chave de reeleição: titulo_eleitoral_candidato com shift(1) por município gera segundo_mandato. Eleição de 2008 só serve de âncora para 2012. Mapeamento ano financeiro para eleição: 2013-16 usa 2012, 2017-20 usa 2016, 2021-24 usa 2020, 2025 usa 2024.
Governador/Presidente: resultados_candidato JOIN partidos (coligação em composicao_coligacao), com IFNULL(sigla_uf,'BR') no join para o presidente. Mapeamento: 2013-14 usa 2010, 2015-18 usa 2014, 2019-22 usa 2018, 2023-25 usa 2022. Dummies coalizao_gov e coalizao_pres via verifica_alianca (separa a coligação por "/" e compara sigla exata).
IBGE anual: PIB (br_ibge_pib.municipio) e população (br_ibge_populacao.municipio), com pib_per_capita.
Censo (SIDRA): grau de urbanização, % jovens (0-19) e % idosos (65+), 2010 e 2022. Interpolação linear entre 2010 e 2022 e forward fill para 2023-2025.
Logs: ln_populacao, ln_pib_per_capita, ln_pib.
Receitas (controles do Sakurai): br_me_siconfi.municipio_receitas_orcamentarias, estágio Receitas Brutas Realizadas.
receita_tributaria = id_conta_bd 1.1.1.0.0.00.00.00 (Impostos, Taxas e Contribuições de Melhoria).
transf_correntes = id_conta_bd 1.1.7.0.0.00.00.00 (Transferências Correntes).
Merge com o painel por ['ano', 'id_municipio'] (left join).
Decisões e validações das receitas
Usar o valor da conta mãe direto. Nunca somar uma conta mãe com filha dela (conta dupla).
Hierarquia validada por município-ano (teste_todas_maes.py, 2013-2025):
1.1.1.0 = Impostos (1.1.1.1) + Taxas (1.1.1.2) + Contribuição de Melhoria: bate em 100% dos 71.333 município-anos. A Contribuição de Melhoria não tem id_conta_bd; foi buscada pela portaria 1.1.3.0.00.00.00 (2013-17) / 1.1.3.0.00.0.0 (2018+).
1.1.7.0 = soma das filhas diretas (portaria 1.7.X.0.00.00.00 em 2013-17 e 1.7.X.0.00.0.0 em 2018+, X de 1 a 9): bate em 100% dos 71.316 município-anos, exceto ~2 casos em 2013.
Dois sistemas de código: id_conta_bd (padronizado pela Base dos Dados, estável entre anos, só ~50 contas) e portaria (código original do Tesouro, muda de formato e significado em 2018). O mesmo número (ex.: 1.7.2) significa coisas diferentes em cada sistema. Não misturar.
Filtrar por código, nunca pelo nome da conta: a partir de 2019 existem várias linhas com o mesmo nome no mesmo ano (ex.: "Contribuição de Melhoria" aparece como mãe e filha), e filtrar pelo nome conta em dobro.
Linhas com id_conta_bd nulo ou vazio ('') existem; IS NOT NULL não pega o vazio. Usar também TRIM(id_conta_bd) != ''.
Diferença em relação ao Sakurai: transf_correntes (1.1.7.0) inclui mais do que União + Estados (ex.: transferências de outras instituições públicas, convênios, instituições privadas). Declarar na metodologia. Versão só União + Estados exigiria regra por ano (portaria muda em 2018) e fica como possível teste de robustez.
Estágio usado é receita bruta; não desconta deduções (ex.: FUNDEB).
Problemas conhecidos e pendências
Deflacionar valores monetários (IPCA) — despesas e receitas — e usar per capita antes de aplicar log. A Célula 3 cria receita_tributaria_pc e transf_correntes_pc ainda nominais.
Hierarquia de contas no Siconfi (despesas): a tabela de despesas mistura totais, subtotais e funções (ex.: conta 3.0 é o total, 3.1 é parte dele). Somar valor sem filtrar conta dupla. Falta: listar conta/id_conta_bd/conta_bd distintos, manter só o nível de função e validar que a soma das funções bate com o total por município-ano (mesma lógica do teste_todas_maes.py).
Siglas partidárias que mudaram (PMDB para MDB, PPS para Cidadania, DEM e PSL para União Brasil etc.) geram falso 0 em verifica_alianca. Precisa de dicionário de equivalência.
MAX(composicao_coligacao) na query de governador/presidente é arbitrário se 1º e 2º turno tiverem textos diferentes. Verificar.
Cobertura temporal: PIB municipal sai com defasagem, então os anos finais podem ficar nulos. Siconfi 2025 tem menos municípios (~5.440 contra ~5.550). Receitas têm queda de cobertura em 2014 (~5.180 municípios).
Conferir nulos em titulo_eleitoral_candidato e eventuais eleições suplementares que desalinhem o shift(1).
Despesas por função no corpo do trabalho (ex.: Urbanismo, Habitação, Cultura). Investimentos reais (Anexo 2, natureza da despesa, municipio_despesas_orcamentarias) ficam como teste de robustez.
Variáveis do Censo não variam o suficiente para sobreviver a efeitos fixos de município. Úteis para descritivas e heterogeneidade.
Ainda não decidido: estimar no Python (linearmodels ou statsmodels) ou exportar para Stata/R.
Convenções
Responder em português.
Manter o padrão de cache por os.path.exists em cada consulta ao BigQuery.
Scripts rodam em VS Code com células # %%; usar print em vez de display em .py.
Em GROUP BY, usar nomes de colunas em vez de posições (GROUP BY 1, 2...).
Antes de afirmar algo sobre a estrutura dos dados, verificar com código. Não supor hierarquia de contas.