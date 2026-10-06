# ==============================================================================
# 05_robustez.R — testes de robustez
# ==============================================================================
# Cada teste reestima o modelo A e/ou o modelo B (ver 04_regressoes.R) mudando
# UMA coisa. A tabela mostra:
#   - ano eleitoral e pré-eleitoral, do modelo A (erro-padrão Driscoll-Kraay);
#   - coalizão do governador e do presidente, do modelo B (erro agrupado por município);
# com o modelo de origem indicado em cada linha ("[modelo A]" / "[modelo B]").
#   R1  Coalizões sem fusões/incorporações de partidos (A e B)
#   R2  Sem município-anos com prefeito ou governador de eleição suplementar (A e B)
#   R3  Variável dependente em log (A e B)
#   R4  Variável dependente como participação na despesa total, % (A e B)
#   R5  Especificação de Sakurai: modelo A sem pré-eleitoral e sem pandemia,
#       erro agrupado por município (só modelo A)
#   R6  Inclui prefeito em segundo mandato (A e B)
#   R7  PIB municipal per capita, amostra 2013-2023 (A: no lugar do PIB
#       nacional; B: somado aos controles) (A e B)
#   R7a Especificação principal só na amostra 2013-2023, sem trocar o PIB
#       (separa o efeito da amostra do efeito do PIB municipal no R7) (A e B)
#   R8  Assistência + Previdência (agrupamento do Sakurai) (A e B)
#   R9  Transporte, Agricultura e Comunicações só com municípios que informam
#       a função em todos os anos em que aparecem na base (A e B)
#   R10 Sem limpeza: mantém os município-anos com outlier_despesa = 1 e usa a
#       receita tributária original (A e B)
#   R11 Winsorização: base sem limpeza de despesa (receita já corrigida), com
#       cada dependente per capita limitada aos percentis 1 e 99 de cada ano (A e B)
#   R12 Modelo A com erro-padrão agrupado por município (só modelo A)
#   R13 Modelo B com erro-padrão de Driscoll-Kraay (só modelo B)
#   R14 Modelo A sem a dummy de pandemia (só modelo A)
#   R15 Sem as variáveis do Censo (perc_jovens, perc_idosos, grau_urb) (A e B)
#   R16 Ano eleitoral e pré-eleitoral separados por eleição: eleicao_2016,
#       eleicao_2024 (2020 fica com a pandemia), pre_2015, pre_2019 e pre_2023
#       (só modelo A, erro Driscoll-Kraay)
source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()

X_A <- c(INTERESSE_A, CONTROLES)
X_B <- c(INTERESSE_B, CONTROLES_B)
MOSTRA_A <- c("ano_eleitoral", "pre_eleitoral")   # linhas que saem do modelo A
MOSTRA_B <- INTERESSE_B                           # linhas que saem do modelo B

# ------------------------------------------------------------------------------
# Funções auxiliares
# ------------------------------------------------------------------------------
# Estima as regressões de efeitos fixos para cada dependente.
# efeito = "individual" (modelo A) ou "twoways" (modelo B)
estima <- function(dados, x, efeito, sufixo_y = "_pc", prefixo_y = "", dependentes = DEPENDENTES) {
  pdados <- pdata.frame(dados, index = c("id_municipio", "ano"))
  modelos <- list()
  for (v in dependentes) {
    y <- paste0(prefixo_y, v, sufixo_y)
    if (!y %in% names(dados)) {
      warning("Variável dependente não encontrada na base: ", y, " (pulada)")
      next
    }
    modelos[[rotulo(v)]] <- plm(monta_formula(y, x), data = pdados, model = "within", effect = efeito)
  }
  modelos
}
estima_A <- function(dados, x = X_A, ...) estima(dados, x, "individual", ...)
estima_B <- function(dados, x = X_B, ...) estima(dados, x, "twoways", ...)

# Acrescenta "[modelo A]" ou "[modelo B]" ao nome das linhas (inclusive
# Observações, Municípios e R²), para saber de qual modelo vem cada número
marca_modelo <- function(tab, letra) {
  v <- tab[["Variável"]]
  tab[["Variável"]] <- ifelse(v == "", "", paste0(v, " [modelo ", letra, "]"))
  tab
}

# Junta numa tabela só as linhas do modelo A e do modelo B (qualquer um pode faltar)
tabela_ab <- function(mods_A = NULL, vars_A = MOSTRA_A, vcov_A = vcov_dk,
                      mods_B = NULL, vars_B = MOSTRA_B, vcov_B = vcov_cluster) {
  partes <- list()
  if (!is.null(mods_A)) partes$A <- marca_modelo(tabela_regressao(mods_A, vars = vars_A, vcov_fun = vcov_A), "A")
  if (!is.null(mods_B)) partes$B <- marca_modelo(tabela_regressao(mods_B, vars = vars_B, vcov_fun = vcov_B), "B")
  tab <- bind_rows(partes)
  tab[is.na(tab)] <- ""
  tab
}

