# Memorial metodológico

Ciclos Políticos Orçamentários e finanças municipais no Brasil (2013-2025)

Documento de estudo para a defesa na banca. Explica cada decisão do trabalho, por que foi tomada, o que se testou no lugar e onde ela está no código.

**De onde vêm os números.** Todos os números deste memorial vêm do `CLAUDE.md` ou das tabelas em `regressao/saidas/tabelas/`, na versão de 05/10/2026: % jovens = 0-19 anos, modelos A e B, testes R1 a R16 e R7a.

**Unidades.**
- Coeficientes das despesas: R$ de 2025 por habitante (per capita em nível), salvo quando indicado.
- Estrelas: \*\*\* p<0,01; \*\* p<0,05; \* p<0,1; "n.s." = não significativo a 10%.

**Formato de cada decisão** (sempre o mesmo):

- **O que foi feito**
- **Por quê**
- **Alternativa considerada**
- **Efeito no resultado** (com o teste de robustez que mostra isso, quando há um)
- **Onde está no código**

Os links de código apontam para o arquivo e a linha na versão atual.

> Este memorial descreve o que foi feito e o que as tabelas mostram. A interpretação econômica dos resultados é da autora.

---

## 1. Dados e fontes

A fonte principal é a **Base dos Dados** (BigQuery, projeto de cobrança `monografia-508123`). Cada consulta é guardada em cache (`dados/cache/`), e o pipeline pode ser refeito sem baixar nada de novo.

### 1.1 Despesas municipais (Siconfi)

