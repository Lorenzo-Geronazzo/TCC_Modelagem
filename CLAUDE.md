# Contexto do projeto: TCC em Ciências Econômicas (UFPR)

## Tema
Ciclos Políticos Orçamentários e finanças municipais no Brasil. Analisa como as despesas dos municípios respondem ao ciclo eleitoral e ao alinhamento político do prefeito com governador e presidente. Metodologia: painel município-ano com efeitos fixos, em dois modelos (A: ciclo eleitoral, efeito fixo de município, erro-padrão de Driscoll-Kraay; B: coalizões, efeitos fixos de município e de ano, erro-padrão agrupado por município), teste de Hausman clássico e robusto, e a especificação de Sakurai (2009) como teste de robustez (R5). Controles do Sakurai: receita tributária e receita de transferências correntes, demografia, população. Estimação em R (`arrow`, `dplyr`, `tidyr`, `plm`, `lmtest`, `sandwich`, `ggplot2`, `scales`, `flextable`, `here`); ver seção "Regressão em R".

## Estado atual da base (leia primeiro)
- **Base final: `dados/finais/painel_final_real.parquet`** (valores deflacionados, R$ de 2025). Não versionada no git (ver Estrutura de pastas); recriar rodando o pipeline.
- Ordem de execução (rodar tudo de novo quando uma etapa anterior mudar):
  1. `codigo/main_code.py` → `dados/finais/painel_final_eleicoes.parquet`.
  2. `codigo/explora_receitas.py`, Células 2 e 3 → `dados/finais/receitas_municipio_ano.parquet` e `dados/finais/painel_final_eleicoes_receitas.parquet` (Célula 1 = catálogo, só exploração).
  3. `codigo/explora_receitas.py`, Célula 4 (deflação) → `dados/finais/painel_final_real.parquet`.
  4. R: `regressao/rodar_tudo.R` (no terminal, na raiz: `Rscript regressao/rodar_tudo.R`; no RStudio: abrir `TCC_Modelagem.Rproj` e dar Source; o `rodar_tudo.R` instala o pacote `here` se faltar, e o `00_configuracao.R` instala os demais). O `01_base_regressao.R` gera `dados/finais/base_regressao.rds`; os demais leem esse arquivo.
- Formato: uma linha por município × ano × conta de despesa (inclui total, funções e subfunções). Para as variáveis dependentes usar só `id_conta_bd` no formato `3.FF.000` (ver seção Variáveis dependentes). A passagem para uma linha por município-ano é feita no R, em `regressao/01_base_regressao.R` (decisão: montar a base no R, não em Python).

## Estrutura de pastas
- `codigo/`: pipeline. `main_code.py`, `explora_receitas.py` e **`caminhos.py`** (todos os caminhos de arquivo, a partir da raiz do projeto).
- `codigo/exploracao/`: testes e explorações fora do pipeline: `exploracao_contas_despesas.py`, `teste_mae_filho.py`.
- `dados/externos/`: CSVs do SIDRA/IBGE baixados à mão (Censo): tabela9923.csv (urbanização 2022), tabela202.csv (urbanização 2010), tabela9514.csv (idade 2022), tabela200.csv (idade 2010).
- `dados/cache/`: caches das consultas (apague o arquivo para forçar novo download quando a query mudar). Pipeline: base_siconfi_despesas.parquet, base_prefeitos_v3.parquet, base_gov_pres_v2.parquet, base_gov_pres_2010.parquet, base_ibge_anual_v2.parquet, catalogo_receitas.parquet, base_siconfi_receitas.parquet, ipca_mensal.csv, pib_nacional_trimestral.csv. Testes de receita (teste_mae_filho.py): teste_todas_maes.parquet, contribuicao_melhoria_v2.parquet, transferencias_filhas.parquet.
- `dados/finais/`: painel_final_eleicoes.parquet, painel_final_eleicoes_receitas.parquet, painel_final_real.parquet, receitas_municipio_ano.parquet/.csv.
- `saidas/exploracao/`: xlsx e csv de testes (catalogo_receitas.xlsx, catalogo_contas_despesas.xlsx, nao_batem_todas_maes.csv, resumo_todas_maes.csv, transf_nao_batem.csv, trib_ainda_nao_batem.csv).
- `backups/`: cópias "antes" de mudanças de regra (dummies_coalizao_antes.parquet, segundo_mandato_antes.parquet, coalizao_gov_antes_tse_ordinaria.parquet).
- `obsoletos/`: caches que não são mais usados (base_prefeitos.parquet, base_prefeitos_v2.parquet, base_gov_pres.parquet, base_ibge_anual.parquet).
- `referencia/br_me_siconfi/`: código do pipeline da própria Base dos Dados que baixa o Siconfi (Prefect). Só referência; nenhum script nosso usa.
- `regressao/`: scripts de R (ver seção "Regressão em R"). Saídas em `regressao/saidas/tabelas/` (.csv e .docx), `regressao/saidas/graficos/` (.png) e `regressao/saidas/modelos/` (`modelos_principais.rds`). `TCC_Modelagem.Rproj` fica na raiz do projeto.
- `dados/finais/base_regressao.rds`: base de regressão, uma linha por município-ano (gerada pelo `01_base_regressao.R`).
- Como os scripts acham os arquivos: cada script procura a pasta `codigo/` subindo a partir da pasta atual e importa as constantes de `caminhos.py` (ex.: `PAINEL_FINAL_REAL`, `CACHE`). Funciona no terminal na raiz (`python codigo/main_code.py`) e nas células do VS Code (que rodam na pasta do script). Para mudar um arquivo de lugar, mudar só `caminhos.py`. Nunca escrever nome de arquivo solto nos scripts. No R, o equivalente é `regressao/00_configuracao.R`: caminhos com `here::here(...)`, que acha a raiz pelo `TCC_Modelagem.Rproj` (ou pela pasta `.git`), então funciona no terminal, no VS Code e no RStudio sem `setwd`.
- Git: só código e documentação são versionados: `codigo/`, `dados/externos/` (CSVs do SIDRA), `dados/cache/ipca_mensal.csv` e `dados/cache/pib_nacional_trimestral.csv` (únicos arquivos versionados em `dados/cache/`), `CLAUDE.md`, `README.md`, `requirements.txt`, `regressao/*.R`, `TCC_Modelagem.Rproj` e `referencia/`. Ficam fora do Git (no `.gitignore`, recriados pelo pipeline): `dados/cache/` (exceto `ipca_mensal.csv` e `pib_nacional_trimestral.csv`), `dados/finais/` (inclui `base_regressao.rds`), `backups/`, `obsoletos/` e `saidas/` (o padrão `saidas/` também ignora `regressao/saidas/`). Arquivos do R a ignorar: `.Rproj.user/`, `.Rhistory`, `.RData`. Git LFS desligado (`git lfs untrack "*.parquet"`; `.gitattributes` vazio). Versões antigas de parquet continuam no histórico/LFS do GitHub (commits até 65e1751). Em outro computador, a 1ª execução baixa os caches de novo (custo no BigQuery). Reorganização conferida: depois de mover, o pipeline rodou só com caches (download bloqueado) e `painel_final_real.parquet` saiu idêntico ao anterior (3.281.067 × 48, `assert_frame_equal`).
- Fonte principal: Base dos Dados (BigQuery), projeto de cobrança monografia-508123.

