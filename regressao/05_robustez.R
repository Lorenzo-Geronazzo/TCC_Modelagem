# ==============================================================================
# 05_robustez.R — testes de robustez
# ==============================================================================
# Cada teste reestima as 9 regressões mudando UMA coisa em relação ao modelo
# principal, e a tabela mostra só os coeficientes de interesse.
#   R1  Coalizões sem fusões/incorporações de partidos
#   R2  Sem município-anos com prefeito ou governador de eleição suplementar
#   R3  Variável dependente em log
#   R4  Variável dependente como participação na despesa total (%)
#   R5  Inclui o ano pré-eleitoral
#   R6  Inclui prefeito em segundo mandato
#   R7  PIB municipal per capita no lugar do PIB nacional (amostra 2013-2023)
#   R8  Assistência + Previdência (agrupamento do Sakurai)
#   R9  Transporte, Agricultura e Comunicações só com municípios que informam
#       a função em todos os anos em que aparecem na base
#   R10 Sem limpeza: mantém os município-anos com outlier_despesa = 1 e usa a
#       receita tributária original (inclusive TO 2024 e valores negativos)
#   R11 Winsorização: base sem limpeza de despesa (receita já corrigida), com
#       cada dependente per capita limitada aos percentis 1 e 99 de cada ano
#   R12 Erro-padrão de Driscoll-Kraay (mesmos modelos do principal)
#   R13 Efeitos fixos de município e de ano (sem ano eleitoral, PIB nacional
#       e tendências, colineares com o efeito de ano); só as coalizões
#   R14 Inclui dummy de pandemia (pandemia_2020 = 1 em 2020)
MODELO <- "within"   # manter igual ao 04_regressoes.R

source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()

estima_todas <- function(dados, x, sufixo_y = "_pc", prefixo_y = "", dependentes = DEPENDENTES) {
  pdados <- pdata.frame(dados, index = c("id_municipio", "ano"))
  modelos <- list()
  for (v in dependentes) {
    y <- paste0(prefixo_y, v, sufixo_y)
    if (!y %in% names(dados)) next
    modelos[[rotulo(v)]] <- plm(monta_formula(y, x), data = pdados, model = MODELO, random.method = METODO_RE)
  }
  modelos
}

# vcov_fun e nota têm padrão (erro-padrão agrupado por município); o R12 troca os dois
roda_teste <- function(codigo, titulo, modelos, vars, vcov_fun = vcov_cluster, nota = NOTA_EP) {
  message("Robustez ", codigo, ": ", titulo)
  tab <- tabela_regressao(modelos, vars = vars, vcov_fun = vcov_fun)
  salva_tabela(tab, paste0("robustez_", codigo),
               titulo = paste0("Robustez ", codigo, " — ", titulo), nota = nota)
  invisible(tab)
}

X <- c(INTERESSE, CONTROLES)

# R1 — coalizões sem fusões
x_r1 <- c("ano_eleitoral", "coalizao_gov_sem_fusao", "coalizao_pres_sem_fusao", CONTROLES)
roda_teste("R1", "coalizões sem fusões de partidos",
           estima_todas(base, x_r1), c("ano_eleitoral", "coalizao_gov_sem_fusao", "coalizao_pres_sem_fusao"))

# R2 — sem suplementares
base_r2 <- base |> filter(coalesce(prefeito_suplementar, 0) == 0, coalesce(governador_suplementar, 0) == 0)
roda_teste("R2", "sem prefeitos/governadores de eleição suplementar",
           estima_todas(base_r2, X), INTERESSE)

# R3 — dependente em log
roda_teste("R3", "variável dependente em log",
           estima_todas(base, X, prefixo_y = "ln_"), INTERESSE)

# R4 — participação na despesa total (%), sem a própria despesa total
roda_teste("R4", "participação na despesa total (%)",
           estima_todas(base, X, sufixo_y = "_part", dependentes = setdiff(DEPENDENTES, "despesa_total")),
           INTERESSE)

# R5 — inclui ano pré-eleitoral
roda_teste("R5", "inclui ano pré-eleitoral",
           estima_todas(base, c("pre_eleitoral", X)), c("pre_eleitoral", INTERESSE))

# R6 — inclui segundo mandato
roda_teste("R6", "inclui prefeito em segundo mandato",
           estima_todas(base, c(X, "segundo_mandato")), c(INTERESSE, "segundo_mandato"))