roda_teste <- function(codigo, titulo, tab, nota = NOTA_AB) {
  message("Robustez ", codigo, ": ", titulo)
  salva_tabela(tab, paste0("robustez_", codigo),
               titulo = paste0("Robustez ", codigo, " — ", titulo), nota = nota)
  invisible(tab)
}

# ------------------------------------------------------------------------------
# Testes
# ------------------------------------------------------------------------------
# R1 — coalizões sem fusões (nos dois modelos)
sem_fusao <- c("coalizao_gov_sem_fusao", "coalizao_pres_sem_fusao")
x_a1 <- c("ano_eleitoral", "pre_eleitoral", "pandemia_2020", sem_fusao, CONTROLES)
x_b1 <- c(sem_fusao, CONTROLES_B)
roda_teste("R1", "coalizões sem fusões de partidos",
           tabela_ab(estima_A(base, x_a1), mods_B = estima_B(base, x_b1), vars_B = sem_fusao))

# R2 — sem suplementares
base_r2 <- base |> filter(coalesce(prefeito_suplementar, 0) == 0, coalesce(governador_suplementar, 0) == 0)
roda_teste("R2", "sem prefeitos/governadores de eleição suplementar",
           tabela_ab(estima_A(base_r2), mods_B = estima_B(base_r2)))

# R3 — dependente em log
roda_teste("R3", "variável dependente em log",
           tabela_ab(estima_A(base, prefixo_y = "ln_"), mods_B = estima_B(base, prefixo_y = "ln_")))

# R4 — participação na despesa total (%), sem a própria despesa total
deps_part <- setdiff(DEPENDENTES, "despesa_total")
roda_teste("R4", "participação na despesa total (%)",
           tabela_ab(estima_A(base, sufixo_y = "_part", dependentes = deps_part),
                     mods_B = estima_B(base, sufixo_y = "_part", dependentes = deps_part)))

# R5 — especificação de Sakurai (2009): modelo A sem pré-eleitoral e sem
# pandemia, erro agrupado por município (só modelo A)
roda_teste("R5", "especificação de Sakurai (sem pré-eleitoral e sem pandemia, erro agrupado)",
           tabela_ab(estima_A(base, c(INTERESSE, CONTROLES)), vars_A = INTERESSE, vcov_A = vcov_cluster),
           nota = paste("Só modelo A: efeito fixo de município, sem ano pré-eleitoral e sem pandemia.",
                        NOTA_EP))

# R6 — inclui segundo mandato (nos dois modelos)
roda_teste("R6", "inclui prefeito em segundo mandato",
           tabela_ab(estima_A(base, c(X_A, "segundo_mandato")), vars_A = c(MOSTRA_A, "segundo_mandato"),
                     mods_B = estima_B(base, c(X_B, "segundo_mandato")), vars_B = c(MOSTRA_B, "segundo_mandato")))

# R7 — PIB municipal per capita, 2013-2023 (o IBGE ainda não publicou 2024-2025).
# Modelo A: no lugar do PIB nacional. Modelo B: somado aos controles (o PIB
# nacional já está absorvido pelo efeito de ano).
base_r7 <- base |> filter(ano <= 2023)
x_a7 <- c(setdiff(X_A, "pib_nacional_tri"), "ln_pib_mun_pc")
x_b7 <- c(X_B, "ln_pib_mun_pc")
roda_teste("R7", "PIB municipal per capita (2013-2023)",
           tabela_ab(estima_A(base_r7, x_a7), vars_A = c(MOSTRA_A, "ln_pib_mun_pc"),
                     mods_B = estima_B(base_r7, x_b7)))

# R7a — especificação principal (sem trocar o PIB) só na amostra 2013-2023.
# Comparar com o R7 separa o efeito da amostra do efeito do PIB municipal.
roda_teste("R7a", "especificação principal na amostra 2013-2023",
           tabela_ab(estima_A(base_r7), mods_B = estima_B(base_r7)))

# R8 — Assistência + Previdência, como Sakurai
roda_teste("R8", "Assistência e Previdência somadas (Sakurai, 2009)",
           tabela_ab(estima_A(base, dependentes = "assist_previdencia"),
                     mods_B = estima_B(base, dependentes = "assist_previdencia")))