## Arquivos
- `codigo/main_code.py`: pipeline em células (`# %%`) que gera `painel_final_eleicoes.parquet` (só parquet; não gera .csv).
- `codigo/explora_receitas.py`: Célula 1 gera `catalogo_receitas.parquet`/`.xlsx`; Célula 2 gera `base_siconfi_receitas.parquet` e `receitas_municipio_ano.parquet`/`.csv`; Célula 3 junta ao painel (`painel_final_eleicoes_receitas.parquet`); Célula 4 deflaciona e acrescenta o PIB nacional (`ipca_mensal.csv`, `pib_nacional_trimestral.csv`, `painel_final_real.parquet`).
- `codigo/exploracao/exploracao_contas_despesas.py` → `catalogo_contas_despesas.xlsx` (árvore das contas de despesa; só exploração).
- `codigo/exploracao/teste_mae_filho.py`: teste de hierarquia das contas de receita (mãe = soma das filhas), por município-ano; gera teste_todas_maes.parquet e os csv de conferência. Validação, fora do pipeline. (Não existe `teste_todas_maes.py`; o nome antigo era citado por engano.)

## Pipeline
Siconfi despesas: br_me_siconfi.municipio_despesas_funcao (Anexo 1-E), estágio "Despesas Pagas", Brasil inteiro (sem filtro de região). Remove as despesas intraorçamentárias. Elas não têm código (id_conta_bd e portaria vazios), só aparecem como linha de total, e o nome muda: "Despesas (Intra-Orçamentárias)" em 2013 e "Despesas Intraorçamentárias" de 2014 em diante. Filtro: conta_bd sem acento e em minúsculas contém "intra" e não contém "exceto" (as linhas "Despesas Exceto Intraorçamentárias" são o total sem as intra e ficam). Remove 20.504 linhas (antes o filtro por nome exato tirava 19.530 e deixava as 974 de 2013).
Prefeitos: br_tse_eleicoes.resultados_candidato, cargo prefeito, resultado = 'eleito', anos 2008 a 2024, com tipo_eleicao e data_eleicao (cache base_prefeitos_v3.parquet, que inclui também título, CPF e nome da tabela candidatos; base_prefeitos.parquet e base_prefeitos_v2.parquet não são mais usados). Eleição de 2008 só serve de âncora para 2012.
Eleições suplementares: a Base dos Dados registra a suplementar sob o ano da ordinária (ex.: suplementar de fev/2023 com ano 2020). Cada município-eleição tem no máximo 1 ordinária + 0 a 2 suplementares (405 grupos com 1 suplementar, 5 com 2, 116 só com suplementar). Antes isso duplicava linhas do painel.
Regra de um prefeito por município-ano: início do mandato = 1º/jan do ano seguinte (ordinária) ou data da eleição suplementar (aproximação da posse; nunca antes daquele 1º/jan). Em cada ano financeiro fica o último a assumir até 1º de julho (= quem governou a maior parte do ano quando há uma troca no ano). Se ninguém do mandato assumiu até 1º/jul (só houve suplementar depois), o município-ano fica sem prefeito: partido, segundo_mandato e as 4 dummies de coalizão ficam vazios (NaN), não 0 (214 município-anos; verifica_alianca devolve NaN quando falta partido ou coligação). Coluna prefeito_suplementar = 1 quando o prefeito do ano veio de suplementar (útil para robustez). Limitação: se o eleito na ordinária foi afastado muito antes da suplementar, o período com prefeito interino é atribuído a ele.
segundo_mandato = 1 se o prefeito do ano é a mesma pessoa que estava no cargo ao fim do mandato anterior (o último a assumir, ordinário ou tampão), olhando exatamente a eleição de 4 anos antes. Mesma pessoa = título igual OU CPF igual OU, só quando falta o título de um dos lados, nome padronizado igual (sem acento, maiúsculas, espaços simples); vazios nunca contam como iguais. Título = titulo_eleitoral_candidato de resultados_candidato, completado por candidatos.titulo_eleitoral quando nulo; CPF de candidatos.cpf. JOIN com candidatos por ano, id_municipio, cargo = 'prefeito' e sequencial = sequencial_candidato (não duplica: 28.185 eleitos antes e depois). Validação: nos pares com os dois identificadores, CPF e título concordam em 99,9% (5 casos com mesmo CPF e título diferente = título trocado, por isso o CPF entra); nome igual implica título igual em 99,7%. Efeito: 220 município-anos passaram de 0 para 1 (~25/ano em 2013-16, 20 em 2017-20, 8 em 2021-24, 4 em 2025), nenhum de 1 para 0. Cópia anterior: segundo_mandato_antes.parquet. Cache: base_prefeitos_v3.parquet. Substitui o shift(1), que com suplementares comparava linhas em ordem arbitrária. Mandato não consecutivo (ex.: cassado, tampão, volta) = 0. Mapeamento ano financeiro para eleição: 2013-16 usa 2012, 2017-20 usa 2016, 2021-24 usa 2020, 2025 usa 2024.
Governador/Presidente: resultados_candidato JOIN partidos (coligação em composicao_coligacao), com IFNULL(sigla_uf,'BR') no join para o presidente, filtrando tipo_eleicao = 'eleicao ordinaria' (cache base_gov_pres_v2.parquet; base_gov_pres.parquet não é mais usado).
MAX(composicao_coligacao) verificado: a tabela partidos só tem o 1º turno, então nunca há escolha entre turnos. Os únicos grupos com 2 textos eram AM e TO 2014, porque a Base dos Dados grava as suplementares de governador (AM 27/08/2017, TO 24/06/2018) sob o ano de 2014; o partido do vencedor da suplementar puxava a coligação que esse partido tinha em 2014. Em TO o MAX escolhia a chapa derrotada (Sandoval, "PRB / PP / ...") em vez da de Marcelo Miranda ("PMDB / PT / PSD / PV"); em AM acertava por acaso. Com o filtro de ordinária há 1 texto por ano/UF/cargo e o MAX é inofensivo. Efeito: só TO 2015-18 mudou em coalizao_gov (63-68 de 0→1 e 66-70 de 1→0 por ano, de ~135 municípios); nenhum outro estado mudou. Cópia anterior: coalizao_gov_antes_tse_ordinaria.parquet.
governador_suplementar = 1 nos município-anos em que, pela regra de 1º de julho, o governador no cargo não era o eleito na ordinária: AM 2017 (Melo cassado pelo TSE em 04/05/2017; David Almeida interino de 09/05/2017) e AM 2018 (Amazonino Mendes, suplementar, posse em 04/10/2017); TO 2018 (Miranda cassado em 22/03/2018; Mauro Carlesse interino e eleito na suplementar de 24/06/2018). Datas conferidas em fontes externas (TSE, Agência Brasil, Conexão Tocantins). coalizao_gov continua usando a coligação da ordinária nesses anos; a coligação das suplementares não está na tabela partidos (exigiria arquivo do TSE de 2017/2018). Vices que assumem por renúncia/impeachment (ex.: RJ, Witzel → Cláudio Castro) não são marcados: são da mesma chapa eleita. Mapeamento: 2013-14 usa 2010, 2015-18 usa 2014, 2019-22 usa 2018, 2023-25 usa 2022. Dummies coalizao_gov e coalizao_pres via verifica_alianca (separa a coligação por "/" e compara sigla exata, depois de padronizar as siglas dos dois lados com padroniza_sigla). Versão de robustez: coalizao_gov_sem_fusao e coalizao_pres_sem_fusao (só renomeações, sem fusões/incorporações).
Eleição de 2010 (resolvido): na Base dos Dados, a tabela partidos tem composicao_coligacao nula em 2010 e não tem presidente em 2010 (antes isso zerava as dummies de 2013-14). O main_code.py troca as linhas de 2010 por base_gov_pres_2010.parquet: partido eleito de resultados_candidato (presidente 2010 tem resultado nulo; eleito = mais votado no 2º turno, PT) + composição do arquivo oficial do TSE consulta_coligacao_2010 (cdn.tse.jus.br, arquivo _BRASIL.csv, latin1, mesmo formato "A / B"). Validação: para os 27 governadores, a composição do TSE é igual à reconstruída pela Base dos Dados juntando os partidos com o mesmo sequencial_coligacao (27/27).
Padronização de siglas partidárias (main_code.py, Célula 3; fonte: TSE, "Fusões, incorporações e mudanças de nomenclatura"):
Grafia: strip de espaços e dos parênteses das federações de 2022 (ex.: "(PT/PC do B/PV) / MDB" gerava "(PT" e "PV)", falso 0). Não há outras variações de grafia nos dados ("PC do B" e "PT do B" são escritos igual nas duas bases).
(a) Renomeações, aplicadas sempre: PMDB→MDB, PTN→PODE, PT do B→AVANTE, PEN/PATRI→PATRIOTA, PSDC→DC, SD→SOLIDARIEDADE, PR→PL, PRB→REPUBLICANOS, PPS→CIDADANIA, PTC→AGIR, PMN→MOBILIZA.
(b) Fusões/incorporações (decisão metodológica, usada na versão principal): PRP→PATRIOTA, PPL→PC do B, PHS→PODE (2019); DEM, PSL→UNIÃO (2022); PROS→SOLIDARIEDADE, PSC→PODE, PTB, PATRIOTA→PRD (2023). Só valem quando o ano da fusão cai entre as duas eleições comparadas (ano_min < ano_fusao <= ano_max). Se as duas eleições são anteriores à fusão, os partidos eram separados (ex.: prefeito DEM de 2016 x chapa PSL/PRTB de 2018 não é aliança). Aplicar a fusão sempre geraria falsos 1 (ex.: ~275 a 477 município-anos por ano em coalizao_pres 2019-22).
Na base de prefeitos, a Base dos Dados já grava a eleição de 2016 com as siglas novas (MDB, PL, REPUBLICANOS etc.), e 2008/2012 com as antigas. Coligações de 2014 e 2018 usam a sigla da época.
Efeito (município-anos distintos): nenhuma passagem de 1 para 0. 0→1 concentrado em 2017-18 (prefeito MDB de 2016 x PMDB de 2014: ~830/ano em gov, ~1.470/ano em pres) e 2023-25 (federações). Cópia das dummies anteriores: dummies_coalizao_antes.parquet.
IBGE anual: população (br_ibge_populacao.municipio, até 2025) com LEFT JOIN do PIB municipal (br_ibge_pib.municipio, só até 2023), com pib_per_capita. Cache base_ibge_anual_v2.parquet (o antigo base_ibge_anual.parquet, feito com INNER JOIN, foi para obsoletos/). Correção aplicada: com INNER JOIN a população de 2024-25 sumia junto com o PIB e todo per capita ficava vazio nesses anos (inclusive no ano eleitoral de 2024). Conferido: 2013-2023 idêntico nas 48 colunas; em 2024-25 mudaram só populacao e as variáveis per capita (valor_real_pc, receitas pc e seus logs); pib e pib_per_capita continuam vazios em 2024-25. Limitação: Boa Esperança do Norte (MT, 5101837), instalado em 2025, não tem população no cache em 2025.
Controle de PIB (decidido): controle principal = PIB nacional real (pib_nacional_real), como Sakurai (2009); disponível em todos os anos 2013-2025. PIB municipal (pib, ln_pib_real) só existe até 2023: usar como robustez (amostra 2013-2023).
Censo (SIDRA): grau de urbanização, % jovens (0-19 anos) e % idosos (65+), 2010 e 2022, como proporção (0 a 1). Interpolação linear entre 2010 e 2022 e forward fill para 2023-2025. Os municípios criados depois de 2010 só têm valor a partir de 2022 (a interpolação não preenche para trás).
% jovens = 0-19 anos (mudança em 05/10/2026; decisão da autora: faixa usual de demanda por educação). Antes o código somava 0-24 anos (incluía "20 a 24 anos"), embora este arquivo já dissesse 0-19. As duas tabelas (tabela200.csv de 2010 e tabela9514.csv de 2022) têm as faixas 0-4, 5-9, 10-14 e 15-19 separadas de 20-24, então 0-19 é exato nos dois censos. Efeito: média de perc_jovens de 0,410 para 0,328 em 2013 e de 0,347 para 0,275 em 2022-2025 (correlação antes × depois 0,992); nenhum valor aumentou. Pipeline refeito só com caches: painel_final_real com as mesmas 3.281.067 linhas e 50 colunas, só perc_jovens mudou (comparação coluna a coluna).
tabela9923.csv traz dois blocos (absoluto e percentual) e também as concentrações urbanas sob o código do município-sede (ex.: "Belém/PA" = população da região). Filtro: só bloco absoluto e nome terminando em "(UF)" (5.570 municípios, 1 linha cada). Antes isso duplicava todas as linhas de 2022 do painel (+291 mil).
Conferência no fim do main_code.py: linhas do painel = linhas do Siconfi sem intraorçamentárias (3.281.067).
Logs: o main_code.py não cria nenhuma coluna de log (não existem ln_populacao, ln_pib_per_capita nem ln_pib no painel). Os logs do painel vêm da Célula 4 do explora_receitas.py, sobre valores reais (ln_pib_real, ln_pib_real_pc, ln_receita_tributaria_real_pc etc.). O ln_populacao e o ln_pib_mun_pc da regressão são criados no R, em `regressao/01_base_regressao.R`.
Receitas (controles do Sakurai): br_me_siconfi.municipio_receitas_orcamentarias, estágio Receitas Brutas Realizadas.
receita_tributaria = id_conta_bd 1.1.1.0.0.00.00.00 (Impostos, Taxas e Contribuições de Melhoria).
transf_correntes = id_conta_bd 1.1.7.0.0.00.00.00 (Transferências Correntes).
Merge com o painel por ['ano', 'id_municipio'] (left join).
Deflação (feita, `explora_receitas.py` Célula 4): IPCA médio anual, preços de 2025. Fonte: API SIDRA/IBGE, tabela 1737, variável 2266 (número-índice mensal, dez/1993 = 100). Fator = média IPCA 2025 / média IPCA do ano; valor_real = valor_nominal × fator. Justificativa: receitas, despesas e PIB são fluxos do ano civil (Lei 4.320, arts. 34-35; MCASP: receita registrada na arrecadação). Colunas deflacionadas: valor (despesa), receita_tributaria, transf_correntes, pib. Gera <col>_real, <col>_real_pc, ln_<col>_real_pc e ln_pib_real; log de zero/negativo = NaN.
PIB nacional (feito, `explora_receitas.py` Célula 4): colunas pib_nacional (R$ correntes) e pib_nacional_real (× fator_2025, mesmo IPCA médio), mesmo valor para todos os municípios do ano, 2013-2025 sem vazios. Fonte: SIDRA/IBGE, tabela 1846 (Contas Nacionais Trimestrais), variável 585 "Valores a preços correntes" (R$ milhões), classificação 11255 = 90707 "PIB a preços de mercado"; PIB do ano = soma dos 4 trimestres (todos os anos com 4 trimestres), convertido para R$. Cache dados/cache/pib_nacional_trimestral.csv (versionado no Git, como o IPCA). **Download em 05/10/2026.** **Valores de 2024 e 2025 são preliminares** (Contas Trimestrais; o IBGE ainda revisa) — se baixar de novo no futuro, os números podem mudar. A tabela anual 6784 (Contas Nacionais Anuais) só vai até 2023, por isso a trimestral. Validação 2013-2023 contra a 6784: iguais em 8 anos (diferença ≤ R$ 1 milhão, arredondamento); 2017 −0,11%, 2018 +0,10%, 2019 −0,07% (trimestral não totalmente alinhada à última revisão anual). Unidade conferida: soma dos PIBs municipais de 2023 = PIB nacional (razão 1,0000). Conferido: painel com as mesmas 3.281.067 linhas e as 48 colunas antigas idênticas; só entraram as 2 colunas novas.

