# ==============================================================================
# 00_configuracao.R — pacotes, caminhos, definições e funções auxiliares
# ==============================================================================
# Este arquivo é carregado no começo de todos os outros scripts (source()).
# Não precisa rodar sozinho.
#
# IMPORTANTE (RStudio): abra o projeto pelo arquivo TCC_Modelagem.Rproj, que fica
# na raiz do repositório. Assim a pasta de trabalho é a raiz, e o pacote `here`
# encontra os arquivos sem você precisar de setwd().

# ------------------------------------------------------------------------------
# 1) Pacotes: instala os que faltarem e carrega
# ------------------------------------------------------------------------------
pacotes <- c("arrow", "dplyr", "tidyr", "ggplot2", "scales",
             "plm", "lmtest", "sandwich", "flextable", "here")
faltando <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltando) > 0) {
  message("Instalando pacotes: ", paste(faltando, collapse = ", "))
  install.packages(faltando, repos = "https://cloud.r-project.org")
}
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(scales)
  library(plm); library(lmtest); library(sandwich); library(flextable); library(here)
})

# ------------------------------------------------------------------------------
# 2) Caminhos (a partir da raiz do projeto)
# ------------------------------------------------------------------------------
PAINEL_FINAL_REAL <- here("dados", "finais", "painel_final_real.parquet")
BASE_REGRESSAO    <- here("dados", "finais", "base_regressao.rds")
PASTA_TABELAS     <- here("regressao", "saidas", "tabelas")
PASTA_GRAFICOS    <- here("regressao", "saidas", "graficos")
PASTA_MODELOS     <- here("regressao", "saidas", "modelos")
dir.create(PASTA_TABELAS, recursive = TRUE, showWarnings = FALSE)
dir.create(PASTA_GRAFICOS, recursive = TRUE, showWarnings = FALSE)
dir.create(PASTA_MODELOS, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# 3) Definições do estudo
# ------------------------------------------------------------------------------
ANOS_ELEITORAIS     <- c(2016, 2020, 2024)   # eleições municipais dentro de 2013-2025
ANOS_PRE_ELEITORAIS <- ANOS_ELEITORAIS - 1   # 2015, 2019, 2023

# Variáveis dependentes: grupos de funções (id_conta_bd no formato 3.FF.000).
# Ver CLAUDE.md, seção "Variáveis dependentes".
GRUPOS <- list(
  saude_saneamento   = c("3.10.000", "3.17.000"),
  educ_cultura       = c("3.12.000", "3.13.000"),
  habit_urbanismo    = c("3.16.000", "3.15.000"),
  assistencia        = c("3.08.000"),
  transporte         = c("3.26.000"),
  administracao      = c("3.04.000"),
  agricultura        = c("3.20.000"),
  comunicacoes       = c("3.24.000"),
  # só para robustez (agrupamento original do Sakurai):
  assist_previdencia = c("3.08.000", "3.09.000")
)

# Ordem e rótulos para tabelas e gráficos
DEPENDENTES <- c("despesa_total", "saude_saneamento", "educ_cultura", "habit_urbanismo",
                 "assistencia", "transporte", "administracao", "agricultura", "comunicacoes")
ROTULOS <- c(
  despesa_total      = "Despesa total",
  saude_saneamento   = "Saúde e Saneamento",
  educ_cultura       = "Educação e Cultura",
  habit_urbanismo    = "Habitação e Urbanismo",
  assistencia        = "Assistência Social",
  transporte         = "Transporte",
  administracao      = "Administração",
  agricultura        = "Agricultura",
  comunicacoes       = "Comunicações",
  assist_previdencia = "Assistência e Previdência",
  ano_eleitoral      = "Ano eleitoral",
  pre_eleitoral      = "Ano pré-eleitoral",
  coalizao_gov       = "Prefeito na coalizão do governador",
  coalizao_pres      = "Prefeito na coalizão do presidente",
  coalizao_gov_sem_fusao  = "Coalizão governador (sem fusões)",
  coalizao_pres_sem_fusao = "Coalizão presidente (sem fusões)",
  segundo_mandato    = "Prefeito em segundo mandato",
  receita_tributaria_real_pc = "Receita tributária per capita (R$)",
  transf_correntes_real_pc   = "Transferências correntes per capita (R$)",
  perc_jovens        = "Proporção de jovens",
  perc_idosos        = "Proporção de idosos",
  grau_urb           = "Grau de urbanização",
  ln_populacao       = "População (log)",
  pib_nacional_tri   = "PIB nacional (R$ trilhões)",
  ln_pib_mun_pc      = "PIB municipal per capita (log)",
  tendencia          = "Tendência",
  tendencia2         = "Tendência ao quadrado",
  pandemia_2020      = "Pandemia (2020)"
)

# Especificação (ver CLAUDE.md, "Especificação: modelos A e B")
# Modelo A ("ciclo eleitoral"): efeito fixo de município, INTERESSE_A + CONTROLES,
#   erro-padrão de Driscoll-Kraay (robusto a choques comuns aos municípios no ano).
# Modelo B ("coalizões"): efeitos fixos de município e de ano, coalizões +
#   CONTROLES_B, erro-padrão agrupado por município. O efeito de ano absorve tudo
#   o que só varia no tempo (ano eleitoral, PIB nacional, tendências).
INTERESSE_A <- c("ano_eleitoral", "pre_eleitoral", "pandemia_2020",
                 "coalizao_gov", "coalizao_pres")
INTERESSE_B <- c("coalizao_gov", "coalizao_pres")
CONTROLES <- c("receita_tributaria_real_pc", "transf_correntes_real_pc",
               "perc_jovens", "perc_idosos", "grau_urb", "ln_populacao",
               "pib_nacional_tri", "tendencia", "tendencia2")
# Controles que variam entre municípios (os únicos que sobram com efeito de ano)
CONTROLES_B <- c("receita_tributaria_real_pc", "transf_correntes_real_pc",
                 "perc_jovens", "perc_idosos", "grau_urb", "ln_populacao")
# Especificação de Sakurai (2009): usada nas descritivas e no teste de robustez R5
INTERESSE <- c("ano_eleitoral", "coalizao_gov", "coalizao_pres")

# ------------------------------------------------------------------------------
# 4) Funções auxiliares
# ------------------------------------------------------------------------------
rotulo <- function(x) ifelse(x %in% names(ROTULOS), ROTULOS[x], x)

# Método dos efeitos aleatórios. O padrão do plm (Swamy-Arora) usa uma regressão
# "between" (médias por município); as variáveis que só mudam com o ano (ano
# eleitoral, tendências, PIB nacional) não variam entre municípios nessa
# regressão e o cálculo fica singular. Wallace-Hussain estima as variâncias com
# os resíduos do pooled e evita o problema.
METODO_RE <- "walhus"

# Monta a fórmula y ~ x1 + x2 + ...
monta_formula <- function(y, x) as.formula(paste(y, "~", paste(x, collapse = " + ")))

# Erro-padrão agrupado por município (Arellano), para modelos do plm
vcov_cluster <- function(modelo) vcovHC(modelo, method = "arellano", type = "HC1", cluster = "group")

# Erro-padrão de Driscoll-Kraay (robusto a correlação entre municípios no mesmo
# ano e a autocorrelação), usado no modelo A
vcov_dk <- function(m) plm::vcovSCC(m, type = "HC1")

# Estrelas de significância
estrelas <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))