- **O que foi feito:** despesas por função de governo, tabela `br_me_siconfi.municipio_despesas_funcao` (Anexo 1-E do RREO), estágio **"Despesas Pagas"**, Brasil inteiro, 2013-2025. O painel bruto tem 3.281.067 linhas (município × ano × conta).
- **Por quê:** a classificação por função (Portaria 42/1999) permite separar áreas de gasto (Saúde, Educação, Urbanismo etc.), como em Sakurai (2009).
- **Alternativa considerada:** despesa por natureza (Anexo 2, `municipio_despesas_orcamentarias`), que permitiria olhar investimentos. Ficou como possível extensão.
- **Efeito no resultado:** nenhum teste específico. O formato dos códigos é estável de 2013 a 2025 e as 28 funções existem nos 13 anos.
- **Onde está no código:** [main_code.py, Célula 1](../codigo/main_code.py#L3).

### 1.2 Receitas municipais (Siconfi), usadas como controles

- **O que foi feito:** tabela `br_me_siconfi.municipio_receitas_orcamentarias`, estágio "Receitas Brutas Realizadas". Duas contas:
  - **receita tributária**, `id_conta_bd` 1.1.1.0.0.00.00.00 (impostos, taxas e contribuição de melhoria);
  - **transferências correntes**, 1.1.7.0.0.00.00.00.
- **Por quê:** são os controles de receita de Sakurai (2009). Usou-se o valor da conta "mãe" direto, sem somar mãe com filhas (isso contaria em dobro).
- **Alternativa considerada:** só as transferências da União e dos Estados, como em Sakurai. Exigiria uma regra por ano, porque o código da portaria muda em 2018, e ficou como possível robustez.
- **Efeito no resultado:** validação, não teste. A conta 1.1.1.0 é igual à soma das filhas em 100% dos 71.333 município-anos. A 1.1.7.0 é igual em 100% dos 71.316, exceto cerca de 2 casos em 2013.
- **Onde está no código:** [explora_receitas.py, Células 2 e 3](../codigo/explora_receitas.py#L113); validação em [teste_mae_filho.py](../codigo/exploracao/teste_mae_filho.py).

### 1.3 Eleições (TSE, via Base dos Dados)

- **O que foi feito:**
  - prefeitos eleitos em 2008, 2012, 2016, 2020 e 2024 (`resultados_candidato` + `candidatos`, 28.185 eleitos);
  - governadores e presidentes eleitos em 2010, 2014, 2018 e 2022;
  - coligações das chapas (tabela `partidos`, campo `composicao_coligacao`).
  - A eleição de 2008 só serve de referência para o segundo mandato em 2012.
- **Por quê:** é a fonte oficial do partido do prefeito e das coligações vencedoras.
- **Alternativa considerada:** nenhuma outra fonte para o período inteiro. Para 2010 foi preciso o arquivo do próprio TSE (ver 2.7).
- **Efeito no resultado:** ver as decisões de montagem (seção 2) e os testes R1, R2 e R6.
- **Onde está no código:** [main_code.py, Células 2 e 3](../codigo/main_code.py#L70).

### 1.4 População e PIB municipal (IBGE)

- **O que foi feito:**
  - população: `br_ibge_populacao.municipio`, até 2025;
  - PIB municipal: `br_ibge_pib.municipio`, só até 2023, juntado com LEFT JOIN.
- **Por quê:** a população é o denominador do per capita e entra como controle (em log). Com INNER JOIN, a população de 2024-25 sumia junto com o PIB inexistente, e todo per capita desses anos ficava vazio, inclusive no ano eleitoral de 2024.
- **Alternativa considerada:** usar o PIB municipal como controle principal. Isso cortaria 2024-2025 da amostra; ver 2.9 e os testes R7 e R7a.
- **Efeito no resultado:** com o LEFT JOIN, 2024 e 2025 entram na regressão.
- **Onde está no código:** [main_code.py, Célula 4](../codigo/main_code.py#L400).

### 1.5 IPCA, PIB nacional e Censo (SIDRA/IBGE)

- **O que foi feito:**
  - **IPCA:** tabela 1737, variável 2266 (número-índice mensal), cache em `ipca_mensal.csv`.
  - **PIB nacional:** tabela 1846 (Contas Nacionais Trimestrais), variável 585, soma dos 4 trimestres de cada ano, cache em `pib_nacional_trimestral.csv`. Baixado em 05/10/2026.
  - **Censo 2010 e 2022:** urbanização (tabelas 202 e 9923) e idade (tabelas 200 e 9514).
- **Por quê:** o IPCA deflaciona os valores. O PIB nacional é o controle de ciclo econômico de Sakurai (2009). O Censo dá a demografia.
- **Alternativa considerada:** a tabela anual de PIB 6784, que só vai até 2023. Por isso se usou a trimestral.
- **Efeito no resultado:** validação, não teste. De 2013 a 2023, a trimestral é igual à anual em 8 anos; as diferenças nos outros são de −0,11% (2017), +0,10% (2018) e −0,07% (2019). A soma dos PIBs municipais de 2023 dividida pelo PIB nacional dá 1,0000. **Os valores de 2024 e 2025 são preliminares.**
- **Onde está no código:** [explora_receitas.py, Célula 4](../codigo/explora_receitas.py#L233); Censo em [main_code.py, Célula 5](../codigo/main_code.py#L436).

---

## 2. Montagem da base

### 2.1 Só as linhas de função (3.FF.000)

- **O que foi feito:** para as dependentes, só as linhas com `id_conta_bd` no formato `3.FF.000` (as 28 funções), sem o total `3.00.000`.
- **Por quê:** o mesmo dinheiro aparece três vezes no painel: no total, na função e na subfunção. Somar tudo contaria em dobro. A hierarquia foi conferida:
  - soma das subfunções = função em ≥ 99,98% dos município-anos;
  - soma das funções = total em 100% (2014 em diante).
- **Alternativa considerada:**
  - Usar a linha de total `3.00.000` para a despesa total. Ela não existe em 2013, e o total sem código de 2013 bate com a soma das funções em só 99,5% dos municípios.
  - Usar subfunções. Não são comparáveis antes de 2016 ("Administração Geral" 122 surge em 2016).
- **Efeito no resultado:** a despesa total tem uma definição única nos 13 anos. De 2014 em diante, é idêntica ao total oficial.
- **Onde está no código:** [01_base_regressao.R:48](../regressao/01_base_regressao.R#L48).

### 2.2 Despesas intraorçamentárias

- **O que foi feito:** foram retiradas as linhas de despesa intraorçamentária (pagamentos entre órgãos do próprio município). Remove 20.504 linhas.
- **Por quê:** é dinheiro que circula dentro da própria prefeitura. As linhas não têm código e o nome muda entre 2013 e 2014, então o filtro é pelo nome: contém "intra" e não contém "exceto".
- **Alternativa considerada:** filtrar pelo nome exato. Isso tirava só 19.530 linhas e deixava as 974 de 2013.
- **Efeito no resultado:** não muda as dependentes, que vêm das funções. Deixa o painel coerente.
- **Onde está no código:** [main_code.py:60](../codigo/main_code.py#L60).

### 2.3 Um prefeito por município-ano: a regra de 1º de julho

- **O que foi feito:**
  - Cada eleito assume em 1º de janeiro do ano seguinte à eleição (ordinária) ou na data da eleição suplementar.
  - Em cada ano, fica o **último a assumir até 1º de julho**, isto é, quem governou a maior parte do ano.
  - Se ninguém do mandato assumiu até essa data, o município-ano fica **sem prefeito**: partido, segundo mandato e coalizões ficam vazios, não 0. São 214 município-anos.
- **Por quê:** com eleições suplementares, um município pode ter mais de um eleito no mesmo mandato, e isso duplicava linhas do painel.
- **Alternativa considerada:** ficar sempre com o eleito na ordinária. Isso atribuiria o ano a quem já não governava.
- **Efeito no resultado:** o teste **R2** retira os município-anos com prefeito ou governador de suplementar. O modelo A passa de 70.669 para 69.424 observações (Despesa total) e o padrão de significância do ano eleitoral se mantém (Despesa total 279,523\*\*\*).
- **Onde está no código:** [main_code.py:165](../codigo/main_code.py#L165).

### 2.4 Eleições suplementares

- **O que foi feito:** a Base dos Dados grava a suplementar sob o ano da ordinária (por exemplo, uma suplementar de fevereiro de 2023 aparece com ano 2020). Cada município-eleição tem no máximo 1 ordinária e de 0 a 2 suplementares:
  - 405 grupos com 1 suplementar;
  - 5 com 2;
  - 116 só com suplementar.

  Foram criadas as colunas `prefeito_suplementar` e `governador_suplementar`. Esta última marca AM 2017, AM 2018 e TO 2018, com datas de cassação e posse conferidas em fontes externas.
- **Por quê:** separar os casos atípicos e poder testá-los.
- **Alternativa considerada:** descartar as suplementares. Isso perderia os prefeitos que de fato governaram.
- **Efeito no resultado:** teste **R2** (ver 2.3).
- **Onde está no código:** [main_code.py, Célula 2](../codigo/main_code.py#L70) e [main_code.py:305](../codigo/main_code.py#L305).

### 2.5 Segundo mandato

- **O que foi feito:** `segundo_mandato` = 1 se o prefeito do ano é a mesma pessoa que estava no cargo ao fim do mandato anterior, olhando exatamente a eleição de 4 anos antes. "Mesma pessoa" significa:
  - título de eleitor igual; ou
  - CPF igual; ou
  - só quando falta o título, nome padronizado igual.
- **Por quê:** o método anterior (comparar com a linha de cima) errava quando havia suplementares. Nos pares com os dois identificadores, CPF e título concordam em 99,9%.
- **Alternativa considerada:** só o título. Há 5 casos com o mesmo CPF e título diferente (título trocado).
- **Efeito no resultado:** 220 município-anos passaram de 0 para 1, nenhum de 1 para 0. A variável só entra na robustez (**R6**): os coeficientes de ano eleitoral e de coalizões quase não mudam (Despesa total 277,917\*\*\* no modelo A).
- **Onde está no código:** [main_code.py:152](../codigo/main_code.py#L152).

### 2.6 Siglas partidárias e fusões

- **O que foi feito:** as siglas foram padronizadas dos dois lados (prefeito e coligação).
  - **Renomeações**, sempre aplicadas (ex.: PMDB→MDB, PR→PL, PRB→REPUBLICANOS).
  - **Fusões e incorporações** (ex.: DEM e PSL→UNIÃO em 2022), aplicadas **só quando o ano da fusão cai entre as duas eleições comparadas**.
  - Também se tiraram os parênteses das federações de 2022.
- **Por quê:** a Base dos Dados grava a eleição municipal de 2016 com as siglas novas e as coligações de 2014 com as antigas. Sem padronizar, um prefeito do MDB de 2016 não "casava" com o PMDB da chapa de 2014.
- **Alternativa considerada:** aplicar a fusão sempre. Isso geraria falsos 1, de cerca de 275 a 477 município-anos por ano em `coalizao_pres` em 2019-22. Por exemplo, um prefeito do DEM de 2016 e uma chapa PSL/PRTB de 2018 não eram aliados.
- **Efeito no resultado:**
  - A padronização fez cerca de 830 município-anos por ano (governador) e cerca de 1.470 por ano (presidente) passarem de 0 para 1 em 2017-18; nenhum passou de 1 para 0.
  - O teste **R1** (sem fusões, só renomeações) mantém a coalizão do governador na Despesa total (28,511\*\*\* contra 31,560\*\*\*). Em Saúde, ela passa de 4,704\*\* para 3,295 (n.s.).
- **Onde está no código:** [main_code.py:319](../codigo/main_code.py#L319) (`RENOMEACOES`), [main_code.py:338](../codigo/main_code.py#L338) (`FUSOES`) e [main_code.py:350](../codigo/main_code.py#L350) (`padroniza_sigla`).

### 2.7 Coligações de 2010

- **O que foi feito:** na Base dos Dados, a tabela `partidos` tem a coligação vazia em 2010 e não tem o presidente de 2010. A composição veio do arquivo oficial do TSE (`consulta_coligacao_2010`). O partido eleito veio de `resultados_candidato`; para presidente, é o mais votado no 2º turno (PT).
- **Por quê:** sem isso, as dummies de coalizão de 2013-14 ficavam zeradas.
- **Alternativa considerada:** reconstruir a coligação pela própria Base dos Dados (partidos com o mesmo `sequencial_coligacao`). Foi usada como validação: dá o mesmo resultado nos 27 governadores (27/27).
- **Efeito no resultado:** 2013 e 2014 passam a ter coalizões válidas.
- **Onde está no código:** [main_code.py:229](../codigo/main_code.py#L229).

### 2.8 Deflação pelo IPCA médio anual

- **O que foi feito:** valor real = valor nominal × (média do IPCA de 2025 ÷ média do IPCA do ano). Tudo fica em **R$ de 2025**. Foram deflacionadas a despesa, as receitas e o PIB.
- **Por quê:** receitas, despesas e PIB são fluxos do ano civil (Lei 4.320, arts. 34-35; MCASP: a receita é registrada na arrecadação). Por isso o deflator é a média dos 12 meses, e não o índice de dezembro.
- **Alternativa considerada:** IGP-DI, usado por Sakurai (2009), em R$ de 2006. Fica como diferença declarada em relação a ele.
- **Efeito no resultado:** nenhum teste específico. É diferença de método a declarar.
- **Onde está no código:** [explora_receitas.py:268](../codigo/explora_receitas.py#L268).

### 2.9 PIB nacional como controle principal

- **O que foi feito:** `pib_nacional_tri` = PIB nacional real em R$ trilhões, o mesmo valor para todos os municípios no ano, sem vazios de 2013 a 2025.
- **Por quê:** é o controle de Sakurai (2009) e existe em todos os anos. O PIB municipal só vai até 2023.
- **Alternativa considerada:** PIB municipal per capita (em log), que tiraria 2024-2025.
- **Efeito no resultado:**
  - **R7** (PIB municipal, 2013-2023): ano eleitoral na Despesa total = 129,219\*.
  - **R7a** (especificação principal, mesma amostra 2013-2023): 66,596 (n.s.).
  - No principal: 277,865\*\*\*.
  - A comparação R7 × R7a mostra que a maior parte da mudança vem da amostra (sem 2024), não da troca do PIB.
- **Onde está no código:** [01_base_regressao.R:110](../regressao/01_base_regressao.R#L110).

---

## 3. Variáveis dependentes

### 3.1 Os 9 grupos

| # | Variável | Funções (`id_conta_bd`) |
|---|---|---|
| 0 | Despesa total | soma das 28 funções (3.01 a 3.28) |
| 1 | Saúde e Saneamento | 3.10 + 3.17 |
| 2 | Educação e Cultura | 3.12 + 3.13 |
| 3 | Habitação e Urbanismo | 3.16 + 3.15 |
| 4 | Assistência Social | 3.08 (sem Previdência) |
| 5 | Transporte | 3.26 |
| 6 | Administração | 3.04 |
| 7 | Agricultura | 3.20 |
| 8 | Comunicações | 3.24 |

- **O que foi feito:** agrupamentos como os de Sakurai (2009), com três ajustes: Assistência sem Previdência, Administração incluída e Comunicações só com a função 24. Todas as variáveis estão em R$ de 2025 per capita, em nível.
- **Por quê:**
  - Previdência (função 9, regime próprio) é gasto obrigatório, com pouca margem para o prefeito.
  - Administração é gasto pouco visível, citado por Teixeira e Mattos (2021).
  - Sakurai encontrou efeito positivo do ano eleitoral em Comunicações (0,280\*\*\*).
- **Alternativa considerada:**
  - Assistência + Previdência, como Sakurai: teste **R8**.
  - Variável em log: teste **R3**.
  - Participação na despesa total: teste **R4**.
- **Efeito no resultado:**
  - **R8:** ano eleitoral 10,004 (n.s.) e pré-eleitoral 10,708 (n.s.), contra 14,078\*\*\* e 9,468\*\* só com Assistência.
  - R3 e R4: ver a seção 7.
- **Onde está no código:** [00_configuracao.R:46](../regressao/00_configuracao.R#L46) (`GRUPOS`) e [01_base_regressao.R:61](../regressao/01_base_regressao.R#L61) (`soma_grupo`).

### 3.2 Soma das funções e despesa total

- **O que foi feito:** cada grupo é a soma das funções que o município informou naquele ano. A despesa total é a soma das 28 funções informadas, e não só das escolhidas.
- **Por quê:** é a mesma definição em todos os anos e coerente com os grupos (ver 2.1).
- **Alternativa considerada:** a linha de total oficial `3.00.000` (ver 2.1).
- **Efeito no resultado:** sem teste específico.
- **Onde está no código:** [01_base_regressao.R:68-75](../regressao/01_base_regressao.R#L68-L75).

### 3.3 Ausência ≠ zero

- **O que foi feito:** se o município não informou nenhuma função do grupo no ano, o grupo fica **vazio (NA)**, não zero, e esse município-ano sai daquela regressão.
- **Por quê:** quem classifica o gasto por função é a prefeitura, e um gasto pode estar lançado em outra conta (ex.: publicidade dentro de Administração Geral). Pôr zero criaria quedas e subidas artificiais.
- **Alternativa considerada:** preencher com zero; ou usar só os municípios que informam sempre.
- **Efeito no resultado:**
  - A cobertura é desigual. Média de municípios por ano: Comunicações 958, Transporte 4.220, Agricultura 4.999, Administração 5.474.
  - O teste **R9** usa só os municípios que informam a função em todos os anos em que aparecem (3.000 em Transporte, 4.264 em Agricultura, 330 em Comunicações).
  - Resultados do R9: ano eleitoral em Transporte = 48,686\*\*\* (principal 41,741\*\*\*); Comunicações = −0,300\* (principal −0,801\*\*\*).
- **Onde está no código:** [01_base_regressao.R:61-75](../regressao/01_base_regressao.R#L61-L75); cobertura em [01b_cobertura.R](../regressao/01b_cobertura.R); R9 em [05_robustez.R:150](../regressao/05_robustez.R#L150).

---

## 4. Variáveis explicativas e controles

### 4.1 Variáveis de interesse

- **O que foi feito:**
  - `ano_eleitoral` = 1 em 2016, 2020 e 2024;
  - `pre_eleitoral` = 1 em 2015, 2019 e 2023;
  - `pandemia_2020` = 1 em 2020;
  - `coalizao_gov` = 1 se o partido do prefeito está na coligação do governador eleito do estado;
  - `coalizao_pres` = 1 se está na coligação do presidente eleito.
- **Por quê:**
  - O ano eleitoral é o centro da hipótese do ciclo.
  - O pré-eleitoral capta gastos antecipados.
  - A pandemia separa o choque de 2020, que também foi ano eleitoral.
  - As coalizões medem o alinhamento político.
- **Alternativa considerada:**
  - Sem pré-eleitoral e sem pandemia, como Sakurai: teste **R5**.
  - Sem pandemia: teste **R14**.
  - Uma dummy para cada eleição: teste **R16**.
- **Efeito no resultado:**
  - Com a dummy de pandemia, o ano eleitoral do modelo A é identificado pelas eleições de **2016 e 2024**.
  - Sem a dummy (**R14**), Educação e Cultura passa de 49,079\* para −10,566 (n.s.).
- **Onde está no código:** [01_base_regressao.R:102-104](../regressao/01_base_regressao.R#L102-L104) e [00_configuracao.R:99-101](../regressao/00_configuracao.R#L99-L101).

### 4.2 Controles

- **O que foi feito:**
  - receita tributária per capita;
  - transferências correntes per capita;
  - % jovens, % idosos e grau de urbanização;
  - população (log);
  - PIB nacional (R$ trilhões);
  - tendência (ano − 2012) e tendência ao quadrado.
  - No modelo B, só os seis primeiros desta lista (os que variam entre municípios).
- **Por quê:** são os controles de Sakurai (2009), que também usou tendência linear e quadrática.
- **Alternativa considerada:** PIB municipal (**R7**); sem as variáveis do Censo (**R15**).
- **Efeito no resultado:** ver 4.4 e a seção 7.
- **Onde está no código:** [00_configuracao.R:102-107](../regressao/00_configuracao.R#L102-L107); transformações em [01_base_regressao.R:106-111](../regressao/01_base_regressao.R#L106-L111).

### 4.3 % jovens = 0-19 anos

- **O que foi feito:** `perc_jovens` = população de 0 a 19 anos ÷ população total, como proporção de 0 a 1.
- **Por quê:** decisão da autora (05/10/2026): é a faixa usual de demanda por educação. As duas tabelas do Censo têm as faixas 0-4, 5-9, 10-14 e 15-19 separadas de 20-24, então 0-19 é exato nos dois censos.
- **Alternativa considerada:** 0-24 anos, que o código usava antes por engano (incluía "20 a 24 anos").
- **Efeito no resultado:**
  - A média de `perc_jovens` caiu de 0,410 para 0,328 em 2013 e de 0,347 para 0,275 em 2022-2025. A correlação entre as duas versões é 0,992.
  - Nas regressões, os coeficientes de interesse quase não mudaram. A única mudança de significância foi o ano eleitoral em Educação e Cultura (de 49,116, n.s., para 49,079\*).
- **Onde está no código:** [main_code.py:479](../codigo/main_code.py#L479).

### 4.4 O problema das variáveis do Censo com efeito fixo

- **O que foi feito:** grau de urbanização, % jovens e % idosos só existem em 2010 e 2022. Os anos de 2011 a 2021 são **interpolados linearmente**, e 2023-2025 repetem 2022.
  - Dentro de cada município, a única variação dessas variáveis é essa interpolação, uma reta que fica constante depois de 2022.
  - Elas ficam nos controles (como em Sakurai), mas **seus coeficientes não são interpretados**.
  - Há 45 município-anos sem esses dados (6 municípios criados depois de 2010).
- **Por quê:** manter a especificação comparável à de Sakurai. Com efeito fixo de município, essa "variação" é artificial, e por isso os coeficientes não são lidos.
- **Alternativa considerada:** tirar as três variáveis: teste **R15**.
- **Efeito no resultado (R15):**
  - Modelo A, ano eleitoral na Despesa total: 277,669\*\*\* contra 277,865\*\*\*.
  - Modelo B, coalizão do governador: 31,000\*\*\* contra 31,560\*\*\*.
  - A coalizão presidencial em Transporte passa de −12,466\*\*\* para −15,707\*\*\*.
- **Onde está no código:** [main_code.py:554](../codigo/main_code.py#L554) (interpolação) e [05_robustez.R:205](../regressao/05_robustez.R#L205) (R15).

---

## 5. Limpeza da base

A base salva não apaga nada: só cria colunas de marcação. Quem retira os município-anos marcados é a função `carrega_base()`.

- Sem limpeza: 71.307 município-anos.
- Com limpeza: 71.241.

### 5.1 Receita tributária de Tocantins em 2024 e valores negativos

- **O que foi feito:** a receita tributária per capita usada no modelo vira vazio (NA) em **Tocantins 2024** e quando é **negativa**. São 141 município-anos:
  - 137 de TO 2024;
  - 35 negativos, sendo 31 deles em TO 2024, 1 em TO 2021 e 3 em GO 2024.

  A original fica guardada em `receita_tributaria_real_pc_bruta`.
- **Por quê:** em TO 2024, a mediana cai de 493 (2023) para 353 e volta a 501 (2025), com 31 municípios negativos. É um erro de lançamento do estado no ano. Receita tributária negativa não faz sentido econômico.
- **Alternativa considerada:** usar a receita original: teste **R10**.
- **Efeito no resultado:** ver 5.2 (o R10 desfaz as duas limpezas juntas).
- **Onde está no código:** [01_base_regressao.R:128-134](../regressao/01_base_regressao.R#L128-L134).

### 5.2 Outliers de despesa: 0,2× e 5× a mediana do município

- **O que foi feito:** `outlier_despesa` = 1 quando a despesa total per capita do ano é **menor que 0,2×** ou **maior que 5×** a mediana do próprio município. São 66 município-anos:
  - 62 abaixo, 4 acima;
  - **12 deles em 2016, ano eleitoral.**
- **Por quê:** são quedas ou saltos isolados de um ano em séries normais (ex.: MA 2013, município 3170701 em MG em 2022-2023), que parecem erro de registro.
- **Alternativa considerada:**
  - Não limpar: teste **R10**.
  - Winsorizar (limitar aos percentis 1 e 99 de cada ano): teste **R11**.
- **Efeito no resultado:**
  - **R10:** ano eleitoral na Despesa total = 284,240\*\*\* (principal 277,865\*\*\*).
  - **R11:** 292,138\*\*\*.
  - O padrão de significância do ano eleitoral e do pré-eleitoral se mantém nos dois.
  - Como 12 dos outliers caem em 2016, o **R10 é o teste principal dessa decisão**.
- **Onde está no código:** [01_base_regressao.R:139-146](../regressao/01_base_regressao.R#L139-L146) e [00_configuracao.R:224](../regressao/00_configuracao.R#L224) (`carrega_base`).

---

## 6. Modelos, Hausman e erros-padrão

### 6.1 Por que a especificação mudou (os R12 e R13 antigos)

- **O que foi feito:** antes havia um modelo só, a especificação de Sakurai: efeito fixo de município, ano eleitoral + coalizões + controles, erro agrupado por município. Dois testes daquela versão mostraram dois problemas:
  - **R12 antigo** (erro de Driscoll-Kraay): o ano eleitoral é igual para todos os municípios no mesmo ano, então precisa de um erro-padrão robusto a choques comuns a todos no ano.
  - **R13 antigo** (efeitos fixos de município e de ano): sem efeito de ano, a coalizão presidencial confunde **alinhamento com o presidente** com **o período** (quem era presidente na época).
- **Por quê:** cada pergunta passou a ter o modelo adequado. O ano eleitoral não pode ficar num modelo com efeito de ano (seria colinear: todos votam no mesmo ano). As coalizões precisam do efeito de ano.
- **Alternativa considerada:** manter o modelo único. Ele continua no trabalho como teste **R5**, que reproduz a especificação anterior com os dados atuais.
- **Efeito no resultado:** os números do R12 e do R13 antigos não foram guardados. O efeito aparece comparando o R5 com o modelo B:
  - Coalizão presidencial, Despesa total: **65,039\*\*\*** no R5 e **−9,744 (n.s.)** no modelo B.
  - Coalizão presidencial, Educação: **56,711\*\*\*** no R5 e **−1,253 (n.s.)** no modelo B.
  - No próprio modelo A, sem efeito de ano, ela também sai positiva (Despesa total 67,005\*\*\*).
- **Onde está no código:** [04_regressoes.R](../regressao/04_regressoes.R); R5 em [05_robustez.R:118](../regressao/05_robustez.R#L118).

### 6.2 Modelo A ("ciclo eleitoral")

- **O que foi feito:** efeito fixo de município. Variáveis: ano eleitoral, pré-eleitoral, pandemia, coalizões e todos os controles (inclusive PIB nacional e tendências). Erro-padrão de **Driscoll-Kraay**.
- **Por quê:** o ano eleitoral só varia no tempo. Ele precisa de tendências e do PIB nacional para separar o ciclo eleitoral da trajetória geral, e de um erro robusto a choques comuns no ano e a autocorrelação.
- **Alternativa considerada:** erro agrupado por município (teste **R12** atual).
- **Efeito no resultado:** ver a seção 8. **Leitura: ano eleitoral e pré-eleitoral vêm do modelo A.**
- **Onde está no código:** [04_regressoes.R:32](../regressao/04_regressoes.R#L32); erro-padrão em [00_configuracao.R:131](../regressao/00_configuracao.R#L131).

### 6.3 Modelo B ("coalizões")

- **O que foi feito:** efeitos fixos de município **e de ano**. Variáveis: coalizão do governador, coalizão do presidente e os controles que variam entre municípios. Erro-padrão **agrupado por município**.
- **Por quê:** o efeito de ano absorve tudo o que é comum aos municípios no ano (ciclo eleitoral, PIB nacional, presidente da época). A coalizão passa a ser comparada **dentro do mesmo ano**.
- **Alternativa considerada:** erro de Driscoll-Kraay (teste **R13** atual).
- **Efeito no resultado:** ver a seção 8. **Leitura: as coalizões vêm do modelo B.**
- **Onde está no código:** [04_regressoes.R:48](../regressao/04_regressoes.R#L48); erro-padrão em [00_configuracao.R:127](../regressao/00_configuracao.R#L127).

### 6.4 Efeitos fixos × aleatórios (Hausman)

- **O que foi feito:** para cada dependente, com a especificação do modelo A, compararam-se efeitos fixos e aleatórios por dois testes:
  - **Hausman clássico**;
  - **Hausman robusto** (versão de Mundlak/Wooldridge: inclui as médias de cada município e testa se são conjuntamente zero, com erro agrupado).
- **Por quê:** o clássico supõe erros sem heterocedasticidade e sem correlação no tempo, o que é pouco realista aqui. O robusto não depende disso.
- **Alternativa considerada:** efeitos aleatórios. Foram estimados pelo método Wallace-Hussain, porque o método padrão (Swamy-Arora) fica singular com variáveis que só variam no tempo.
- **Efeito no resultado:** os dois testes rejeitam efeitos aleatórios nas 9 dependentes (p < 0,05). **Decisão: efeitos fixos.**

| Dependente | Hausman (χ²) | p-valor | Robusto | p-valor (robusto) |
|---|---|---|---|---|
| Despesa total | 3.573,83 | 0 | 267,50 | 3,34e-53 |
| Saúde e Saneamento | 2.258,51 | 0 | 387,08 | 1,09e-78 |
| Educação e Cultura | 3.911,60 | 0 | 1.113,39 | 4,92e-235 |
| Habitação e Urbanismo | 179,95 | 6,63e-31 | 42,92 | 9,10e-07 |
| Assistência Social | 2.632,55 | 0 | 142,51 | 7,12e-27 |
| Transporte | 944,72 | 1,12e-192 | 273,29 | 1,97e-54 |
| Administração | 1.627,32 | 0 | 121,72 | 1,46e-22 |
| Agricultura | 857,00 | 6,99e-174 | 264,36 | 1,55e-52 |
| Comunicações | 154,56 | 8,77e-26 | 35,63 | 2,05e-05 |

  "p-valor 0" significa abaixo da precisão numérica do R.

  Na despesa total, os três estimadores dão um ano eleitoral parecido: pooled 251,583\*\*, efeitos fixos 277,865\*\*\* e efeitos aleatórios 257,627\*\*. Os controles municipais mudam bastante; por exemplo, população (log) vai de −68,438\*\* no pooled a −1562,263\*\*\* nos efeitos fixos.
- **Onde está no código:** [03_hausman.R:23-25](../regressao/03_hausman.R#L23-L25), [00_configuracao.R:200](../regressao/00_configuracao.R#L200) (`hausman_mundlak`) e [04_regressoes.R:66](../regressao/04_regressoes.R#L66) (comparação).

### 6.5 Os dois erros-padrão

- **O que foi feito:**
  - **Driscoll-Kraay:** robusto a correlação entre municípios no mesmo ano e a autocorrelação.
  - **Agrupado por município** (Arellano, HC1): robusto a heterocedasticidade e a correlação dentro de cada município ao longo do tempo.
- **Por quê:** cada modelo usa o erro mais adequado à variável de interesse, e o outro serve de teste (R12 e R13). O Driscoll-Kraay depende de muitos períodos, e aqui há só 13 anos. Por isso o critério de resultado sólido exige os dois.
- **Alternativa considerada:** usar um erro só para tudo.
- **Efeito no resultado:** ver a seção 8.
- **Onde está no código:** [00_configuracao.R:127-131](../regressao/00_configuracao.R#L127-L131).

### 6.6 Resultados principais

**Modelo A** (Driscoll-Kraay):

| | Desp. total | Saúde e San. | Educ. e Cult. | Hab. e Urb. | Assistência | Transporte | Administração | Agricultura | Comunicações |
|---|---|---|---|---|---|---|---|---|---|
| Ano eleitoral | 277,865\*\*\* | 53,163\*\*\* | 49,079\* | 126,814\*\*\* | 14,078\*\*\* | 41,741\*\*\* | 6,817 | 0,486 | −0,801\*\*\* |
| Ano pré-eleitoral | 162,806\* | 1,221 | 78,512\*\* | 34,083\*\* | 9,468\*\* | 8,342 | 10,347 | 5,168 | 0,656\*\*\* |
| Pandemia (2020) | −76,603 | 106,862\*\*\* | −242,843\*\*\* | 31,846\* | −0,062 | −0,516 | 22,273\*\*\* | 2,517 | 1,594\*\*\* |

**Modelo B** (agrupado por município):

| | Desp. total | Saúde e San. | Educ. e Cult. | Hab. e Urb. | Assistência | Transporte | Administração | Agricultura | Comunicações |
|---|---|---|---|---|---|---|---|---|---|
| Coalizão governador | 31,560\*\*\* | 4,704\*\* | −1,165 | 4,267 | 0,698 | 2,406 | 7,167\*\*\* | −0,560 | −0,119 |
| Coalizão presidente | −9,744 | 8,453\*\*\* | −1,253 | 0,219 | 1,003 | −12,466\*\*\* | 0,309 | −4,580\*\*\* | 0,398 |

Observações (modelos A e B): de 70.669 (Despesa total) a 12.360 (Comunicações).

---

## 7. Testes de robustez

Cada teste muda **uma coisa** em relação ao modelo principal. As exceções estão marcadas com ⚠ e são explicadas depois da tabela. "Igual ao principal" quer dizer o mesmo padrão de significância nas 9 dependentes.

| Teste | O que muda | Ano eleitoral (A) | Pré-eleitoral (A) | Coalizões (B) |
|---|---|---|---|---|
| R1 | Coalizões sem fusões (só renomeações) | Igual ao principal (Desp. total 277,672\*\*\*) | Igual (162,635\*) | Governador: Desp. total 28,511\*\*\*; Saúde perde significância (3,295); Administração 6,405\*\*. Presidente: igual |
| R2 | Sem prefeito/governador de suplementar | Igual (279,523\*\*\*) | Igual (165,013\*) | Governador: Saúde passa a 4,376\*, Adm. a 6,811\*\*. Presidente: igual |
| R3 | Dependente em log (coef. ≈ variação proporcional) | Desp. total 0,054\*\*\*; Agricultura passa a 0,061\*\*\*; Comunicações muda de sinal (0,071\*\*\*) | Desp. total 0,023 (n.s.); Agricultura 0,066\*\*\* | Governador: Desp. total 0,003\*\*\*, Educ. 0,003\*, Hab. 0,016\*\*, Adm. 0,006\*\*. Presidente: Transporte muda de sinal (0,054\*\*\*); Adm. 0,007\*; Saúde e Agricultura n.s. |
| R4 | Participação na despesa total (%) | Educ. −0,487\*\*\*, Hab. 1,437\*\*\*, Transp. 0,429\*\*\*, Adm. −0,457\*\*\*, Saúde n.s. | Saúde −0,757\*\*\*, Educ. 0,737\*\*\*, Hab. 0,210\*\* | Governador: Saúde −0,097\*\*\*, Educ. −0,114\*\*\*. Presidente: nenhum significativo |
| R5 ⚠ | Especificação de Sakurai: sem pré-eleitoral e sem pandemia, erro agrupado (só A) | Desp. total 202,329\*\*\*; Educ. −40,640\*\*\*; Adm. 9,046\*\*\*; Comunicações n.s. | (não entra) | (no modelo A) Presidente: Desp. total 65,039\*\*\*, Educ. 56,711\*\*\* |
| R6 | + segundo mandato | Igual (277,917\*\*\*) | Igual (163,833\*) | Igual (governador 30,768\*\*\*; presidente −10,078). Segundo mandato: Desp. total 52,470\* (A) e 64,446\*\*\* (B) |
| R7 ⚠ | PIB municipal per capita, 2013-2023 | Desp. total 129,219\*; Saúde 2,522 (n.s.); Educ. 74,811\*\* | Desp. total 110,111 (n.s.) | Governador 24,960\*\*\*; presidente −17,346\*\* (Desp. total), Educ. −10,449\*\*\* |
| R7a | Especificação principal, só 2013-2023 | Desp. total 66,596 (n.s.); Saúde 33,845\*\*; Hab. 47,315\*\*; Transp. 19,555\* | Desp. total 92,778 (n.s.); Educ. 57,904\* | Governador 25,777\*\*\*; presidente −16,755\*\* (Desp. total), Educ. −10,278\*\*\* |
| R8 | Assistência + Previdência (só essa dependente) | 10,004 (n.s.) | 10,708 (n.s.) | Governador 5,023\*\*\*; presidente −2,323 (n.s.) |
| R9 | Transporte, Agricultura e Comunicações só com quem informa sempre | Transp. 48,686\*\*\*; Agric. 0,077; Com. −0,300\* | Com. 1,145\*\*\* | Presidente: Transp. −17,037\*\*\*, Agric. −5,234\*\*\*; governador n.s. |
| R10 ⚠ | Sem limpeza (outliers + receita original) | Igual (284,240\*\*\*) | Igual (165,024\*) | Governador: Saúde perde significância (3,784), Hab. passa a 4,797\*. Presidente: igual |
| R11 ⚠ | Winsorização p1-p99 no lugar da limpeza | Igual (292,138\*\*\*) | Igual (155,066\*), exceto Assistência 9,110\* | Governador: Hab. passa a 6,484\*\*\*. Presidente: Com. passa a 0,532\* |
| R12 | Modelo A com erro agrupado (só A) | Educ. 49,079\*\*\*; Adm. 6,817\*; Com. −0,801 (n.s.) | Todos \*\*\*, exceto Saúde (n.s.) | (não entra) |
| R13 | Modelo B com Driscoll-Kraay (só B) | (não entra) | (não entra) | Governador: Saúde perde significância (4,704); Adm. 7,167\*\*. Presidente: Saúde 8,453\*\*; resto igual |
| R14 | Modelo A sem pandemia (só A) | Desp. total 259,057\*\*; Saúde 79,403\*\*\*; Educ. −10,566 (n.s.); Com. −0,407 (n.s.) | Desp. total 165,778\*; Educ. 87,930\*\*; Hab. 32,847\* | (não entra) |
| R15 | Sem as variáveis do Censo | Igual (277,669\*\*\*) | Igual (161,903\*) | Governador: Saúde 4,393\*. Presidente: Transp. −15,707\*\*\*, Agric. −5,766\*\*\* |
| R16 | Ano eleitoral e pré-eleitoral separados por eleição (só A) | 2016: Desp. total 30,935 (n.s.). 2024: 467,553\*\*\* | 2015: 52,068 (n.s.); 2019: −9,598 (n.s.); 2023: 392,115\*\*\* | (não entra) |

**Testes que mudam mais de uma coisa (de propósito):**
- **R5:** especificação (sem pré-eleitoral e sem pandemia) + erro agrupado. É a especificação de Sakurai.
- **R7:** amostra 2013-2023 (forçada, porque o PIB municipal só vai até 2023) + troca do PIB. O **R7a** separa as duas coisas. Sem 2024, o efeito do ano eleitoral fica menor: despesa total 67 (n.s.), Saúde 34\*\*, Habitação 47\*\*, Transporte 20\*. Com a dummy de pandemia, o R7a identifica o ano eleitoral só pela eleição de 2016.
- **R10:** volta com os outliers + usa a receita tributária original.
- **R11:** troca a limpeza (excluir outliers) pela winsorização.

**Outros cuidados de leitura:**
- **R3:** perde alguns município-anos a mais, os de valor zero ou negativo (no log, viram vazio).
- **R9:** os municípios foram selecionados na base limpa.
- **R16:** rodado só com Driscoll-Kraay.

---

## 8. Resultados sólidos × frágeis

**Critério do trabalho:** um resultado é **sólido** quando é significativo (pelo menos a 10%) **com os dois erros-padrão**.
- Modelo A: Driscoll-Kraay (principal) e agrupado (R12).
- Modelo B: agrupado (principal) e Driscoll-Kraay (R13).

É **frágil** quando é significativo com só um deles.

### 8.1 Ano eleitoral (modelo A)

| Dependente | Driscoll-Kraay | Agrupado (R12) | Classificação |
|---|---|---|---|
| Despesa total | 277,865\*\*\* | \*\*\* | **Sólido** |
| Saúde e Saneamento | 53,163\*\*\* | \*\*\* | **Sólido** |
| Educação e Cultura | 49,079\* | \*\*\* | **Sólido** (só a 10% com Driscoll-Kraay) |
| Habitação e Urbanismo | 126,814\*\*\* | \*\*\* | **Sólido** |
| Assistência Social | 14,078\*\*\* | \*\*\* | **Sólido** |
| Transporte | 41,741\*\*\* | \*\*\* | **Sólido** |
| Administração | 6,817 | \* | Frágil |
| Agricultura | 0,486 | n.s. | Não significativo |
| Comunicações | −0,801\*\*\* | n.s. | Frágil |

### 8.2 Ano pré-eleitoral (modelo A)

| Dependente | Driscoll-Kraay | Agrupado (R12) | Classificação |
|---|---|---|---|
| Despesa total | 162,806\* | \*\*\* | **Sólido** (só a 10% com Driscoll-Kraay) |
| Saúde e Saneamento | 1,221 | n.s. | Não significativo |
| Educação e Cultura | 78,512\*\* | \*\*\* | **Sólido** |
| Habitação e Urbanismo | 34,083\*\* | \*\*\* | **Sólido** |
| Assistência Social | 9,468\*\* | \*\*\* | **Sólido** |
| Transporte | 8,342 | \*\*\* | Frágil |
| Administração | 10,347 | \*\*\* | Frágil |
| Agricultura | 5,168 | \*\*\* | Frágil |
| Comunicações | 0,656\*\*\* | \*\*\* | **Sólido** |

### 8.3 Coalizão do governador (modelo B)

| Dependente | Agrupado | Driscoll-Kraay (R13) | Classificação |
|---|---|---|---|
| Despesa total | 31,560\*\*\* | \*\*\* | **Sólido** |
| Saúde e Saneamento | 4,704\*\* | n.s. | Frágil |
| Administração | 7,167\*\*\* | \*\* | **Sólido** |
| Demais (Educ., Hab., Assist., Transp., Agric., Com.) | n.s. | n.s. | Não significativo |

### 8.4 Coalizão do presidente (modelo B)

| Dependente | Agrupado | Driscoll-Kraay (R13) | Classificação |
|---|---|---|---|
| Saúde e Saneamento | 8,453\*\*\* | \*\* | **Sólido** |
| Transporte | −12,466\*\*\* | \*\*\* | **Sólido** (negativo) |
| Agricultura | −4,580\*\*\* | \*\*\* | **Sólido** (negativo) |
| Demais (Desp. total, Educ., Hab., Assist., Adm., Com.) | n.s. | n.s. | Não significativo |

### 8.5 O efeito por eleição (R16: 2016 × 2024)

O R16 troca o ano eleitoral por uma dummy para 2016 e outra para 2024. A de 2020 continua absorvida pela pandemia. O pré-eleitoral também é separado por ano. Erro de Driscoll-Kraay.

| Dependente | Eleição 2016 | Eleição 2024 | Pré 2015 | Pré 2019 | Pré 2023 |
|---|---|---|---|---|---|
| Despesa total | 30,935 | 467,553\*\*\* | 52,068 | −9,598 | 392,115\*\*\* |
| Saúde e Saneamento | 24,353\*\*\* | 74,464\*\*\* | −6,984 | −26,741\*\*\* | 29,470\*\*\* |
| Educação e Cultura | −18,578 | 99,544\*\*\* | 41,546\* | 19,599 | 157,564\*\*\* |
| Habitação e Urbanismo | 57,436\*\*\* | 180,025\*\*\* | 15,345\*\*\* | −11,842 | 83,331\*\*\* |
| Assistência Social | 2,994 | 22,594\*\*\* | 3,640 | 2,172 | 20,259\*\*\* |
| Transporte | 17,628\*\*\* | 60,162\*\*\* | 4,317 | −10,992\* | 25,594\*\*\* |
| Administração | −17,401\*\* | 26,208\*\*\* | −5,873 | 2,091 | 31,265\*\*\* |
| Agricultura | −2,341 | 2,210 | 3,429\* | −0,504 | 11,195\* |
| Comunicações | −0,389\*\* | −1,210\*\*\* | 0,427\*\*\* | 0,835\*\*\* | 0,840\*\*\* |

**O que a tabela mostra (descrição, sem interpretação):**
- O coeficiente médio do ano eleitoral no modelo A (277,865\*\*\* na Despesa total) junta duas eleições muito diferentes. Em 2016, a despesa total não é significativa (30,935). Em 2024, é 467,553\*\*\*.
- Saúde, Habitação e Transporte são significativos e positivos nas duas eleições.
- O mesmo acontece no pré-eleitoral: 2023 é significativo em quase tudo; 2015 e 2019, em poucas variáveis.
- Junto com o R7a (sem 2024, o efeito médio cai), isso indica que **2023-2024 pesam muito no resultado médio**. Cabe à autora discutir por quê.
- O R16 foi rodado só com Driscoll-Kraay. O critério de solidez (os dois erros) não foi aplicado a ele.

---

## 9. Limitações

1. **Poucas eleições para identificar o ciclo.** Com a dummy de pandemia, o ano eleitoral do modelo A vem só de 2016 e 2024 (no R7 e no R7a, só de 2016). O R16 mostra que as duas eleições dão resultados muito diferentes.
2. **Driscoll-Kraay com T = 13.** Esse erro-padrão é pensado para muitos períodos. Por isso o critério de solidez exige também o erro agrupado.
3. **Variáveis do Censo** só variam pela interpolação 2010-2022 e ficam constantes em 2023-2025. Os coeficientes não são interpretados (R15 sem elas). 45 município-anos não têm esses dados.
4. **Ausência não é zero**, mas a cobertura é desigual. Comunicações tem em média 958 municípios por ano, e Transporte, 4.220. As amostras diferem entre dependentes.
5. **Comunicações (função 24) é sobretudo infraestrutura** (telecomunicações, postais). O gasto com publicidade fica em Comunicação Social (3.04.131), dentro de Administração, e não foi usado.
6. **Lei eleitoral (Lei 9.504/1997, art. 73):** proíbe publicidade institucional nos 3 meses antes da eleição. Com dado anual, uma alta no 1º semestre e o bloqueio no 2º podem se compensar. Conferir a redação vigente antes de citar.
7. **Vinculações constitucionais:** mínimos de 15% (Saúde) e 25% (Educação) das receitas de impostos limitam a margem do prefeito.
8. **Transferências correntes** (conta 1.1.7.0) incluem mais do que União + Estados (convênios, outras instituições), diferente de Sakurai. E a receita é bruta, sem descontar deduções (ex.: FUNDEB).
9. **Ideologia do partido do prefeito** ficou fora do modelo (decisão da autora). Sakurai usa.
10. **Coalizões em casos especiais:**
    - nos anos de governador de suplementar (AM 2017-18, TO 2018), usa-se a coligação da ordinária;
    - se o prefeito eleito foi afastado muito antes da suplementar, o período do interino é atribuído a ele;
    - 214 município-anos ficam sem prefeito, dos quais 49 em 2025 (eleição de 2024 sem eleito na base).
11. **Dados preliminares e cobertura:**
    - PIB nacional de 2024 e 2025 é preliminar;
    - o PIB municipal só vai até 2023;
    - o Siconfi de 2025 tem menos municípios (cerca de 5.440 contra cerca de 5.550);
    - as receitas têm queda de cobertura em 2014 (cerca de 5.180 municípios);
    - Boa Esperança do Norte (MT), instalado em 2025, não tem população em 2025.
12. **Diferenças em relação a Sakurai (2009) a declarar:** deflator IPCA (ele usou IGP-DI); Assistência sem Previdência; Administração incluída; classificação funcional atual (Portaria 42/1999) em todo o período.

---

## 10. Perguntas prováveis da banca

**1. Por que efeitos fixos e não aleatórios?**
O teste de Hausman, clássico e robusto (Mundlak), rejeita efeitos aleatórios nas 9 dependentes (p < 0,05). Na despesa total, o robusto dá 267,50 (p = 3,34e-53). O robusto foi incluído porque o clássico supõe erros sem heterocedasticidade e sem correlação no tempo.

**2. Por que dois modelos em vez de um?**
Porque as duas perguntas pedem especificações diferentes. O ano eleitoral é igual para todos os municípios no ano, então não cabe num modelo com efeito fixo de ano (seria colinear): vai no modelo A, com tendências e PIB nacional. As coalizões precisam do efeito de ano para não confundir alinhamento com período: vão no modelo B.

**3. Que evidência há de que a coalizão presidencial confundia alinhamento com período?**
Sem efeito de ano, a coalizão presidencial sai positiva e forte: 65,039\*\*\* na despesa total no R5 e 67,005\*\*\* no modelo A. Com efeito de ano (modelo B), cai para −9,744 (n.s.). Em Educação, vai de 56,711\*\*\* (R5) para −1,253 (n.s.).

**4. Por que Driscoll-Kraay, se há só 13 anos?**
Porque o ano eleitoral é um choque comum a todos os municípios. O erro precisa ser robusto à correlação entre municípios no mesmo ano, e o agrupado por município não é. Como o Driscoll-Kraay depende de muitos períodos, o critério de resultado sólido exige significância também com o erro agrupado (R12).

**5. Por que uma dummy de pandemia? Ela não "rouba" o efeito de 2020?**
Sim: com ela, o ano eleitoral é identificado por 2016 e 2024, e 2020 fica com a pandemia. Sem ela (R14), a despesa total fica em 259,057\*\* (contra 277,865\*\*\*), mas Educação passa de 49,079\* para −10,566 (n.s.), porque 2020 tem um efeito próprio forte em Educação (pandemia: −242,843\*\*\*).

**6. O efeito do ano eleitoral é o mesmo nas eleições?**
Não. No R16, a despesa total não é significativa em 2016 (30,935) e é 467,553\*\*\* em 2024. O R7a, sem 2024, dá 66,596 (n.s.). O resultado médio depende muito de 2024 (e de 2023 no pré-eleitoral). Isso deve ser discutido, e não escondido.

**7. Por que per capita em nível e não em log?**
Para comparar com Sakurai (2009), que usa per capita em nível. O log está no R3. Na despesa total, o ano eleitoral dá 0,054\*\*\*, ou seja, a mesma direção. Em Comunicações e na coalizão presidencial em Transporte, o sinal muda em log. Esses resultados devem ser tratados com cuidado.

**8. Por que não preencher com zero quando o município não informa a função?**
Porque ausência não é zero. A classificação por função é feita pela prefeitura, e o gasto pode estar em outra conta. Zero criaria quedas e subidas artificiais. O R9 usa só quem informa sempre: Transporte fica em 48,686\*\*\* no ano eleitoral.

**9. A exclusão dos outliers não fabricou o resultado, já que 12 deles são de 2016?**
O R10 refaz tudo sem limpeza e o ano eleitoral na despesa total fica em 284,240\*\*\* (principal: 277,865\*\*\*). O R11, com winsorização no lugar da exclusão, dá 292,138\*\*\*. O padrão de significância do ano eleitoral e do pré-eleitoral é o mesmo nos dois.

**10. Como foram tratadas as fusões de partidos?**
As renomeações (ex.: PMDB→MDB) são aplicadas sempre. As fusões, só quando o ano da fusão cai entre as duas eleições comparadas, para não criar alianças que não existiam (aplicar sempre geraria de cerca de 275 a 477 falsos 1 por ano em 2019-22). Sem fusões (R1), a coalizão do governador na despesa total fica em 28,511\*\*\*.

**11. Por que IPCA e não IGP-DI, como Sakurai?**
O IPCA é o índice oficial de inflação ao consumidor. Usou-se a média anual porque despesas e receitas são fluxos do ano civil (Lei 4.320, arts. 34-35). É uma diferença declarada em relação a Sakurai. Não há teste com IGP-DI.

**12. Por que PIB nacional e não PIB municipal como controle?**
O PIB municipal só existe até 2023 e tiraria 2024-2025, inclusive uma das duas eleições que identificam o ciclo. O R7 testa o PIB municipal e o R7a mostra que a diferença vem sobretudo da amostra: 129,219\* no R7 contra 66,596 (n.s.) no R7a, na despesa total.

**13. As variáveis do Censo fazem sentido com efeito fixo de município?**
Pouco: dentro do município, elas só variam pela interpolação entre 2010 e 2022 e ficam constantes em 2023-2025. Por isso ficam como controles (como em Sakurai), mas seus coeficientes não são interpretados. Sem elas (R15), o ano eleitoral fica em 277,669\*\*\* e a coalizão do governador em 31,000\*\*\*.

**14. Por que Assistência sem Previdência?**
A Previdência (regime próprio) é gasto obrigatório, com pouca margem para o prefeito, e Drazen e Eslava (2010) mostram que pensões são cortadas. O agrupamento de Sakurai está no R8: Assistência + Previdência não tem ano eleitoral significativo (10,004).

**15. Comunicações deu sinal negativo, ao contrário de Sakurai. Por quê?**
Primeiro, a função 24 é sobretudo infraestrutura (telecomunicações, postais), não publicidade, que fica em 3.04.131. Segundo, poucos municípios a informam (média de 958 por ano). Terceiro, o resultado é frágil: −0,801\*\*\* com Driscoll-Kraay, mas n.s. com erro agrupado (R12), e positivo em log (R3: 0,071\*\*\*). A Lei 9.504/1997 também limita a publicidade no ano eleitoral.