## Estrutura das contas de despesa (validada)
- id_conta_bd: 3.00.000 = total exceto intraorçamentárias (só de 2014 em diante); 3.FF.000 = 28 funções; 3.FF.SSS = 169 subfunções. portaria equivalente ("10", "10.301"); formato estável 2013-2025, só mudam nomes.
- Hierarquia fecha: soma das subfunções = função em ≥ 99,98% dos município-anos; soma das funções = total em 100% (2014+); em 2013 o total vem sem código e bate com a soma das funções em 99,5% dos municípios.
- As 28 funções existem nos 13 anos. Subfunções NÃO comparáveis antes de 2016 ("Administração Geral" FF.122 surge em 2016; antes estava em FF.999).
- Linhas sem id_conta_bd que ficam no painel: total de 2013 ("Despesas (Exceto Intra-Orçamentárias)") e 64 linhas de "Demais Subfunções" de 2017 (19 municípios). Filtrar por código (3.FF.000) evita as duas.
- As 64 linhas de 2017 são de nível de subfunção: a soma das funções bate com o total em 100% dos município-anos em 2017, então o valor delas já está dentro das funções. (Verificação opcional caso a caso nos 19 municípios: a diferença deve aparecer só no nível subfunção × função.)
- Filtro das funções no R: `filter(grepl("^3\\.\\d\\d\\.000$", id_conta_bd), id_conta_bd != "3.00.000")`. Nunca somar a coluna valor sem esse filtro (o mesmo dinheiro aparece no total, na função e na subfunção).