# Tabela de regressão: coeficiente (com estrelas) e erro-padrão entre parênteses.
# modelos: lista nomeada de modelos plm; vars: variáveis a mostrar (NULL = todas)
# vcov_fun: função que calcula a matriz de variância (padrão: agrupada por município)
# Números com vírgula decimal (ex.: 203,869); ponto de milhar só em Observações/Municípios.
num_virgula <- function(x, digitos) formatC(x, format = "f", digits = digitos, decimal.mark = ",")

tabela_regressao <- function(modelos, vars = NULL, digitos = 3, vcov_fun = vcov_cluster) {
  colunas <- lapply(names(modelos), function(nome) {
    m  <- modelos[[nome]]
    ct <- coeftest(m, vcov. = vcov_fun(m))
    tibble(variavel = rownames(ct),
           coef = paste0(num_virgula(ct[, 1], digitos), estrelas(ct[, 4])),
           ep   = paste0("(", num_virgula(ct[, 2], digitos), ")"))
  })
  names(colunas) <- names(modelos)
  todas <- unique(unlist(lapply(colunas, `[[`, "variavel")))
  todas <- setdiff(todas, "(Intercept)")
  if (!is.null(vars)) todas <- intersect(vars, todas)

  linhas <- list()
  for (v in todas) {
    linha_coef <- c("Variável" = rotulo(v))
    linha_ep   <- c("Variável" = "")
    for (nome in names(colunas)) {
      cl <- colunas[[nome]]
      i  <- match(v, cl$variavel)
      linha_coef[nome] <- if (is.na(i)) "" else cl$coef[i]
      linha_ep[nome]   <- if (is.na(i)) "" else cl$ep[i]
    }
    linhas[[length(linhas) + 1]] <- linha_coef
    linhas[[length(linhas) + 1]] <- linha_ep
  }
  # Rodapé: observações, municípios e R² (within, no caso de efeitos fixos)
  obs  <- c("Variável" = "Observações")
  muni <- c("Variável" = "Municípios")
  r2   <- c("Variável" = "R²")
  for (nome in names(modelos)) {
    m <- modelos[[nome]]
    obs[nome]  <- format(nobs(m), big.mark = ".", decimal.mark = ",")
    muni[nome] <- format(pdim(m)$nT$n, big.mark = ".", decimal.mark = ",")
    r2[nome]   <- num_virgula(summary(m)$r.squared["rsq"], 3)
  }
  as.data.frame(do.call(rbind, c(linhas, list(obs, muni, r2))), check.names = FALSE)
}

