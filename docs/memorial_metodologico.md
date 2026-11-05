# Memorial metodológico

Ciclos Políticos Orçamentários e finanças municipais no Brasil (2013-2025)

Documento de estudo para a defesa na banca. Explica cada decisão do trabalho, por que foi tomada, o que se testou no lugar e onde ela está no código.

**De onde vêm os números.** Todos os números deste memorial vêm do `CLAUDE.md` ou das tabelas em `regressao/saidas/tabelas/`, na versão de 02/11/2026: especificação em log, % jovens = 0-19 anos, modelos A e B, testes R1 a R16 e R7a. As tabelas anteriores, em nível, estão em `backups/tabelas_nivel_2026-11-02/`.

**Unidades.**
- Coeficientes das despesas: dependente em ln(1 + despesa per capita, R$ de 2025). O coeficiente b de uma dummy se lê como variação percentual aproximada; a exata é 100 × (exp(b) − 1). Valores em R$ só quando indicado (teste R3).
- Estrelas: \*\*\* p<0,01; \*\* p<0,05; \* p<0,1; "n.s." = não significativo a 10%.

**Formato de cada decisão** (sempre o mesmo):

- **O que foi feito**
- **Por quê**
- **Alternativa considerada**
- **Efeito no resultado** (com o teste de robustez que mostra isso, quando há um)
- **Onde está no código**

Os links de código apontam para o arquivo e a linha na versão atual.