## Decisões e validações das receitas
Usar o valor da conta mãe direto. Nunca somar uma conta mãe com filha dela (conta dupla).
Hierarquia validada por município-ano (codigo/exploracao/teste_mae_filho.py, 2013-2025):
1.1.1.0 = Impostos (1.1.1.1) + Taxas (1.1.1.2) + Contribuição de Melhoria: bate em 100% dos 71.333 município-anos. A Contribuição de Melhoria não tem id_conta_bd; foi buscada pela portaria 1.1.3.0.00.00.00 (2013-17) / 1.1.3.0.00.0.0 (2018+).
1.1.7.0 = soma das filhas diretas (portaria 1.7.X.0.00.00.00 em 2013-17 e 1.7.X.0.00.0.0 em 2018+, X de 1 a 9): bate em 100% dos 71.316 município-anos, exceto ~2 casos em 2013.
Dois sistemas de código: id_conta_bd (padronizado pela Base dos Dados, estável entre anos, só ~50 contas) e portaria (código original do Tesouro, muda de formato e significado em 2018). O mesmo número (ex.: 1.7.2) significa coisas diferentes em cada sistema. Não misturar.
Filtrar por código, nunca pelo nome da conta: a partir de 2019 existem várias linhas com o mesmo nome no mesmo ano (ex.: "Contribuição de Melhoria" aparece como mãe e filha), e filtrar pelo nome conta em dobro.
Linhas com id_conta_bd nulo ou vazio ('') existem; IS NOT NULL não pega o vazio. Usar também TRIM(id_conta_bd) != ''.
Diferença em relação ao Sakurai: transf_correntes (1.1.7.0) inclui mais do que União + Estados (ex.: transferências de outras instituições públicas, convênios, instituições privadas). Declarar na metodologia. Versão só União + Estados exigiria regra por ano (portaria muda em 2018) e fica como possível teste de robustez.
Estágio usado é receita bruta; não desconta deduções (ex.: FUNDEB).

## Variáveis dependentes (decidido)
Todas em valores reais (IPCA, R$ de 2025) e per capita, no nível de FUNÇÃO: filtrar por `id_conta_bd` no formato `3.FF.000`, sem o total `3.00.000` (no R: `filter(grepl("^3\\.\\d\\d\\.000$", id_conta_bd), id_conta_bd != "3.00.000")`). Não existe coluna de nível no painel. Agrupamentos seguem Sakurai (2009), com os ajustes indicados.

| # | Variável | Funções (`id_conta_bd`) | Justificativa (revisão de literatura) |
|---|---|---|---|
| 0 | Despesa total | soma das 28 funções (3.01 a 3.28), em TODOS os anos | Ciclo agregado: Sakurai e Gremaud (2007); Sakurai e Menezes-Filho (2011). Decidido: não usar a linha de total `3.00.000` (não existe em 2013; o total sem código de 2013 bate com a soma das funções em só 99,5% dos municípios). Somar as funções dá uma definição única para todos os anos e coerente com as demais variáveis; de 2014 em diante é idêntico ao total oficial. Somar as 28 funções, não só as escolhidas. |
| 1 | Saúde e Saneamento | 3.10.000 + 3.17.000 | Sakurai (2009) encontrou ciclo; Nunes (2017) não. |
| 2 | Educação e Cultura | 3.12.000 + 3.13.000 | Nunes (2017): efeito negativo, rigidez das vinculações. |
| 3 | Habitação e Urbanismo | 3.16.000 + 3.15.000 | Gasto visível (Drazen e Eslava, 2010); ciclo em Sakurai (2009). |
| 4 | Assistência Social | 3.08.000 (sem Previdência) | Teixeira e Mattos (2021); Sakurai (2009). Previdência (3.09, RPPS) é gasto obrigatório e Drazen e Eslava (2010) mostram que pensões são cortadas → separado do Sakurai. |
| 5 | Transporte | 3.26.000 | Sakurai (2009); Teixeira e Mattos (2021). |
| 6 | Administração | 3.04.000 | Gasto pouco visível; redução em ano eleitoral em Teixeira e Mattos (2021). |
| 7 | Agricultura | 3.20.000 | Retração em ano eleitoral em Sakurai (2009). |
| 8 | Comunicações | 3.24.000 (só a função, sem a subfunção 3.04.131) | Sakurai (2009): dummy de ano eleitoral positiva e significativa (0,280***), hipótese de divulgação das realizações. |