# Salva uma tabela em .csv (abre no Excel) e .docx (cola no Word)
salva_tabela <- function(tabela, nome, titulo = NULL, nota = NULL) {
  write.csv2(tabela, file.path(PASTA_TABELAS, paste0(nome, ".csv")), row.names = FALSE,
             fileEncoding = "UTF-8")
  ft <- flextable(tabela)
  ft <- autofit(ft)
  if (!is.null(titulo)) ft <- set_caption(ft, titulo)
  if (!is.null(nota))   ft <- add_footer_lines(ft, nota)
  save_as_docx(ft, path = file.path(PASTA_TABELAS, paste0(nome, ".docx")))
  message("Tabela salva: ", nome, " (.csv e .docx)")
  invisible(ft)
}

# Teste de Hausman robusto (versão de Mundlak; Wooldridge, 2010, cap. 10).
# Regressão pooled de y nas explicativas + médias de cada município das explicativas
# que variam entre municípios; erros agrupados por município. H0: as médias são
# conjuntamente zero (efeitos aleatórios consistentes). Rejeitar => efeitos fixos.
# Variáveis que só mudam com o ano (ano eleitoral, tendências, PIB nacional) ficam
# fora das médias: elas não variam entre municípios.
hausman_mundlak <- function(dados, y, x, so_tempo = c("ano_eleitoral", "pre_eleitoral", "pandemia_2020",
                                                     "tendencia", "tendencia2", "pib_nacional_tri")) {
  d <- dados[stats::complete.cases(dados[, c(y, x)]), c("id_municipio", y, x)]
  com_media <- setdiff(x, so_tempo)
  for (v in com_media) d[[paste0("media_", v)]] <- ave(d[[v]], d$id_municipio)
  medias <- paste0("media_", com_media)
  m <- lm(monta_formula(y, c(x, medias)), data = d)
  b <- coef(m)[medias]
  ok <- !is.na(b)                      # médias perfeitamente colineares saem do teste
  V <- sandwich::vcovCL(m, cluster = d$id_municipio, type = "HC1")[medias[ok], medias[ok], drop = FALSE]
  estat <- as.numeric(t(b[ok]) %*% solve(V) %*% b[ok])
  list(statistic = estat, df = sum(ok), p.value = pchisq(estat, df = sum(ok), lower.tail = FALSE))
}

NOTA_EP <- paste("Erros-padrão agrupados por município entre parênteses.",
                 "*** p<0,01; ** p<0,05; * p<0,1.")
NOTA_A <- paste("Efeito fixo de município. Erros-padrão de Driscoll-Kraay entre parênteses.",
                "*** p<0,01; ** p<0,05; * p<0,1.")
NOTA_B <- paste("Efeitos fixos de município e de ano. Erros-padrão agrupados por município",
                "entre parênteses. *** p<0,01; ** p<0,05; * p<0,1.")

# Carrega a base de regressão (gerada por 01_base_regressao.R)
# limpa = TRUE (padrão): tira os município-anos com outlier_despesa == 1
# (ver CLAUDE.md, "Limpeza da base"). limpa = FALSE: base inteira (teste R10/R11).
carrega_base <- function(limpa = TRUE) {
  if (!file.exists(BASE_REGRESSAO)) stop("Rode primeiro o 01_base_regressao.R")
  base <- readRDS(BASE_REGRESSAO)
  if (limpa) base <- base |> filter(outlier_despesa == 0)
  base
}