# R9 — só municípios que informam a função em todos os anos em que aparecem
# (a base tem uma linha por município-ano presente no Siconfi)
modelos_r9_A <- list()
modelos_r9_B <- list()
for (v in c("transporte", "agricultura", "comunicacoes")) {
  base_v <- base |>
    group_by(id_municipio) |>
    filter(all(!is.na(.data[[v]]) & .data[[v]] > 0)) |>
    ungroup()
  message("R9 ", v, ": ", n_distinct(base_v$id_municipio), " municípios")
  modelos_r9_A <- c(modelos_r9_A, estima_A(base_v, dependentes = v))
  modelos_r9_B <- c(modelos_r9_B, estima_B(base_v, dependentes = v))
}
roda_teste("R9", "só municípios que informam a função em todos os anos",
           tabela_ab(modelos_r9_A, mods_B = modelos_r9_B))

# R10 — sem limpeza: base inteira (com os outliers de despesa) e receita
# tributária original (receita_tributaria_real_pc_bruta)
base_r10 <- carrega_base(limpa = FALSE) |>
  mutate(receita_tributaria_real_pc = receita_tributaria_real_pc_bruta)
roda_teste("R10", "sem limpeza (outliers de despesa e receita original)",
           tabela_ab(estima_A(base_r10), mods_B = estima_B(base_r10)))

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
           tabela_ab(estima_A(base_r11), mods_B = estima_B(base_r11)))

# R12 — modelo A com erro-padrão agrupado por município (só modelo A)
roda_teste("R12", "modelo A com erro-padrão agrupado por município",
           tabela_ab(estima_A(base), vcov_A = vcov_cluster),
           nota = paste("Só modelo A: efeito fixo de município.", NOTA_EP))

# R13 — modelo B com erro-padrão de Driscoll-Kraay (só modelo B)
roda_teste("R13", "modelo B com erro-padrão de Driscoll-Kraay",
           tabela_ab(mods_B = estima_B(base), vcov_B = vcov_dk),
           nota = paste("Só modelo B: efeitos fixos de município e de ano.",
                        "Erros-padrão de Driscoll-Kraay entre parênteses. *** p<0,01; ** p<0,05; * p<0,1."))

# R14 — modelo A sem a dummy de pandemia (só modelo A)
roda_teste("R14", "modelo A sem a dummy de pandemia",
           tabela_ab(estima_A(base, setdiff(X_A, "pandemia_2020"))),
           nota = paste("Só modelo A: efeito fixo de município, sem a dummy de pandemia.",
                        "Erros-padrão de Driscoll-Kraay entre parênteses. *** p<0,01; ** p<0,05; * p<0,1."))

# R15 — sem as variáveis do Censo (nos dois modelos). Elas só variam dentro do
# município pela interpolação 2010-2022 e ficam constantes em 2023-2025.
CENSO <- c("perc_jovens", "perc_idosos", "grau_urb")
roda_teste("R15", "sem as variáveis do Censo (jovens, idosos, urbanização)",
           tabela_ab(estima_A(base, setdiff(X_A, CENSO)), mods_B = estima_B(base, setdiff(X_B, CENSO))))

# R16 — ano eleitoral e pré-eleitoral separados por eleição (só modelo A).
# ano_eleitoral vira eleicao_2016 e eleicao_2024 (2020 continua absorvido por
# pandemia_2020); pre_eleitoral vira pre_2015, pre_2019 e pre_2023.
POR_ELEICAO <- c("eleicao_2016", "eleicao_2024", "pre_2015", "pre_2019", "pre_2023")
ROTULOS[POR_ELEICAO] <- c("Ano eleitoral de 2016", "Ano eleitoral de 2024",
                          "Ano pré-eleitoral de 2015", "Ano pré-eleitoral de 2019",
                          "Ano pré-eleitoral de 2023")
base_r16 <- base |>
  mutate(eleicao_2016 = as.integer(ano == 2016),
         eleicao_2024 = as.integer(ano == 2024),
         pre_2015     = as.integer(ano == 2015),
         pre_2019     = as.integer(ano == 2019),
         pre_2023     = as.integer(ano == 2023))
x_a16 <- c(POR_ELEICAO, setdiff(X_A, c("ano_eleitoral", "pre_eleitoral")))
roda_teste("R16", "ano eleitoral e pré-eleitoral separados por eleição (modelo A)",
           tabela_ab(estima_A(base_r16, x_a16), vars_A = POR_ELEICAO),
           nota = paste("Só modelo A: efeito fixo de município; ano eleitoral e pré-eleitoral",
                        "separados por eleição (2020 absorvido pela dummy de pandemia).",
                        "Erros-padrão de Driscoll-Kraay entre parênteses. *** p<0,01; ** p<0,05; * p<0,1."))

message("Testes de robustez concluídos.")