Fora da lista: Legislativa (repasse à Câmara tem teto constitucional), Previdência (obrigatória; pode entrar como robustez "Assistência + Previdência", igual ao Sakurai), demais funções pequenas.

Diferenças em relação ao Sakurai a declarar na metodologia: deflator IPCA (ele usou IGP-DI, R$ de 2006); Assistência sem Previdência; Administração incluída; classificação funcional atual (Portaria 42/1999) em todo o período, enquanto o período dele atravessa a troca da classificação antiga (motivo provável dos agrupamentos; confirmar antes de citar).

Regra de montagem dos grupos (`01_base_regressao.R`): soma das funções do grupo que o município informou; se nenhuma função do grupo aparece no município-ano, o grupo fica vazio (NA), não zero. Despesa total = soma de todas as funções informadas. Forma principal: per capita em nível (R$ de 2025 por habitante), como Sakurai. Também gera `ln_<var>_pc` (log; zero ou negativo vira NA) e `<grupo>_part` (% da despesa total), usados na robustez. Robustez extra: `assist_previdencia` = 3.08.000 + 3.09.000 (agrupamento do Sakurai).

## Variáveis explicativas e especificação: modelos A e B (DECIDIDO)
**Motivo da reestruturação:** os testes R12 (erro-padrão de Driscoll-Kraay) e R13 (efeitos fixos de município e de ano) da versão anterior mostraram que (i) o ano eleitoral, igual para todos os municípios no ano, precisa de erro-padrão robusto a choques comuns, e (ii) a coalizão presidencial sem efeito de ano confunde alinhamento com período. Por isso a análise passou a ter dois modelos principais, cada um com as 9 dependentes.
- **Modelo A ("ciclo eleitoral")**: efeito fixo de município (`within`, `effect = "individual"`), `INTERESSE_A` + `CONTROLES`, erro-padrão de **Driscoll-Kraay** (`vcov_dk <- function(m) plm::vcovSCC(m, type = "HC1")`). Tabela `regressao_principal_A` (todas as variáveis).
  - `INTERESSE_A`: `ano_eleitoral` (= 1 em 2016, 2020 e 2024), `pre_eleitoral` (= 1 em 2015, 2019, 2023), `pandemia_2020` (= 1 em 2020, criada no `01_base_regressao.R`), `coalizao_gov`, `coalizao_pres`.
  - `CONTROLES`: `receita_tributaria_real_pc`, `transf_correntes_real_pc`, `perc_jovens`, `perc_idosos`, `grau_urb`, `ln_populacao`, `pib_nacional_tri` (= `pib_nacional_real` / 1e12, R$ trilhões), `tendencia` (= ano − 2012) e `tendencia2`.
- **Modelo B ("coalizões")**: efeitos fixos de município e de ano (`effect = "twoways"`), `coalizao_gov` + `coalizao_pres` (`INTERESSE_B`) + `CONTROLES_B`, erro-padrão **agrupado por município**. Tabela `regressao_principal_B`.
  - `CONTROLES_B` (só os que variam entre municípios): `receita_tributaria_real_pc`, `transf_correntes_real_pc`, `perc_jovens`, `perc_idosos`, `grau_urb`, `ln_populacao`. Ano eleitoral, pré-eleitoral, pandemia, PIB nacional e tendências saem (colineares com o efeito de ano).
- Leitura dos coeficientes: ano eleitoral e pré-eleitoral vêm do modelo A; coalizões vêm do modelo B.
- Identificação do ano eleitoral: como `pandemia_2020` = 1 em 2020, que também é ano eleitoral, no modelo A o efeito do ano eleitoral vem das eleições de 2016 e 2024. No R7 e no R7a (2013-2023), só de 2016.
- Variáveis do Censo (`perc_jovens`, `perc_idosos`, `grau_urb`) ficam nos controles principais (A e B), como em Sakurai (2009), mas seus coeficientes não são interpretados (ver "Pendências"); o R15 reestima sem elas.
- Driscoll-Kraay depende de muitos períodos (aqui T = 13). Critério de leitura: resultado sólido = significativo com Driscoll-Kraay (principal) E com erro agrupado por município (R12).
- `INTERESSE` antigo (`ano_eleitoral`, `coalizao_gov`, `coalizao_pres`) continua no `00_configuracao.R`: é a especificação de Sakurai (2009), usada nas descritivas e no teste R5.
- Rótulos novos: `pre_eleitoral` = "Ano pré-eleitoral", `pandemia_2020` = "Pandemia (2020)".
- Notas das tabelas: `NOTA_A` (efeito fixo de município, Driscoll-Kraay) e `NOTA_B` (efeitos fixos de município e de ano, agrupado por município), no `00_configuracao.R`.
- Só na robustez: `segundo_mandato`, `coalizao_gov_sem_fusao`/`coalizao_pres_sem_fusao`, `ln_pib_mun_pc` (PIB municipal real per capita em log, só até 2023).
- Ideologia do partido do prefeito: fora do modelo (decisão da autora). Sakurai usa; declarar como diferença/limitação.