> Este memorial descreve o que foi feito e o que as tabelas mostram. A interpretação econômica dos resultados é do autor.

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
- **Quebra da série (conferida município a município com o SIDRA):**
  - 2013-2021: estimativas antigas do IBGE (tabela 6579);
  - 2022: contagem do Censo 2022, igual nos 5.570 municípios;
  - 2023: arquivo do IBGE para o TCU, derivado do Censo, igual a 2022 em 5.430 municípios (pelo nome do arquivo, na malha municipal de 2023);
  - 2024-2025: nova série de estimativas (tabela 6579, que não tem 2022 nem 2023).
  - O total cai de 213,3 para 203,1 milhões em 2022 e volta a 212,6 milhões em 2024, o que torna, em geral, os per capita de 2022 e 2023 artificialmente maiores. A série oficial ficou nos modelos; o teste **R17** interpola 2022 e 2023 entre 2021 e 2024 e não muda os resultados principais.
  - Divergências pequenas entre cache e SIDRA, não corrigidas (mesma soma no ano): 3 municípios em 2020, 2 em 2024 e 4 em 2025 (ver CLAUDE.md).
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
- **Onde está no código:** [01_base_regressao.R:49](../regressao/01_base_regressao.R#L49).

### 2.2 Despesas intraorçamentárias

- **O que foi feito:** foram retiradas as linhas de despesa intraorçamentária (pagamentos entre órgãos do próprio município). Remove 20.504 linhas.
- **Por quê:** são operações entre órgãos, fundos e entidades do próprio município, e contariam o mesmo recurso duas vezes (Portaria Interministerial STN/SOF nº 338/2006: art. 1º, definição; primeiro considerando, dupla contagem; art. 3º, efeitos a partir de 2007). As linhas não têm código e o nome muda entre 2013 e 2014, então o filtro é pelo nome: contém "intra" e não contém "exceto".
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
- **Efeito no resultado:** o teste **R2** retira os município-anos com prefeito ou governador de suplementar. O modelo A passa de 70.669 para 69.424 observações (Despesa total) e o padrão de significância do ano eleitoral se mantém (Despesa total 0,0519\*\*\*).
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
- **Efeito no resultado:** 220 município-anos passaram de 0 para 1, nenhum de 1 para 0. A variável só entra na robustez (**R6**): os coeficientes de ano eleitoral e de coalizões quase não mudam (Despesa total 0,0520\*\*\* no modelo A).
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
  - O teste **R1** (sem fusões, só renomeações) mantém a coalizão do governador na Despesa total (0,0034\*\*\* contra 0,0037\*\*\*). Em Administração, ela passa de 0,0070\*\*\* para 0,0061\*\*.
- **Onde está no código:** [main_code.py:319](../codigo/main_code.py#L319) (`RENOMEACOES`), [main_code.py:338](../codigo/main_code.py#L338) (`FUSOES`) e [main_code.py:350](../codigo/main_code.py#L350) (`padroniza_sigla`).

### 2.7 Coligações de 2010

- **O que foi feito:** na Base dos Dados, a tabela `partidos` tem a coligação vazia em 2010 e não tem o presidente de 2010. A composição veio do arquivo oficial do TSE (`consulta_coligacao_2010`). O partido eleito veio de `resultados_candidato`; para presidente, é o mais votado no 2º turno (PT).
- **Por quê:** sem isso, as dummies de coalizão de 2013-14 ficavam zeradas.
- **Alternativa considerada:** reconstruir a coligação pela própria Base dos Dados (partidos com o mesmo `sequencial_coligacao`). Foi usada como validação: dá o mesmo resultado nos 27 governadores (27/27).
- **Efeito no resultado:** 2013 e 2014 passam a ter coalizões válidas.
- **Onde está no código:** [main_code.py:229](../codigo/main_code.py#L229).

### 2.8 Deflação pelo IPCA médio anual

- **O que foi feito:** valor real = valor nominal × (média do IPCA de 2025 ÷ média do IPCA do ano). Tudo fica em **R$ de 2025**. Foram deflacionadas a despesa, as receitas e o PIB.
- **Por quê:** o valor anual soma pagamentos feitos a preços de meses diferentes. Por isso o deflator é a média dos 12 meses: o índice de dezembro trataria pagamentos do início do ano como se fossem a preços de fim de ano. Por decisão do autor, o TCC não cita norma nesse ponto (a Lei 4.320 não trata de deflação).
- **Alternativa considerada:** IGP-DI, usado por Sakurai (2009), em R$ de 2006. Fica como diferença declarada em relação a ele.
- **Efeito no resultado:** nenhum teste específico. É diferença de método a declarar.
- **Onde está no código:** [explora_receitas.py:268](../codigo/explora_receitas.py#L268).

### 2.9 PIB nacional como controle principal

- **O que foi feito:** `ln_pib_nacional_real` = logaritmo do PIB nacional real, o mesmo valor para todos os municípios no ano, sem vazios de 2013 a 2025. `pib_nacional_tri` (R$ trilhões) ficou para o R3 e as descritivas.
- **Por quê:** é o controle de Sakurai (2009) e existe em todos os anos. O PIB municipal só vai até 2023.
- **Alternativa considerada:** PIB municipal per capita (em log), que tiraria 2024-2025.
- **Efeito no resultado:**
  - **R7** (PIB municipal, 2013-2023): ano eleitoral na Despesa total = 0,0267\*\*\*.
  - **R7a** (especificação principal, mesma amostra 2013-2023): 0,0306 (n.s.).
  - No principal: 0,0519\*\*\*.
  - Sem 2024, o coeficiente fica menor nos dois testes; a significância difere entre eles.
- **Onde está no código:** [01_base_regressao.R:169](../regressao/01_base_regressao.R#L169).

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

- **O que foi feito:** agrupamentos como os de Sakurai (2009), com três ajustes: Assistência sem Previdência, Administração incluída e Comunicações só com a função 24. Todas as variáveis estão em R$ de 2025 per capita e entram nos modelos em ln(1 + x).
- **Por quê:**
  - Previdência (função 9, regime próprio) é gasto obrigatório, com pouca margem para o prefeito.
  - Administração é gasto pouco visível, citado por Teixeira e Mattos (2021).
  - Sakurai encontrou efeito positivo do ano eleitoral em Comunicações (0,280\*\*\*).
- **Alternativa considerada:**
  - Assistência + Previdência, como Sakurai: teste **R8**.
  - Variável em nível: teste **R3**.
  - Participação na despesa total: teste **R4**.
- **Efeito no resultado:**
  - **R8:** ano eleitoral 0,0377\*\*\* e pré-eleitoral 0,0260 (n.s.), contra 0,0678\*\*\* e 0,0355\* só com Assistência. Em nível, o ano eleitoral do R8 era 10,004 (n.s.; ver o backup).
  - R3 e R4: ver a seção 7.
- **Onde está no código:** [00_configuracao.R:48](../regressao/00_configuracao.R#L48) (`GRUPOS`) e [01_base_regressao.R:62](../regressao/01_base_regressao.R#L62) (`soma_grupo`).

### 3.2 Soma das funções e despesa total

- **O que foi feito:** cada grupo é a soma das funções que o município informou naquele ano. A despesa total é a soma das 28 funções informadas, e não só das escolhidas.
- **Por quê:** é a mesma definição em todos os anos e coerente com os grupos (ver 2.1).
- **Alternativa considerada:** a linha de total oficial `3.00.000` (ver 2.1).
- **Efeito no resultado:** sem teste específico.
- **Onde está no código:** [01_base_regressao.R:69-76](../regressao/01_base_regressao.R#L69-L76).

### 3.3 Ausência ≠ zero

- **O que foi feito:** se o município não informou nenhuma função do grupo no ano, o grupo fica **vazio (NA)**, não zero, e esse município-ano sai daquela regressão.
- **Por quê:** quem classifica o gasto por função é a prefeitura, e um gasto pode estar lançado em outra conta (ex.: publicidade dentro de Administração Geral). Pôr zero criaria quedas e subidas artificiais.
- **Alternativa considerada:** preencher com zero; ou usar só os municípios que informam sempre.
- **Efeito no resultado:**
  - A cobertura é desigual. Média de municípios por ano: Comunicações 958, Transporte 4.220, Agricultura 4.999, Administração 5.474.
  - O teste **R9** usa só os municípios que informam a função em todos os anos em que aparecem (3.000 em Transporte, 4.264 em Agricultura, 330 em Comunicações).
  - Resultados do R9: ano eleitoral em Transporte = 0,1525\*\*\* (principal 0,1778\*\*\*); Comunicações = 0,0195 (n.s.; principal 0,0318\*\*\*).
- **Onde está no código:** [01_base_regressao.R:62-76](../regressao/01_base_regressao.R#L62-L76); cobertura em [01b_cobertura.R](../regressao/01b_cobertura.R); R9 em [05_robustez.R:158](../regressao/05_robustez.R#L158).

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
  - Sem a dummy (**R14**), Educação e Cultura passa de 0,0343\*\* para −0,0078 (n.s.).
- **Onde está no código:** [01_base_regressao.R:103-105](../regressao/01_base_regressao.R#L103-L105) e [00_configuracao.R:106-107](../regressao/00_configuracao.R#L106-L107).

### 4.2 Controles

- **O que foi feito:**
  - receita tributária per capita, em ln(1 + x);
  - transferências correntes per capita, em ln(1 + x);
  - % jovens, % idosos e grau de urbanização;
  - população (log);
  - PIB nacional real (log);
  - tendência (ano − 2012) e tendência ao quadrado.
  - No modelo B, só os seis primeiros desta lista (os que variam entre municípios).
- **Por quê:** são os controles de Sakurai (2009), que também usou tendência linear e quadrática.
- **Alternativa considerada:** PIB municipal (**R7**); sem as variáveis do Censo (**R15**).
- **Efeito no resultado:** ver 4.4 e a seção 7.
- **Onde está no código:** [00_configuracao.R:109-113](../regressao/00_configuracao.R#L109-L113); transformações em [01_base_regressao.R:107-112](../regressao/01_base_regressao.R#L107-L112) e [01_base_regressao.R:167-169](../regressao/01_base_regressao.R#L167-L169).

### 4.3 % jovens = 0-19 anos

- **O que foi feito:** `perc_jovens` = população de 0 a 19 anos ÷ população total, como proporção de 0 a 1.
- **Por quê:** decisão do autor (05/10/2026): é a faixa usual de demanda por educação. As duas tabelas do Censo têm as faixas 0-4, 5-9, 10-14 e 15-19 separadas de 20-24, então 0-19 é exato nos dois censos.
- **Alternativa considerada:** 0-24 anos, que o código usava antes por engano (incluía "20 a 24 anos").
- **Efeito no resultado:**
  - A média de `perc_jovens` caiu de 0,410 para 0,328 em 2013 e de 0,347 para 0,275 em 2022-2025. A correlação entre as duas versões é 0,992.
  - Nas regressões, os coeficientes de interesse quase não mudaram. Na especificação em nível da época, a única mudança de significância foi o ano eleitoral em Educação e Cultura (de 49,116, n.s., para 49,079\*).
- **Onde está no código:** [main_code.py:479](../codigo/main_code.py#L479).

### 4.4 O problema das variáveis do Censo com efeito fixo

- **O que foi feito:** grau de urbanização, % jovens e % idosos só existem em 2010 e 2022. Os anos de 2011 a 2021 são **interpolados linearmente**, e 2023-2025 repetem 2022.
  - Dentro de cada município, a única variação dessas variáveis é essa interpolação, uma reta que fica constante depois de 2022.
  - Elas ficam nos controles (como em Sakurai), mas **seus coeficientes não são interpretados**.
  - Há 45 município-anos sem esses dados (6 municípios criados depois de 2010).
- **Por quê:** manter a especificação comparável à de Sakurai. Com efeito fixo de município, essa "variação" é artificial, e por isso os coeficientes não são lidos.
- **Alternativa considerada:** tirar as três variáveis: teste **R15**.
- **Efeito no resultado (R15):**
  - Modelo A, ano eleitoral na Despesa total: 0,0516\*\*\* contra 0,0519\*\*\*.
  - Modelo B, coalizão do governador: 0,0038\*\*\* contra 0,0037\*\*\*.
  - A coalizão presidencial em Transporte passa de 0,0418\*\*\* para 0,0427\*\*\*.
  - A única mudança de significância nos coeficientes de interesse é o pré-eleitoral em Habitação e Urbanismo (de \*\* para \*).
- **Onde está no código:** [main_code.py:554](../codigo/main_code.py#L554) (interpolação) e [05_robustez.R:215](../regressao/05_robustez.R#L215) (R15).

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
- **Por quê:** em TO 2024, a mediana cai de 493 (2023) para 353 e volta a 501 (2025), com 31 municípios negativos, o que sugere possíveis erros de lançamento concentrados no estado e no ano. Receita tributária negativa não faz sentido econômico. Como a receita é controle em todas as regressões, esses município-anos saem dos modelos principais; os municípios do Tocantins continuam nos outros anos.
- **Alternativa considerada:** usar a receita original: teste **R10**, com ln(1 + receita original). Os 35 negativos não têm logaritmo e ficam ausentes também no R10.
- **Efeito no resultado:** ver 5.2 (o R10 desfaz as duas limpezas juntas).
- **Onde está no código:** [01_base_regressao.R:130-135](../regressao/01_base_regressao.R#L130-L135).

### 5.2 Outliers de despesa: 0,2× e 5× a mediana do município

- **O que foi feito:** `outlier_despesa` = 1 quando a despesa total per capita do ano é **menor que 0,2×** ou **maior que 5×** a mediana do próprio município. São 66 município-anos:
  - 62 abaixo, 4 acima;
  - **12 deles em 2016, ano eleitoral.**
- **Por quê:** são quedas ou saltos isolados de um ano em séries normais (ex.: MA 2013, município 3170701 em MG em 2022-2023), que parecem erro de registro.
- **Alternativa considerada:**
  - Não limpar: teste **R10**.
  - Winsorizar (limitar aos percentis 1 e 99 de cada ano): teste **R11**.
- **Efeito no resultado:**
  - **R10:** ano eleitoral na Despesa total = 0,0499\*\*\* (principal 0,0519\*\*\*).
  - **R11:** 0,0529\*\*\*.
  - O padrão de significância do ano eleitoral e do pré-eleitoral se mantém nos dois.
  - No R10, nenhum coeficiente de interesse muda de sinal; no modelo B, a coalizão do governador passa de \*\* para \* em Educação e Cultura e de \*\*\* para \*\* em Administração.
  - Como 12 dos outliers caem em 2016, o **R10 é o teste principal dessa decisão**.
- **Onde está no código:** [01_base_regressao.R:142-147](../regressao/01_base_regressao.R#L142-L147) e [00_configuracao.R:263](../regressao/00_configuracao.R#L263) (`carrega_base`).

---

## 6. Modelos, Hausman e erros-padrão

### 6.1 Por que a especificação mudou (os R12 e R13 antigos)

- **O que foi feito:** antes havia um modelo só, a especificação de Sakurai: efeito fixo de município, ano eleitoral + coalizões + controles, erro agrupado por município. Dois testes daquela versão mostraram dois problemas:
  - **R12 antigo** (erro de Driscoll-Kraay): o ano eleitoral é igual para todos os municípios no mesmo ano, então precisa de um erro-padrão robusto a choques comuns a todos no ano.
  - **R13 antigo** (efeitos fixos de município e de ano): sem efeito de ano, a coalizão presidencial confunde **alinhamento com o presidente** com **o período** (quem era presidente na época).
- **Por quê:** cada pergunta passou a ter o modelo adequado. O ano eleitoral não pode ficar num modelo com efeito de ano (seria colinear: todos votam no mesmo ano). As coalizões precisam do efeito de ano.
- **Alternativa considerada:** manter o modelo único. Ele continua no trabalho como teste **R5**, que reproduz a especificação anterior com os dados atuais.
- **Efeito no resultado:** os números do R12 e do R13 antigos não foram guardados. O efeito aparece comparando o R5 com o modelo B:
  - Coalizão presidencial, Despesa total: **0,0084\*\*\*** no R5 e **−0,0010 (n.s.)** no modelo B.
  - Coalizão presidencial, Educação: **0,0309\*\*\*** no R5 e **−0,0025 (n.s.)** no modelo B.
  - No próprio modelo A, sem efeito de ano, ela também sai positiva (Despesa total 0,0092\*).
- **Onde está no código:** [04_regressoes.R](../regressao/04_regressoes.R); R5 em [05_robustez.R:126](../regressao/05_robustez.R#L126).

### 6.2 Modelo A ("ciclo eleitoral")

- **O que foi feito:** efeito fixo de município. Variáveis: ano eleitoral, pré-eleitoral, pandemia, coalizões e todos os controles (inclusive PIB nacional e tendências). Erro-padrão de **Driscoll-Kraay**.
- **Por quê:** o ano eleitoral só varia no tempo. Ele precisa de tendências e do PIB nacional para separar o ciclo eleitoral da trajetória geral, e de um erro robusto a choques comuns no ano e a autocorrelação.
- **Alternativa considerada:** erro agrupado por município (teste **R12** atual).
- **Efeito no resultado:** ver a seção 8. **Leitura: ano eleitoral e pré-eleitoral vêm do modelo A.**
- **Onde está no código:** [04_regressoes.R:34](../regressao/04_regressoes.R#L34); erro-padrão em [00_configuracao.R:151](../regressao/00_configuracao.R#L151).

### 6.3 Modelo B ("coalizões")

- **O que foi feito:** efeitos fixos de município **e de ano**. Variáveis: coalizão do governador, coalizão do presidente e os controles que variam entre municípios. Erro-padrão **agrupado por município**.
- **Por quê:** o efeito de ano absorve tudo o que é comum aos municípios no ano (ciclo eleitoral, PIB nacional, presidente da época). A coalizão passa a ser comparada **dentro do mesmo ano**.
- **Alternativa considerada:** erro de Driscoll-Kraay (teste **R13** atual).
- **Efeito no resultado:** ver a seção 8. **Leitura: as coalizões vêm do modelo B.**
- **Onde está no código:** [04_regressoes.R:50](../regressao/04_regressoes.R#L50); erro-padrão em [00_configuracao.R:147](../regressao/00_configuracao.R#L147).

### 6.4 Efeitos fixos × aleatórios (Hausman)

- **O que foi feito:** para cada dependente, com a especificação do modelo A, compararam-se efeitos fixos e aleatórios por dois testes:
  - **Hausman clássico**;
  - **Hausman robusto** (versão de Mundlak/Wooldridge: inclui as médias de cada município e testa se são conjuntamente zero, com erro agrupado).
- **Por quê:** o clássico supõe erros sem heterocedasticidade e sem correlação no tempo, o que é pouco realista aqui. O robusto não depende disso.
- **Alternativa considerada:** efeitos aleatórios. Foram estimados pelo método Wallace-Hussain, porque o método padrão (Swamy-Arora) fica singular com variáveis que só variam no tempo.
- **Efeito no resultado:** os dois testes rejeitam efeitos aleatórios nas 9 dependentes (p < 0,05). **Decisão: efeitos fixos.**

| Dependente | Hausman (χ²) | p-valor | Robusto | p-valor (robusto) |
|---|---|---|---|---|
| Despesa total | 29.697,93 | 0 | 374,28 | 5,90e-76 |
| Saúde e Saneamento | 4.697,14 | 0 | 484,11 | 1,80e-99 |
| Educação e Cultura | 3.198,99 | 0 | 686,00 | 7,38e-143 |
| Habitação e Urbanismo | 296,93 | 5,17e-55 | 109,32 | 5,25e-20 |
| Assistência Social | 1.463,20 | 4,00e-304 | 355,68 | 5,55e-72 |
| Transporte | 670,22 | 5,82e-134 | 410,03 | 1,34e-83 |
| Administração | 2.618,88 | 0 | 671,99 | 7,66e-140 |
| Agricultura | 130,36 | 5,76e-21 | 229,48 | 3,81e-45 |
| Comunicações | 542,95 | 7,16e-107 | 178,34 | 2,30e-34 |

  "p-valor 0" significa abaixo da precisão numérica do R.

  Na despesa total, o ano eleitoral é positivo nos três estimadores: pooled 0,0381\*\*\*, efeitos fixos 0,0519\*\*\* e efeitos aleatórios 0,0449\*\*\*. Os controles municipais mudam bastante; por exemplo, população (log) vai de −0,0147\* no pooled a −0,5413\*\*\* nos efeitos fixos.
- **Onde está no código:** [03_hausman.R:23-25](../regressao/03_hausman.R#L23-L25), [00_configuracao.R:222](../regressao/00_configuracao.R#L222) (`hausman_mundlak`) e [04_regressoes.R:67](../regressao/04_regressoes.R#L67) (comparação).

### 6.5 Os dois erros-padrão

- **O que foi feito:**
  - **Driscoll-Kraay:** robusto a correlação entre municípios no mesmo ano e a autocorrelação.
  - **Agrupado por município** (Arellano, HC1): robusto a heterocedasticidade e a correlação dentro de cada município ao longo do tempo.
- **Por quê:** cada modelo usa o erro mais adequado à variável de interesse, e o outro serve de teste (R12 e R13). O Driscoll-Kraay depende de muitos períodos, e aqui há só 13 anos. Por isso o critério de resultado sólido exige os dois (ver a seção 8).
- **Alternativa considerada:** usar um erro só para tudo.
- **Efeito no resultado:** ver a seção 8.
- **Onde está no código:** [00_configuracao.R:147-151](../regressao/00_configuracao.R#L147-L151).

### 6.6 Especificação em log (decisão do orientador)

- **O que foi feito:** a dependente e as receitas entram em ln(1 + valor per capita); o PIB nacional, em ln. O zero vira ln(1) = 0 e fica na regressão; negativo vira NA.
- **Por quê:**
  - os municípios têm tamanhos muito diferentes (despesa total de R$ 643 a R$ 63.396 per capita, Tabela 4);
  - o interesse é a recomposição entre áreas de tamanhos diferentes, e a variação percentual torna os grupos comparáveis;
  - a distribuição é assimétrica (despesa total: média de R$ 5.446 e mediana de R$ 4.705).
  - ln(1 + x) em vez de ln(x): mantém os zeros. Para valores acima de R$ 10, a diferença entre os dois é menor que 0,1 (no máximo 0,0953).
- **Alternativa considerada:** nível, a antiga especificação principal, agora no teste **R3** e comparação direta com Sakurai (2009).
- **Efeito no resultado:** na amostra, saem só os negativos que estavam nos modelos (Assistência 1, Transporte 1); os 5 de Administração são de TO 2024 e já estavam fora. Os 4 zeros continuam. Na Tabela 4 do TCC, os 7 negativos também ficam ausentes e os zeros ficam, para a tabela seguir a mesma regra dos modelos; a base e as colunas `<var>_pc` não mudam. Ver as seções 7 e 8.
- **Cuidado de leitura:** valores positivos até R$ 10: Comunicações 74,42% (24,95% abaixo de R$ 1), Transporte 13,28%, Agricultura 12,78%. Em Comunicações, o coeficiente não se lê como variação percentual, e o resultado não é interpretado; o mesmo vale, em parte, para Transporte e Agricultura.
- **Onde está no código:** [00_configuracao.R:131](../regressao/00_configuracao.R#L131) (`ln1p`), [01_base_regressao.R:167](../regressao/01_base_regressao.R#L167) (colunas `ln1p_*`).

### 6.7 Resultados principais

**Modelo A** (Driscoll-Kraay):

| | Desp. total | Saúde e San. | Educ. e Cult. | Hab. e Urb. | Assistência | Transporte | Administração | Agricultura | Comunicações |
|---|---|---|---|---|---|---|---|---|---|
| Ano eleitoral | 0,0519\*\*\* | 0,0411\*\*\* | 0,0343\*\* | 0,2389\*\*\* | 0,0678\*\*\* | 0,1778\*\*\* | 0,0097 | 0,0529\*\*\* | 0,0318\*\*\* |
| Ano pré-eleitoral | 0,0209 | −0,0083 | 0,0461\*\* | 0,0509\*\* | 0,0355\* | 0,0188 | 0,0077 | 0,0564\*\* | 0,0605\*\*\* |
| Pandemia (2020) | −0,0058 | 0,0908\*\*\* | −0,1610\*\*\* | 0,1254\*\*\* | 0,0169\* | 0,0711\*\*\* | 0,0297\*\*\* | 0,0312\*\* | 0,0444\*\*\* |

Elasticidades na despesa total: receita tributária 0,0837\*\*\* (A) e 0,0776\*\*\* (B); transferências correntes 0,3203\*\*\* (A) e 0,3164\*\*\* (B); PIB nacional 0,6812 (n.s., A).

**Modelo B** (agrupado por município):

| | Desp. total | Saúde e San. | Educ. e Cult. | Hab. e Urb. | Assistência | Transporte | Administração | Agricultura | Comunicações |
|---|---|---|---|---|---|---|---|---|---|
| Coalizão governador | 0,0037\*\*\* | 0,0009 | 0,0033\*\* | 0,0160\*\* | 0,0009 | 0,0114 | 0,0070\*\*\* | 0,0110 | −0,0022 |
| Coalizão presidente | −0,0010 | 0,0001 | −0,0025 | −0,0163\* | −0,0058 | 0,0418\*\*\* | 0,0043 | 0,0045 | 0,0075 |

Observações (modelos A e B): de 70.669 (Despesa total) a 12.360 (Comunicações).

---

## 7. Testes de robustez

Cada teste muda **uma coisa** em relação ao modelo principal, em log. As exceções estão marcadas com ⚠ e são explicadas depois da tabela. "Igual ao principal" quer dizer o mesmo padrão de significância nas 9 dependentes.

| Teste | O que muda | Ano eleitoral (A) | Pré-eleitoral (A) | Coalizões (B) |
|---|---|---|---|---|
| R1 | Coalizões sem fusões (só renomeações) | Igual ao principal (Desp. total 0,0519\*\*\*) | Igual (0,0209) | Governador: Desp. total 0,0034\*\*\*; Adm. 0,0061\*\*. Presidente: igual |
| R2 | Sem prefeito/governador de suplementar | Igual (0,0519\*\*\*) | Igual (0,0211) | Governador: Educ. 0,0029\*, Adm. 0,0067\*\*. Presidente: igual |
| R3 | Especificação em nível (R$; dependente, receitas e PIB) | Desp. total 277,865\*\*\*; Educ. 49,079\*; Agricultura 0,486 (n.s.); Comunicações muda de sinal (−0,801\*\*\*) | Desp. total 162,806\*; Agricultura 5,168 (n.s.) | Governador: Desp. total 31,560\*\*\*, Saúde 4,704\*\*, Adm. 7,167\*\*\*, Hab. e Educ. n.s. Presidente: Transporte muda de sinal (−12,466\*\*\*); Saúde 8,453\*\*\*; Agricultura −4,580\*\*\* |
| R4 | Participação na despesa total (%), controles em log | Educ. −0,545\*\*\*, Hab. 1,463\*\*\*, Transp. 0,437\*\*\*, Adm. −0,448\*\*\*, Assist. 0,064\*\*\*, Saúde n.s. | Saúde −0,750\*\*\*, Educ. 0,736\*\*\*, Hab. 0,196\*, Adm. −0,205\*\* | Governador: Saúde −0,098\*\*\*, Educ. −0,115\*\*\*. Presidente: nenhum significativo |
| R5 ⚠ | Especificação de Sakurai, em log: sem pré-eleitoral e sem pandemia, erro agrupado (só A) | Desp. total 0,0432\*\*\*; Educ. −0,0257\*\*\*; Adm. 0,0152\*\*\*; Comunicações n.s. | (não entra) | (no modelo A) Presidente: Desp. total 0,0084\*\*\*, Educ. 0,0309\*\*\* |
| R6 | + segundo mandato | Igual (0,0520\*\*\*) | Igual (0,0211) | Governador 0,0035\*\*\*, Educ. 0,0033\*; presidente −0,0011 (n.s.). Segundo mandato: Desp. total 0,0126\*\*\* (A) e 0,0141\*\*\* (B) |
| R7 ⚠ | Log do PIB municipal per capita, 2013-2023 | Desp. total 0,0267\*\*\*; Saúde 0,0027 (n.s.); Educ. 0,0466\*\*; Assist. e Agric. n.s.; Adm. −0,0136\*\* | Desp. total 0,0083 (n.s.); Saúde −0,0214\*\*\* | Governador 0,0030\*\*\*; presidente −0,0035\*\* (Desp. total), Educ. −0,0070\*\*\* |
| R7a | Especificação principal, só 2013-2023 | Desp. total 0,0306 (n.s.); Saúde 0,0446\*\*\*; Hab. 0,1924\*\*\*; Transp. 0,1591\*\*\*; Educ., Assist. e Agric. n.s. | Desp. total 0,0087 (n.s.); Saúde −0,0112\*\* | Governador 0,0033\*\*\*; presidente −0,0034\*\* (Desp. total), Educ. −0,0069\*\*\* |
| R8 | ln(1 + Assistência + Previdência) (só essa dependente) | 0,0377\*\*\* | 0,0260 (n.s.) | Governador 0,0103\*\*\*; presidente −0,0144\*\*\* |
| R9 | Transporte, Agricultura e Comunicações só com quem informa sempre | Transp. 0,1525\*\*\*; Agric. 0,0484\*\*\*; Com. 0,0195 (n.s.) | Agric. 0,0564\*\*; Com. 0,0894\*\*\* | Governador: Transp. 0,0238\*\*, Agric. 0,0122\*. Presidente: Transp. 0,0295\*\* |
| R10 ⚠ | Sem limpeza (outliers + ln(1 + receita original)) | Igual (0,0499\*\*\*) | Igual (0,0215) | Governador: Educ. 0,0031\*, Adm. 0,0069\*\*. Presidente: igual |
| R11 ⚠ | Winsorização p1-p99 em reais, antes do log | Igual (0,0529\*\*\*) | Igual (0,0211) | Governador: Hab. 0,0158\*\*\*. Presidente: Hab. −0,0162\*\* |
| R12 | Modelo A com erro agrupado (só A) | Todos significativos: Adm. 0,0097\*\*\*; Educ. 0,0343\*\*\*; Com. 0,0318\*\* | Todos \*\*\* | (não entra) |
| R13 | Modelo B com Driscoll-Kraay (só B) | (não entra) | (não entra) | Governador: Educ. n.s.; Hab. 0,0160\*\*\*; Agric. 0,0110\*. Presidente: Hab. −0,0163\*\*\*; Assist. −0,0058\* |
| R14 | Modelo A sem pandemia (só A) | Desp. total 0,0504\*\*\*; Saúde 0,0649\*\*\*; Educ. −0,0078 (n.s.); Adm. 0,0174\*\* | Desp. total 0,0211 (n.s.); Educ. 0,0523\*\*; Hab. 0,0461\* | (não entra) |
| R15 | Sem as variáveis do Censo | Igual (0,0516\*\*\*) | Igual, exceto Hab. 0,0473\* | Governador 0,0038\*\*\*. Presidente: Transp. 0,0427\*\*\* |
| R16 | Ano eleitoral e pré-eleitoral separados por eleição (só A) | 2016: Desp. total 0,0329\*\*. 2024: 0,0650\*\*\* | 2015: 0,0083 (n.s.); 2019: −0,0025 (n.s.); 2023: 0,0511\*\* | (não entra) |
| R17 | População de 2022 e 2023 interpolada entre as estimativas de 2021 e 2024 | Igual (0,0522\*\*\*) | Igual (0,0208) | Governador 0,0036\*\*\*, Educ. 0,0032\*, Adm. 0,0069\*\*\*. Presidente: igual |

**Testes que mudam mais de uma coisa (de propósito):**
- **R5:** especificação (sem pré-eleitoral e sem pandemia) + erro agrupado. É a especificação de Sakurai, em log.
- **R7:** amostra 2013-2023 (forçada, porque o PIB municipal só vai até 2023) + troca do PIB. O **R7a** separa as duas coisas. Com a dummy de pandemia, o R7a identifica o ano eleitoral só pela eleição de 2016.
- **R10:** volta com os outliers + usa ln(1 + receita tributária original). Os 35 negativos dessa receita (31 de TO 2024, 1 de TO 2021 e 3 de GO 2024) ficam ausentes, de 7 a 35 por variável.
- **R11:** troca a limpeza (excluir outliers) pela winsorização em reais, antes do log. Nenhum negativo ou zero sobra depois da winsorização.

**Outros cuidados de leitura:**
- **R3:** é a antiga especificação principal, e mantém os negativos. Os coeficientes estão em R$.
- **R9:** os municípios foram selecionados na base limpa.
- **R16:** rodado só com Driscoll-Kraay.
- **R17:** usa as colunas `*_interp` do `01_base_regressao.R` (dependentes, receitas e `ln_populacao`); a interpolação é geométrica, município a município, e os demais anos ficam iguais.
- Os números em nível de R7, R7a e R16 estão no backup, não nas tabelas atuais. Coalizão presidencial, Despesa total, em nível: −17,346\*\* (R7) e −16,755\*\* (R7a).

---

## 8. Resultados sólidos × frágeis

**Critério do trabalho:** um resultado é **sólido** quando atende a três condições:
- é significativo (pelo menos a 10%) **com os dois erros-padrão** (modelo A: Driscoll-Kraay e agrupado, R12; modelo B: agrupado e Driscoll-Kraay, R13);
- **não depende de uma só eleição** (R16, só no modelo A);
- **vale nas duas formas funcionais**, log e nível (R3).

### 8.1 Ano eleitoral (modelo A)

| Dependente | Driscoll-Kraay | Agrupado (R12) | 2016 | 2024 | Nível (R3) | Classificação |
|---|---|---|---|---|---|---|
| Despesa total | 0,0519\*\*\* | \*\*\* | \*\* | \*\*\* | \*\*\* | **Sólido**, com a ressalva de que o R7a dá n.s. |
| Saúde e Saneamento | 0,0411\*\*\* | \*\*\* | \*\*\* | \*\*\* | \*\*\* | **Sólido** (n.s. no R7) |
| Educação e Cultura | 0,0343\*\* | \*\*\* | n.s. | \*\* | \* | Depende de 2024 e do tratamento de 2020 |
| Habitação e Urbanismo | 0,2389\*\*\* | \*\*\* | \*\*\* | \*\*\* | \*\*\* | **Sólido** |
| Assistência Social | 0,0678\*\*\* | \*\*\* | n.s. | \*\*\* | \*\*\* | Depende de 2024 |
| Transporte | 0,1778\*\*\* | \*\*\* | \*\*\* | \*\*\* | \*\*\* | **Sólido** (cerca de 13% dos valores até R$ 10) |
| Administração | 0,0097 | \*\*\* | n.s. | \*\* | n.s. | Frágil |
| Agricultura | 0,0529\*\*\* | \*\*\* | \*\* | n.s. | n.s. | Depende da forma funcional |
| Comunicações | 0,0318\*\*\* | \*\* | \*\*\* | n.s. | −0,801\*\*\* | Não interpretada |

### 8.2 Ano pré-eleitoral (modelo A)

| Dependente | Driscoll-Kraay | Agrupado (R12) | 2015 | 2019 | 2023 | Nível (R3) | Classificação |
|---|---|---|---|---|---|---|---|
| Despesa total | 0,0209 | \*\*\* | n.s. | n.s. | \*\* | \* | Frágil |
| Saúde e Saneamento | −0,0083 | \*\*\* | \*\*\* | \*\*\* | n.s. | n.s. | Frágil |
| Educação e Cultura | 0,0461\*\* | \*\*\* | \*\* | n.s. | \*\* | \*\* | Significativo nas formas e erros; varia por ano |
| Habitação e Urbanismo | 0,0509\*\* | \*\*\* | \*\*\* | n.s. | \*\* | \*\* | Significativo nas formas e erros; varia por ano |
| Assistência Social | 0,0355\* | \*\*\* | \* | n.s. | \*\* | \*\* | Significativo nas formas e erros; varia por ano |
| Transporte | 0,0188 | \*\*\* | n.s. | n.s. | n.s. | n.s. | Frágil |
| Administração | 0,0077 | \*\*\* | \*\* | n.s. | \* | n.s. | Frágil |
| Agricultura | 0,0564\*\* | \*\*\* | \*\*\* | n.s. | n.s. | n.s. | Depende da forma funcional |
| Comunicações | 0,0605\*\*\* | \*\*\* | \*\*\* | \*\*\* | \*\*\* | \*\*\* | Não interpretada |

### 8.3 Coalizão do governador (modelo B)

| Dependente | Agrupado | Driscoll-Kraay (R13) | Nível (R3) | Classificação |
|---|---|---|---|---|
| Despesa total | 0,0037\*\*\* | \*\*\* | 31,560\*\*\* | **Sólido** |
| Administração | 0,0070\*\*\* | \*\*\* | 7,167\*\*\* | **Sólido** |
| Habitação e Urbanismo | 0,0160\*\* | \*\*\* | 4,267 (n.s.) | Depende da forma funcional |
| Educação e Cultura | 0,0033\*\* | n.s. | −1,165 (n.s.) | Frágil |
| Saúde e Saneamento | 0,0009 | n.s. | 4,704\*\* | Depende da forma funcional |
| Agricultura | 0,0110 | \* | −0,560 (n.s.) | Frágil |
| Assist., Transp., Com. | n.s. | n.s. | n.s. | Não significativo |

### 8.4 Coalizão do presidente (modelo B)

| Dependente | Agrupado | Driscoll-Kraay (R13) | Nível (R3) | Classificação |
|---|---|---|---|---|
| Despesa total | −0,0010 | n.s. | −9,744 (n.s.) | Não significativo na amostra completa; negativo em 2013-2023 (R7 e R7a) |
| Transporte | 0,0418\*\*\* | \*\*\* | −12,466\*\*\* | Sinal oposto entre as formas; não interpretado |
| Habitação e Urbanismo | −0,0163\* | \*\*\* | 0,219 (n.s.) | Depende da forma funcional |
| Saúde e Saneamento | 0,0001 | n.s. | 8,453\*\*\* | Depende da forma funcional |
| Agricultura | 0,0045 | n.s. | −4,580\*\*\* | Depende da forma funcional |
| Assistência Social | −0,0058 | \* | 1,003 (n.s.) | Frágil |
| Educ., Adm., Com. | n.s. | n.s. | n.s. | Não significativo |

### 8.5 O efeito por eleição (R16: 2016 × 2024)

O R16 troca o ano eleitoral por uma dummy para 2016 e outra para 2024. A de 2020 continua absorvida pela pandemia. O pré-eleitoral também é separado por ano. Erro de Driscoll-Kraay.

| Dependente | Eleição 2016 | Eleição 2024 | Pré 2015 | Pré 2019 | Pré 2023 |
|---|---|---|---|---|---|
| Despesa total | 0,0329\*\* | 0,0650\*\*\* | 0,0083 | −0,0025 | 0,0511\*\* |
| Saúde e Saneamento | 0,0414\*\*\* | 0,0396\*\*\* | −0,0106\*\*\* | −0,0196\*\*\* | 0,0033 |
| Educação e Cultura | 0,0030 | 0,0564\*\* | 0,0243\*\* | 0,0137 | 0,0920\*\* |
| Habitação e Urbanismo | 0,2153\*\*\* | 0,2526\*\*\* | 0,0422\*\*\* | −0,0030 | 0,1012\*\* |
| Assistência Social | 0,0402 | 0,0873\*\*\* | 0,0221\* | 0,0063 | 0,0705\*\* |
| Transporte | 0,1920\*\*\* | 0,1625\*\*\* | −0,0070 | −0,0093 | 0,0695 |
| Administração | −0,0059 | 0,0217\*\* | −0,0066\*\* | 0,0024 | 0,0251\* |
| Agricultura | 0,0632\*\* | 0,0418 | 0,0657\*\*\* | 0,0265 | 0,0720 |
| Comunicações | 0,0393\*\*\* | 0,0250 | 0,0627\*\*\* | 0,0627\*\*\* | 0,0566\*\*\* |

**O que a tabela mostra (descrição, sem interpretação):**
- A despesa total é significativa nas duas eleições, com efeito maior em 2024 (cerca de 6,7%, contra 3,3% em 2016).
- Saúde, Habitação e Transporte são significativos e positivos nas duas eleições.
- No pré-eleitoral, a despesa total só é significativa em 2023.
- O R7a (sem 2024) dá 0,0306 (n.s.) na despesa total, e o R7 (mesma amostra, PIB municipal), 0,0267\*\*\*. O R16 foi rodado só com Driscoll-Kraay.

### 8.6 Síntese (a mesma do TCC, seção 5.4)

1. Habitação e Urbanismo, Transporte e Saúde e Saneamento sobem no ano eleitoral nas duas eleições, nas duas formas e com os dois erros.
2. O alinhamento com o governador aumenta a despesa total, com efeito pequeno (cerca de 0,4%).
3. O alinhamento com o presidente não tem efeito sobre a despesa total na amostra completa; na amostra até 2023 o efeito é negativo, de modo que o resultado é sensível ao período.
4. A despesa total sobe cerca de 5% no ano eleitoral, mais em 2024; em 2016 o efeito é menor e não resiste ao corte da amostra na especificação principal (R7a).
5. Resultados que dependem da forma funcional: Agricultura no ano eleitoral, Transporte e Habitação nas coalizões; Comunicações não é interpretada.

---

## 9. Limitações

1. **Poucas eleições para identificar o ciclo.** Com a dummy de pandemia, o ano eleitoral do modelo A vem só de 2016 e 2024 (no R7 e no R7a, só de 2016). O R16 mostra diferenças entre as duas eleições.
2. **Driscoll-Kraay com T = 13.** Esse erro-padrão é pensado para muitos períodos. Por isso o critério de solidez exige também o erro agrupado.
3. **Variáveis do Censo** só variam pela interpolação 2010-2022 e ficam constantes em 2023-2025. Os coeficientes não são interpretados (R15 sem elas). 45 município-anos não têm esses dados.
4. **Ausência não é zero**, mas a cobertura é desigual. Comunicações tem em média 958 municípios por ano, e Transporte, 4.220. As amostras diferem entre dependentes.
5. **Valores pequenos e ln(1 + x).** Em Comunicações, 74% dos valores são de até R$ 10, e ali o coeficiente não se lê como variação percentual; em Transporte e Agricultura, cerca de 13%.
6. **Comunicações (função 24) é sobretudo infraestrutura** (telecomunicações, postais). O gasto com publicidade fica em Comunicação Social (3.04.131), dentro de Administração, e não foi usado.
7. **Lei eleitoral (Lei 9.504/1997, art. 73):** não é citada no TCC, porque Comunicações não é interpretada. Conferir a redação vigente se a pergunta aparecer.
8. **Vinculações constitucionais:** mínimos de 15% (Saúde) e 25% (Educação) das receitas de impostos limitam a margem do prefeito.
9. **Transferências correntes** (conta 1.1.7.0) incluem mais do que União + Estados (convênios, outras instituições), diferente de Sakurai. E a receita é bruta, sem descontar deduções (ex.: FUNDEB).
10. **Ideologia do partido do prefeito** ficou fora do modelo (decisão do autor). Sakurai usa.
11. **Coalizões em casos especiais:**
    - nos anos de governador de suplementar (AM 2017-18, TO 2018), usa-se a coligação da ordinária;
    - se o prefeito eleito foi afastado muito antes da suplementar, o período do interino é atribuído a ele;
    - 214 município-anos ficam sem prefeito, dos quais 49 em 2025 (eleição de 2024 sem eleito na base).
12. **Dados preliminares e cobertura:**
    - PIB nacional de 2024 e 2025 é preliminar;
    - o PIB municipal só vai até 2023;
    - o Siconfi de 2025 tem menos municípios (cerca de 5.440 contra cerca de 5.550);
    - as receitas têm queda de cobertura em 2014 (cerca de 5.180 municípios);
    - Boa Esperança do Norte (MT), instalado em 2025, está no cache de 2025 sem código de município, então fica sem população em 2025.
14. **Quebra da série de população em 2022:** 2022 e 2023 vêm do Censo, e os demais anos, de estimativas. Os per capita desses dois anos ficam, em geral, maiores. O R17 interpola os dois anos e não muda os resultados principais (ver 1.4).
13. **Diferenças em relação a Sakurai (2009) a declarar:** deflator IPCA (ele usou IGP-DI); forma funcional em log (o nível está no R3); Assistência sem Previdência; Administração incluída; classificação funcional atual (Portaria 42/1999) em todo o período.

---

## 10. Perguntas prováveis da banca

**1. Por que efeitos fixos e não aleatórios?**
O teste de Hausman, clássico e robusto (Mundlak), rejeita efeitos aleatórios nas 9 dependentes (p < 0,05). Na despesa total, o robusto dá 374,28 (p = 5,90e-76). O robusto foi incluído porque o clássico supõe erros sem heterocedasticidade e sem correlação no tempo.

**2. Por que dois modelos em vez de um?**
Porque as duas perguntas pedem especificações diferentes. O ano eleitoral é igual para todos os municípios no ano, então não cabe num modelo com efeito fixo de ano (seria colinear): vai no modelo A, com tendências e PIB nacional. As coalizões precisam do efeito de ano para não confundir alinhamento com período: vão no modelo B.

**3. Que evidência há de que a coalizão presidencial confundia alinhamento com período?**
Sem efeito de ano, a coalizão presidencial sai positiva: 0,0084\*\*\* na despesa total no R5 e 0,0092\* no modelo A. Com efeito de ano (modelo B), fica em −0,0010 (n.s.). Em Educação, vai de 0,0309\*\*\* (R5) para −0,0025 (n.s.).

**4. Por que Driscoll-Kraay, se há só 13 anos?**
Porque o ano eleitoral é um choque comum a todos os municípios. O erro precisa ser robusto à correlação entre municípios no mesmo ano, e o agrupado por município não é. Como o Driscoll-Kraay depende de muitos períodos, o critério de resultado sólido exige significância também com o erro agrupado (R12).

**5. Por que uma dummy de pandemia? Ela não "rouba" o efeito de 2020?**
Sim: com ela, o ano eleitoral é identificado por 2016 e 2024, e 2020 fica com a pandemia. Sem ela (R14), a despesa total fica em 0,0504\*\*\* (contra 0,0519\*\*\*), mas Educação passa de 0,0343\*\* para −0,0078 (n.s.), porque 2020 tem um efeito próprio forte em Educação (pandemia: −0,1610\*\*\*, cerca de −14,9%).

**6. O efeito do ano eleitoral é o mesmo nas eleições?**
Não. No R16, a despesa total é 0,0329\*\* em 2016 e 0,0650\*\*\* em 2024. O R7a, sem 2024, dá 0,0306 (n.s.), e o R7, com PIB municipal, 0,0267\*\*\*. Isso deve ser discutido, e não escondido.

**7. Por que log, e não nível como Sakurai?**
Por sugestão do orientador, e por três motivos: municípios de tamanhos muito diferentes, comparação entre áreas de tamanhos diferentes e distribuição assimétrica (seção 6.6). O nível está no R3. Na despesa total, os dois apontam a mesma direção (0,0519\*\*\* e 277,865\*\*\*). Em Comunicações e na coalizão presidencial em Transporte, o sinal muda entre as formas. Esses resultados não são interpretados.

**8. Por que ln(1 + x), e não ln(x)?**
Para manter os 4 zeros na regressão. Acima de R$ 10, a diferença é menor que 0,1. O custo é que, onde há muitos valores pequenos, como em Comunicações, o coeficiente não se lê como variação percentual.

**9. Por que não preencher com zero quando o município não informa a função?**
Porque ausência não é zero. A classificação por função é feita pela prefeitura, e o gasto pode estar em outra conta. Zero criaria quedas e subidas artificiais. O R9 usa só quem informa sempre: Transporte fica em 0,1525\*\*\* no ano eleitoral.

**10. A exclusão dos outliers não fabricou o resultado, já que 12 deles são de 2016?**
O R10 refaz tudo sem limpeza e o ano eleitoral na despesa total fica em 0,0499\*\*\* (principal: 0,0519\*\*\*). O R11, com winsorização no lugar da exclusão, dá 0,0529\*\*\*. O padrão de significância do ano eleitoral e do pré-eleitoral é o mesmo nos dois.

**11. Como foram tratadas as fusões de partidos?**
As renomeações (ex.: PMDB→MDB) são aplicadas sempre. As fusões, só quando o ano da fusão cai entre as duas eleições comparadas, para não criar alianças que não existiam (aplicar sempre geraria de cerca de 275 a 477 falsos 1 por ano em 2019-22). Sem fusões (R1), a coalizão do governador na despesa total fica em 0,0034\*\*\*.

**12. Por que IPCA e não IGP-DI, como Sakurai?**
O IPCA é o índice oficial de inflação ao consumidor. Usou-se a média anual porque o valor anual soma pagamentos feitos a preços de meses diferentes. É uma diferença declarada em relação a Sakurai. Não há teste com IGP-DI.

**13. Por que PIB nacional e não PIB municipal como controle?**
O PIB municipal só existe até 2023 e tiraria 2024-2025, inclusive uma das duas eleições que identificam o ciclo. O R7 testa o PIB municipal: 0,0267\*\*\* na despesa total, contra 0,0306 (n.s.) no R7a, na mesma amostra.

**14. As variáveis do Censo fazem sentido com efeito fixo de município?**
Pouco: dentro do município, elas só variam pela interpolação entre 2010 e 2022 e ficam constantes em 2023-2025. Por isso ficam como controles (como em Sakurai), mas seus coeficientes não são interpretados. Sem elas (R15), o ano eleitoral fica em 0,0516\*\*\* e a coalizão do governador em 0,0038\*\*\*.

**15. Por que Assistência sem Previdência?**
A Previdência (regime próprio) é gasto obrigatório, com pouca margem para o prefeito, e Drazen e Eslava (2010) mostram que pensões são cortadas. O agrupamento de Sakurai está no R8: em log, Assistência + Previdência tem ano eleitoral 0,0377\*\*\*; em nível, era 10,004 (n.s.).

**16. Por que Comunicações não é interpretada?**
Primeiro, 74% dos valores são de até R$ 10 e 25% são menores que R$ 1, e ali o coeficiente não se lê como variação percentual. Segundo, o sinal muda entre as formas (0,0318\*\*\* em log e −0,801\*\*\* em nível). Terceiro, poucos municípios a informam (média de 958 por ano). Além disso, a função 24 é sobretudo infraestrutura (telecomunicações, postais), não publicidade, que fica em 3.04.131.
