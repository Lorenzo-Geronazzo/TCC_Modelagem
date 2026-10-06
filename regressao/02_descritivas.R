# ==============================================================================
# 02_descritivas.R — estatísticas descritivas e gráficos das variáveis dependentes
# ==============================================================================
# Saídas (regressao/saidas/):
#   tabelas/descritivas_explicativas.(csv|docx)  — média, desvio-padrão, mín., máx., N
#   tabelas/descritivas_dependentes.(csv|docx)   — o mesmo para as dependentes per capita
#   graficos/serie_<variavel>_nivel.png e        — média anual, em nível e em log,
#   graficos/serie_<variavel>_log.png              com anos eleitorais e pré-eleitorais marcados
#   graficos/series_todas_log.png                — as 9 variáveis num painel só (log)
source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()

# ------------------------------------------------------------------------------
# 1) Tabelas descritivas
# ------------------------------------------------------------------------------
descreve <- function(dados, variaveis) {
  do.call(rbind, lapply(variaveis, function(v) {
    x <- dados[[v]]
    data.frame(
      "Variável" = rotulo(v),
      "N"             = format(sum(!is.na(x)), big.mark = ".", decimal.mark = ","),
      "Média"         = round(mean(x, na.rm = TRUE), 3),
      "Desvio-padrão" = round(sd(x, na.rm = TRUE), 3),
      "Mínimo"        = round(min(x, na.rm = TRUE), 3),
      "Máximo"        = round(max(x, na.rm = TRUE), 3),
      check.names = FALSE
    )
  }))
}

explicativas <- c(INTERESSE, "pre_eleitoral", "segundo_mandato",
                  setdiff(CONTROLES, c("tendencia", "tendencia2")))
tab_x <- descreve(base, explicativas)
print(tab_x)
salva_tabela(tab_x, "descritivas_explicativas",
             titulo = "Estatísticas descritivas das variáveis explicativas (2013-2025)",
             nota = "Valores monetários em R$ de 2025 (IPCA médio anual). Variáveis binárias: a média é a proporção de 1.")

dep_pc <- paste0(DEPENDENTES, "_pc")
tab_y <- descreve(base, dep_pc)
tab_y[["Variável"]] <- rotulo(DEPENDENTES)
print(tab_y)
salva_tabela(tab_y, "descritivas_dependentes",
             titulo = "Estatísticas descritivas das despesas per capita (R$ de 2025)",
             nota = "Despesas pagas por função (Siconfi, Anexo 1-E), deflacionadas pelo IPCA médio anual.")

# ------------------------------------------------------------------------------
# 2) Séries temporais: média anual entre os municípios
#    - nível: média da despesa per capita (R$)
#    - log:   média do log da despesa per capita (menos sensível a valores extremos)
# ------------------------------------------------------------------------------
anos <- sort(unique(base$ano))
faixas <- data.frame(
  ano  = c(ANOS_ELEITORAIS, ANOS_PRE_ELEITORAIS),
  tipo = rep(c("Ano eleitoral", "Ano pré-eleitoral"), each = length(ANOS_ELEITORAIS))
) |> filter(ano %in% anos)

COR_LINHA  <- "#1F2937"   # tinta escura (uma série só: não precisa de cor de categoria)
CORES_FAIXA <- c("Ano eleitoral" = "#C2410C", "Ano pré-eleitoral" = "#F59E0B")

grafico_serie <- function(v, escala = c("nivel", "log")) {
  escala <- match.arg(escala)
  coluna <- if (escala == "nivel") paste0(v, "_pc") else paste0("ln_", v, "_pc")
  serie <- base |>
    group_by(ano) |>
    summarise(y = mean(.data[[coluna]], na.rm = TRUE),
              municipios = sum(!is.na(.data[[coluna]])), .groups = "drop")
  eixo_y <- if (escala == "nivel") "Média per capita (R$ de 2025)" else "Média do log da despesa per capita"

  ggplot(serie, aes(ano, y)) +
    geom_rect(data = faixas, inherit.aes = FALSE,
              aes(xmin = ano - 0.5, xmax = ano + 0.5, ymin = -Inf, ymax = Inf, fill = tipo),
              alpha = 0.18) +
    geom_line(color = COR_LINHA, linewidth = 0.8) +
    geom_point(color = COR_LINHA, size = 2) +
    scale_fill_manual(values = CORES_FAIXA, name = NULL) +
    scale_x_continuous(breaks = anos) +
    scale_y_continuous(labels = label_number(big.mark = ".", decimal.mark = ",")) +
    labs(title = rotulo(v), x = NULL, y = eixo_y,
         caption = "Faixas: anos eleitorais (2016, 2020, 2024) e pré-eleitorais (2015, 2019, 2023).") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "top", panel.grid.minor = element_blank(),
          axis.text.x = element_text(angle = 45, hjust = 1),
          plot.caption = element_text(color = "grey40", size = 8))
}

for (v in DEPENDENTES) {
  for (esc in c("nivel", "log")) {
    g <- grafico_serie(v, esc)
    arquivo <- file.path(PASTA_GRAFICOS, paste0("serie_", v, "_", esc, ".png"))
    ggsave(arquivo, g, width = 7, height = 4, dpi = 300, bg = "white")
  }
}
message("Gráficos individuais salvos em ", PASTA_GRAFICOS)

# Painel com as 9 variáveis (em log, escalas livres)
todas <- base |>
  select(ano, all_of(paste0("ln_", DEPENDENTES, "_pc"))) |>
  pivot_longer(-ano, names_to = "variavel", values_to = "valor") |>
  mutate(variavel = sub("^ln_(.*)_pc$", "\\1", variavel),
         variavel = factor(rotulo(variavel), levels = rotulo(DEPENDENTES))) |>
  group_by(ano, variavel) |>
  summarise(y = mean(valor, na.rm = TRUE), .groups = "drop")

g_todas <- ggplot(todas, aes(ano, y)) +
  geom_rect(data = faixas, inherit.aes = FALSE,
            aes(xmin = ano - 0.5, xmax = ano + 0.5, ymin = -Inf, ymax = Inf, fill = tipo),
            alpha = 0.18) +
  geom_line(color = COR_LINHA, linewidth = 0.6) +
  geom_point(color = COR_LINHA, size = 1.2) +
  facet_wrap(~ variavel, scales = "free_y", ncol = 3) +
  scale_fill_manual(values = CORES_FAIXA, name = NULL) +
  scale_x_continuous(breaks = c(2013, 2016, 2019, 2022, 2025)) +
  labs(x = NULL, y = "Média do log da despesa per capita (R$ de 2025)") +
  theme_minimal(base_size = 10) +
  theme(legend.position = "top", panel.grid.minor = element_blank())

ggsave(file.path(PASTA_GRAFICOS, "series_todas_log.png"), g_todas,
       width = 10, height = 8, dpi = 300, bg = "white")
message("Painel com todas as séries salvo.")