## Regressão em R
Scripts em `regressao/`, rodar na ordem (ou tudo pelo `rodar_tudo.R`):
- `00_configuracao.R`: instala/carrega pacotes, caminhos (`here`), anos eleitorais, `GRUPOS`, `DEPENDENTES`, rótulos, `INTERESSE_A`, `INTERESSE_B`, `INTERESSE` (especificação de Sakurai), `CONTROLES`, `CONTROLES_B`, `METODO_RE`, `NOTA_EP`, `NOTA_A`, `NOTA_B` e funções auxiliares (fórmula, erro-padrão agrupado `vcov_cluster`, erro-padrão de Driscoll-Kraay `vcov_dk`, tabela de regressão, salvar tabela em .csv/.docx, Hausman robusto, `carrega_base(limpa = TRUE)`). Mudar a especificação aqui, não nos outros scripts. `carrega_base()` (padrão `limpa = TRUE`) tira os município-anos com `outlier_despesa == 1`; `carrega_base(limpa = FALSE)` devolve a base inteira (usado no R10 e no R11). 02, 03 e 04 chamam `carrega_base()`, ou seja, com limpeza.
- `01_base_regressao.R`: lê só as colunas necessárias do painel, soma as funções em grupos, junta os atributos do município-ano (para se um município-ano tiver atributos diferentes entre linhas), cria per capita, logs, participações, dummies de tempo e tendências; aplica as marcações de limpeza (ver "Limpeza da base"); imprime contagens e % de vazios; salva `dados/finais/base_regressao.rds`.
- `01b_cobertura.R`: tabela de cobertura das funções e dos grupos (municípios que informam em todos os anos, em parte, com buraco, em nenhum; linhas com valor zero; municípios por ano). Serviu para a decisão da seção "Cobertura das funções e ausências".
- `02_descritivas.R`: tabelas descritivas (N, média, desvio-padrão, mínimo, máximo) das explicativas e das dependentes; gráfico da média anual de cada dependente per capita, em nível e em log, com faixas no ano eleitoral (laranja escuro) e pré-eleitoral (amarelo); painel com todas em log.
- `02b_proporcoes_politicas.R`: % de município-anos com `coalizao_gov`, `coalizao_pres` e `segundo_mandato` = 1 por ano (sobre os não vazios) e nº de municípios; base limpa. Gera `regressao/saidas/tabelas/proporcoes_politicas.tex` (tabela LaTeX `tab:politicas`, copiada para `TCC_latex/tabelas/`).
- `03_hausman.R`: para cada dependente, com a especificação do modelo A (`INTERESSE_A` + `CONTROLES`), efeitos fixos (`within`) × aleatórios; Hausman clássico (`phtest`) e robusto (Mundlak/Wooldridge: médias por município das variáveis que variam entre municípios, teste de Wald conjunto com erro-padrão agrupado). Tabela com o modelo indicado por cada teste.
- `04_regressoes.R`: modelo A (`regressao_principal_A`, erro Driscoll-Kraay) e modelo B (`regressao_principal_B`, efeitos fixos de município e de ano, erro agrupado), 9 dependentes cada; comparação pooled/FE/RE da despesa total com a especificação do modelo A e erro Driscoll-Kraay. Salva `regressao/saidas/modelos/modelos_principais.rds` (lista com A e B; pasta `PASTA_MODELOS`, criada no 00).
- `05_robustez.R`: cada teste reestima o modelo A e/ou o modelo B mudando UMA coisa; cada tabela mostra `ano_eleitoral` e `pre_eleitoral` do modelo A (erro Driscoll-Kraay) e `coalizao_gov` e `coalizao_pres` do modelo B (erro agrupado), com "[modelo A]"/"[modelo B]" no nome de cada linha (inclusive Observações, Municípios e R²). R1 coalizões sem fusões (A e B); R2 sem prefeito/governador de suplementar (A e B); R3 dependente em log (A e B); R4 participação na despesa total, % (A e B); R5 especificação de Sakurai: modelo A sem `pre_eleitoral` e sem `pandemia_2020`, erro agrupado por município (só A; mostra `INTERESSE`); R6 + segundo mandato (A e B); R7 PIB municipal per capita, 2013-2023 (A: no lugar do PIB nacional; B: somado aos controles); R7a especificação principal (sem trocar o PIB) só na amostra 2013-2023 (A e B; separa o efeito da amostra do efeito do PIB municipal no R7); R8 Assistência + Previdência (A e B); R9 Transporte, Agricultura e Comunicações só com municípios que informam a função (valor > 0) em todos os anos em que aparecem (A e B); R10 sem limpeza (mantém `outlier_despesa = 1` e usa `receita_tributaria_real_pc_bruta`) (A e B); R11 winsorização p1-p99 de cada ano (A e B); R12 modelo A com erro agrupado por município (só A); R13 modelo B com erro Driscoll-Kraay (só B); R14 modelo A sem a dummy de pandemia (só A); R15 sem as variáveis do Censo (`perc_jovens`, `perc_idosos`, `grau_urb`) (A e B); R16 ano eleitoral e pré-eleitoral separados por eleição: `ano_eleitoral` vira `eleicao_2016` e `eleicao_2024` (2020 continua absorvido por `pandemia_2020`) e `pre_eleitoral` vira `pre_2015`, `pre_2019` e `pre_2023`; dummies criadas no próprio 05 (não no 01); tabela mostra as cinco (só A, erro Driscoll-Kraay).
- `06_tabelas_latex.R`: NÃO reestima; lê os .csv do 04 e do 05 e gera um .tex por tabela em `regressao/saidas/tabelas/latex/` (`PASTA_TAB_LATEX` no 00), no estilo da Tabela 2 de Sakurai (2009): paisagem (`landscape` + `table`), grupos nas colunas, erro-padrão entre parênteses, estrelas em sobrescrito, Observações/Municípios/R² no fim; nos testes com A e B, as linhas "[modelo A]"/"[modelo B]" viram dois painéis. Largura de cada coluna de números = maior célula (estimada em pt; mínimo 60pt, para "Saneamento" não quebrar), e a 1ª coluna fica com o resto da página (708pt em paisagem); rótulos com mais de 24 caracteres continuam na linha do erro-padrão; tabelas com mais de 25 linhas (modelo A) usam `\arraystretch` 0,9 para caber na página. Gera `regressao_principal_A`, `regressao_principal_B`, `robustez_R1` a `robustez_R16`, `robustez_R7a` e `robustez_resumo` (ano eleitoral e pré-eleitoral no modelo principal, R5, R12 e R14). Títulos e notas repetem os do 04/05 (se mudar lá, mudar no 06); `NOTA_AB` passou do 05 para o 00. Os .tex são copiados para `TCC_latex/tabelas/resultados/`.
Testes que mudam mais de uma coisa (de propósito; descrever assim no texto):
- R5: especificação (sem pré-eleitoral e sem pandemia) + erro-padrão agrupado por município.
- R7: amostra 2013-2023 (o PIB municipal só vai até 2023) + troca/inclusão do PIB municipal. A amostra tira 2024, um dos dois anos que identificam o ano eleitoral no modelo A (2020 fica com a pandemia): por isso o R7a.
  - Resultado do R7a: sem 2024, o efeito do ano eleitoral fica menor (despesa total 67, n.s.; Saúde 34**; Habitação 47**; Transporte 20*); com a dummy de pandemia, o R7a identifica o ano eleitoral só pela eleição de 2016.
- R10: volta com os outliers de despesa + usa a receita tributária original.
- R11: troca a limpeza (exclusão dos outliers) pela winsorização: base sem limpeza de despesa, receita já corrigida, dependentes per capita limitadas a p1-p99 de cada ano.
Outros cuidados de leitura:
- R3 (log) perde alguns município-anos a mais, os de valor zero ou negativo (de 2 a 5 por variável; ver "Zeros e negativos").
- R9 seleciona os municípios na base limpa (sem os outliers): 3.000 (Transporte), 4.264 (Agricultura) e 330 (Comunicações), um pouco acima da coluna "Todos os anos" da tabela de cobertura (2.984 / 4.245 / 328), que é calculada no painel inteiro.
- `estima()` (no 05) avisa com `warning()` quando a dependente pedida não existe na base, em vez de pular em silêncio.
Decisões de estimação:
- Erro-padrão: modelo A com Driscoll-Kraay (`vcov_dk`); modelo B com agrupado por município (`vcov_cluster`: `vcovHC`, método Arellano, HC1). `tabela_regressao(..., vcov_fun = )` escolhe.
- Efeitos aleatórios com o método Wallace-Hussain (`random.method = "walhus"`). Motivo: com variáveis que só variam no tempo (ano eleitoral, tendências, PIB nacional), a regressão "between" do método padrão (Swamy-Arora) fica singular e o modelo não roda.
- Hausman robusto implementado à mão (`hausman_mundlak`), porque `phtest(method = "aux")` ignora o `random.method` e falha. Validado em dados simulados: não rejeita sem correlação e rejeita com correlação induzida.
- **DECISÃO: efeitos fixos para as 9 dependentes.** Com a especificação do modelo A, o Hausman clássico e o robusto indicam efeitos fixos em todas (p < 0,05). Base limpa (`carrega_base()`).