# R7 — PIB municipal per capita, 2013-2023 (o IBGE ainda não publicou 2024-2025)
x_r7 <- c(setdiff(X, "pib_nacional_tri"), "ln_pib_mun_pc")
roda_teste("R7", "PIB municipal per capita (2013-2023)",
           estima_todas(base |> filter(ano <= 2023), x_r7), c(INTERESSE, "ln_pib_mun_pc"))

# R8 — Assistência + Previdência, como Sakurai
roda_teste("R8", "Assistência e Previdência somadas (Sakurai, 2009)",
           estima_todas(base, X, dependentes = "assist_previdencia"), INTERESSE)

# R9 — só municípios que informam a função em todos os anos em que aparecem
# (a base tem uma linha por município-ano presente no Siconfi)
modelos_r9 <- list()
for (v in c("transporte", "agricultura", "comunicacoes")) {
  base_v <- base |>
    group_by(id_municipio) |>
    filter(all(!is.na(.data[[v]]) & .data[[v]] > 0)) |>
    ungroup()
  message("R9 ", v, ": ", n_distinct(base_v$id_municipio), " municípios")
  modelos_r9 <- c(modelos_r9, estima_todas(base_v, X, dependentes = v))
}
roda_teste("R9", "só municípios que informam a função em todos os anos",
           modelos_r9, INTERESSE)

# R10 — sem limpeza: base inteira (com os outliers de despesa) e receita
# tributária original (receita_tributaria_real_pc_bruta)
base_r10 <- carrega_base(limpa = FALSE) |>
  mutate(receita_tributaria_real_pc = receita_tributaria_real_pc_bruta)
roda_teste("R10", "sem limpeza (outliers de despesa e receita original)",
           estima_todas(base_r10, X), INTERESSE)

# R11 — winsorização: base inteira (receita já corrigida); em cada ano, cada
# dependente per capita é limitada aos percentis 1 e 99 daquele ano
# (valor abaixo do p1 vira p1; acima do p99 vira p99; NA continua NA)
limita_p1_p99 <- function(x) {
  p1  <- quantile(x, 0.01, na.rm = TRUE)
  p99 <- quantile(x, 0.99, na.rm = TRUE)
  pmin(pmax(x, p1), p99)
}
base_r11 <- carrega_base(limpa = FALSE) |>
  group_by(ano) |>
  mutate(across(all_of(paste0(DEPENDENTES, "_pc")), limita_p1_p99)) |>
  ungroup()
roda_teste("R11", "dependentes winsorizadas nos percentis 1 e 99 de cada ano",
           estima_todas(base_r11, X), INTERESSE)

# R12 — mesmos modelos do principal, com erro-padrão de Driscoll-Kraay
# (robusto a correlação entre municípios no mesmo ano e a autocorrelação)
vcov_dk <- function(m) plm::vcovSCC(m, type = "HC1")
roda_teste("R12", "erro-padrão de Driscoll-Kraay",
           estima_todas(base, X), INTERESSE, vcov_fun = vcov_dk,
           nota = paste("Erros-padrão de Driscoll-Kraay entre parênteses.",
                        "*** p<0,01; ** p<0,05; * p<0,1."))

# R13 — efeitos fixos de município e de ano (twoways). O efeito de ano absorve
# tudo o que só varia no tempo, então saem ano eleitoral, PIB nacional e
# tendências (colineares com ele). Mostra só as coalizões.
x_r13 <- c("coalizao_gov", "coalizao_pres", "receita_tributaria_real_pc",
           "transf_correntes_real_pc", "perc_jovens", "perc_idosos",
           "grau_urb", "ln_populacao")
pbase <- pdata.frame(base, index = c("id_municipio", "ano"))
modelos_r13 <- list()
for (v in DEPENDENTES) {
  modelos_r13[[rotulo(v)]] <- plm(monta_formula(paste0(v, "_pc"), x_r13), data = pbase,
                                  model = "within", effect = "twoways")
}
roda_teste("R13", "efeitos fixos de município e de ano",
           modelos_r13, c("coalizao_gov", "coalizao_pres"))

# R14 — modelo principal + dummy de pandemia (ano de 2020)
base_r14 <- base |> mutate(pandemia_2020 = as.integer(ano == 2020))
roda_teste("R14", "inclui dummy de pandemia (2020)",
           estima_todas(base_r14, c(X, "pandemia_2020")), c(INTERESSE, "pandemia_2020"))

message("Testes de robustez concluídos.")
