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

roda_teste <- function(codigo, titulo, modelos, vars) {
  message("Robustez ", codigo, ": ", titulo)
  tab <- tabela_regressao(modelos, vars = vars)
  salva_tabela(tab, paste0("robustez_", codigo),
               titulo = paste0("Robustez ", codigo, " — ", titulo), nota = NOTA_EP)
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

message("Testes de robustez concluídos.")