Teste de Hausman com a especificação do modelo A (`03_hausman.R` → `regressao/saidas/tabelas/hausman.csv`; observações e municípios do modelo de efeitos fixos; p-valor 0 = abaixo da precisão numérica do R):

| Variável dependente | Hausman (χ²) | p-valor | Hausman robusto | p-valor (robusto) | Indicado (clássico) | Indicado (robusto) | Observações | Municípios |
|---|---|---|---|---|---|---|---|---|
| Despesa total | 3.573,83 | 0 | 267,50 | 3,34e-53 | Efeitos fixos | Efeitos fixos | 70.669 | 5.568 |
| Saúde e Saneamento | 2.258,51 | 0 | 387,08 | 1,09e-78 | Efeitos fixos | Efeitos fixos | 70.526 | 5.568 |
| Educação e Cultura | 3.911,60 | 0 | 1.113,39 | 4,92e-235 | Efeitos fixos | Efeitos fixos | 70.550 | 5.568 |
| Habitação e Urbanismo | 179,95 | 6,63e-31 | 42,92 | 9,10e-07 | Efeitos fixos | Efeitos fixos | 69.574 | 5.564 |
| Assistência Social | 2.632,55 | 0 | 142,51 | 7,12e-27 | Efeitos fixos | Efeitos fixos | 70.485 | 5.568 |
| Transporte | 944,72 | 1,12e-192 | 273,29 | 1,97e-54 | Efeitos fixos | Efeitos fixos | 54.423 | 5.205 |
| Administração | 1.627,32 | 0 | 121,72 | 1,46e-22 | Efeitos fixos | Efeitos fixos | 70.553 | 5.568 |
| Agricultura | 857,00 | 6,99e-174 | 264,36 | 1,55e-52 | Efeitos fixos | Efeitos fixos | 64.464 | 5.436 |
| Comunicações | 154,56 | 8,77e-26 | 35,63 | 2,05e-05 | Efeitos fixos | Efeitos fixos | 12.360 | 1.896 |

(Valores com % jovens = 0-19 anos, rodada de 05/10/2026.)

- Teste de reprodutibilidade (05/10/2026): `Rscript regressao/rodar_tudo.R` completo, do 01 ao 05 (R1-R15 e R7a), sem erro, em 16 min 44 s. O modelo B (`effect = "twoways"`) é o mais lento no `plm`. Tabelas em `regressao/saidas/tabelas/`: `hausman`, `regressao_principal_A`, `regressao_principal_B`, `comparacao_estimadores_despesa_total`, `robustez_R1` a `robustez_R16` e `robustez_R7a` (.csv e .docx). O R16 foi acrescentado depois e rodado só no seu bloco (1 min 14 s); o 05 inteiro não foi rodado de novo.
- Formatação das tabelas (`tabela_regressao()` no 00): coeficientes, erros-padrão e R² com vírgula decimal (`formatC(..., format = "f", decimal.mark = ",")`, ex.: 203,869); ponto de milhar só em Observações/Municípios. Argumento `vcov_fun` (padrão `vcov_cluster`) escolhe a matriz de variância. No 05, quem escolhe o erro-padrão é a `tabela_ab()` (argumentos `vcov_A`, padrão `vcov_dk`, e `vcov_B`, padrão `vcov_cluster`); `roda_teste()` recebe a tabela pronta e a nota.

## Cobertura das funções e ausências (RESOLVIDO; antigo "A VER DEPOIS", item 1)
**Ausência ≠ zero.** A classificação por função/subfunção é feita pela prefeitura; um gasto pode estar lançado em outra conta (ex.: publicidade em Administração Geral 04.122/04.999 ou dentro da própria área). Não preencher automaticamente com 0.

Tabela de cobertura (`regressao/01b_cobertura.R` rodado na base real; saídas `regressao/saidas/tabelas/cobertura_funcoes.csv` e `cobertura_grupos.csv`). Nº de municípios. "Todos os anos" = informa a função em todos os anos em que o município aparece no Siconfi (não necessariamente os 13); "Parte" = em alguns desses anos; "com buraco" = dentro de "Parte", falta algum ano entre o primeiro e o último informado; "Nenhum" = nunca informa.

| Função | Conta | Todos os anos | Parte dos anos | Parte: com buraco | Nenhum ano | Linhas com valor zero | Média de municípios/ano |
|---|---|---|---|---|---|---|---|
| Administração | 3.04.000 | 5.447 | 122 | 109 | 0 | 0 | 5.474 |
| Assistência Social | 3.08.000 | 5.382 | 187 | 154 | 0 | 0 | 5.466 |
| Previdência Social | 3.09.000 | 2.134 | 1.333 | 493 | 2.102 | 2 | 2.855 |
| Saúde | 3.10.000 | 5.395 | 174 | 136 | 0 | 0 | 5.468 |
| Educação | 3.12.000 | 5.430 | 139 | 115 | 0 | 0 | 5.470 |
| Cultura | 3.13.000 | 4.109 | 1.426 | 1.107 | 34 | 0 | 5.071 |
| Urbanismo | 3.15.000 | 5.043 | 515 | 396 | 11 | 0 | 5.375 |
| Habitação | 3.16.000 | 427 | 3.035 | 1.537 | 2.107 | 1 | 1.419 |
| Saneamento | 3.17.000 | 1.797 | 2.950 | 1.899 | 822 | 1 | 3.219 |
| Agricultura | 3.20.000 | 4.245 | 1.191 | 858 | 133 | 1 | 4.999 |
| Comunicações | 3.24.000 | 328 | 1.568 | 609 | 3.673 | 2 | 958 |
| Transporte | 3.26.000 | 2.984 | 2.225 | 1.391 | 360 | 1 | 4.220 |

| Grupo | Todos os anos | Parte dos anos | Parte: com buraco | Nenhum ano | Linhas com valor zero | Média de municípios/ano |
|---|---|---|---|---|---|---|
| saude_saneamento | 5.411 | 158 | 125 | 0 | 0 | 5.470 |
| educ_cultura | 5.440 | 129 | 106 | 0 | 0 | 5.471 |
| habit_urbanismo | 5.086 | 480 | 383 | 3 | 0 | 5.395 |
| assistencia | 5.382 | 187 | 154 | 0 | 0 | 5.466 |
| transporte | 2.984 | 2.225 | 1.391 | 360 | 1 | 4.220 |
| administracao | 5.447 | 122 | 109 | 0 | 0 | 5.474 |
| agricultura | 4.245 | 1.191 | 858 | 133 | 1 | 4.999 |
| comunicacoes | 328 | 1.568 | 609 | 3.673 | 2 | 958 |
| assist_previdencia | 5.407 | 162 | 133 | 0 | 0 | 5.469 |

- Nos grupos Saúde+Saneamento e Habitação+Urbanismo, a função pequena (Saneamento 3.17, Habitação 3.16) tem cobertura irregular, mas o grupo aparece quase sempre por causa da função grande.
- Zeros e negativos nas 9 dependentes principais (conferido no `base_regressao.rds`): 7 negativos (Assistência 1, Transporte 1, Administração 5) e 4 zeros (Transporte 1, Agricultura 1, Comunicações 2). Mantidos como estão (no log, zero e negativo viram NA).
- `base_regressao.rds`: 71.307 município-anos, 5.569 municípios, 4.769 presentes nos 13 anos.
- **DECISÃO TOMADA (opção A):** ausência não vira zero. Quando o município não informa nenhuma função do grupo no ano, a variável fica NA e o município-ano sai daquela regressão (regra já implementada no `01_base_regressao.R`; não mudar). Robustez: Transporte, Agricultura e Comunicações reestimados só com os municípios que informam a função em todos os anos em que aparecem no Siconfi (teste R9 do `05_robustez.R`).

## Limpeza da base (DECIDIDO)
Feita no `01_base_regressao.R` (etapa 5b). A base salva NÃO apaga linhas nem valores originais: guarda a receita original numa coluna própria e só cria colunas de marcação. Quem tira os município-anos marcados é o `carrega_base()` (`00_configuracao.R`).
- **Receita tributária (a):** `receita_tributaria_real_pc_bruta` = cópia da original. Em `receita_tributaria_real_pc` (a usada no modelo), NA quando `sigla_uf == "TO" & ano == 2024` OU valor < 0. Motivo: em TO 2024 a mediana cai de 493 (2023) para 353 e volta a 501 (2025), com 31 municípios negativos; erro de lançamento do estado no ano. Atinge 141 município-anos: 137 de TO 2024 e 35 negativos (31 deles em TO 2024; os outros 4 são TO 2021 = 1 e GO 2024 = 3).
- **Despesa (b):** `mediana_despesa_total_pc` = mediana de `despesa_total_pc` do município nos seus anos; `outlier_despesa = 1` quando `despesa_total_pc < 0,2 × mediana` ou `> 5 × mediana`, 0 caso contrário (inclusive quando `despesa_total_pc` é NA). Motivo: quedas/saltos isolados de um ano em séries normais (ex.: MA 2013, 3170701 MG 2022-2023).
- **Município-anos com `outlier_despesa = 1`: 66** (62 abaixo de 0,2× a mediana, 4 acima de 5×). Por ano: 2013: 14; 2014: 2; 2015: 1; 2016: 12; 2017: 9; 2018: 2; 2019: 4; 2020: 5; 2021: 1; 2022: 4; 2023: 4; 2024: 4; 2025: 4. **12 deles são de 2016, ano eleitoral**: por isso o **R10 (sem limpeza) é o teste de robustez principal dessa decisão.**
- Base: 71.307 município-anos sem limpeza; 71.241 com limpeza (`outlier_despesa == 0`).
- Robustez: R10 (sem limpeza: mantém os outliers e usa a receita original) e R11 (winsorização nos percentis 1 e 99 de cada ano, a partir da base sem limpeza de despesa, com a receita já corrigida).
- Descritivas (`02_descritivas.R`) refeitas com a base limpa.

## A VER DEPOIS: qualidade dos dados e cuidados (não resolvido)
1. *(Resolvido: ver seção "Cobertura das funções e ausências".)*
2. **Comunicações (função 24) é sobretudo infraestrutura** (telecomunicações, postais, demais subfunções). Gasto com publicidade/divulgação fica em Comunicação Social (`3.04.131`, ~1.040 municípios/ano, 0,15% do gasto). Decidido por ora usar só a função 24 (comparação com Sakurai); `3.04.131` fica como possível extensão. Se usada junto com Administração, definir Administração = 3.04.000 − 3.04.131.
3. **Lei eleitoral (Lei 9.504/1997, art. 73)**: proíbe publicidade institucional nos 3 meses antes da eleição e limita gastos com publicidade no ano eleitoral. Com dado anual, alta no 1º semestre e bloqueio no 2º podem se compensar. Conferir redação vigente.
4. *(Resolvido: feito no teste R4, participação de cada grupo na despesa total, %, como Teixeira e Mattos, 2021.)*
5. **Vinculações constitucionais**: mínimos de Saúde (15%) e Educação (25%) das receitas de impostos limitam a margem do prefeito; usar na interpretação.
6. **Subfunções não comparáveis antes de 2016** ("Administração Geral" 122 surge em 2016, antes estava em 999). Só afeta se alguma subfunção for usada.
7. *(Resolvido: forma principal per capita em nível, como Sakurai; log feito no teste R3.)*
8. *(Resolvido: substituído pela seção "Variáveis explicativas e especificação: modelos A e B". O efeito de ano é usado no modelo B, sem a dummy de ano eleitoral; o modelo A mantém o ano eleitoral com tendências e erro-padrão de Driscoll-Kraay.)*

## Pendências
Cobertura temporal: PIB municipal só até 2023 (por isso entra só na robustez R7; o PIB nacional cobre 2013-2025). Siconfi 2025 tem menos municípios (~5.440 contra ~5.550). Receitas têm queda de cobertura em 2014 (~5.180 municípios). População 2024-25 já corrigida (ver IBGE anual).
- Scripts de R já rodados na base real (01, 01b, 02, 03, 04 e 05).
- 49 municípios sem prefeito eleito na eleição de 2024 (provavelmente eleição anulada sem suplementar na base): afeta o ano financeiro 2025 (49 município-anos de 2025 com partido, segundo_mandato e coalizões vazios). Documentar como limitação.
- Despesas por função no corpo do trabalho; investimentos (Anexo 2, natureza da despesa, municipio_despesas_orcamentarias) ficam como robustez.
Variáveis do Censo (`perc_jovens`, `perc_idosos`, `grau_urb`): dentro do município, só variam pela interpolação linear 2010-2022 e ficam constantes em 2023-2025 (forward fill). Ficam como controles nos modelos principais (como Sakurai, 2009), com coeficientes não interpretados; o R15 testa os modelos sem elas. 45 município-anos sem esses dados (6 municípios criados depois de 2010: 1504752, 4212650, 4220000, 4314548, 5006275 e 5101837), que saem das regressões. Úteis também para descritivas e heterogeneidade.

## Convenções
Responder em português.
Manter o padrão de cache por os.path.exists em cada consulta ao BigQuery.
Caminhos de arquivo sempre via `codigo/caminhos.py` (novos arquivos: criar a constante lá primeiro).
Scripts rodam em VS Code com células # %%; usar print em vez de display em .py.
R: todo script começa com `source(here::here("regressao", "00_configuracao.R"))`; nunca usar `setwd` nem caminho absoluto; arquivos em UTF-8; nomes de coluna com acento sempre entre aspas (`c("Variável" = ...)`), senão o script quebra em computador com outra codificação. Os scripts têm de rodar tanto no terminal (`Rscript`) quanto no RStudio.
Em GROUP BY, usar nomes de colunas em vez de posições (GROUP BY 1, 2...).
Antes de afirmar algo sobre a estrutura dos dados, verificar com código. Não supor hierarquia de contas.
Antes de mudar uma regra que altera variáveis do modelo, mostrar o efeito (antes × depois) e pedir aprovação.
A usuária prefere código simples e explicado, que ela consiga ler e rodar.