# ==============================================================================
# 02_descritivas.R — estatísticas descritivas e gráficos das variáveis dependentes
# ==============================================================================
# Saídas (regressao/saidas/):
#   tabelas/descritivas_explicativas.(csv|docx)  — média, desvio-padrão, mín., máx., N
#   tabelas/descritivas_dependentes.(csv|docx)   — o mesmo para as dependentes per capita
#   graficos/serie_<variavel>_nivel.png e        — média anual, em nível e em log,
#   graficos/serie_<variavel>_log.png              com anos eleitorais e pré-eleitorais marcados
#   graficos/grupos_painel_1.png e _2.png        — os 8 grupos em dois painéis 2 x 2 (log)
#   tabelas/medias_anuais_grupos.csv             — média anual em R$ e em ln(1 + x)
#   graficos/receitas_painel.png                 — receita tributária e transferências correntes (log)
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
                  setdiff(CONTROLES_NIVEL, c("tendencia", "tendencia2")))   # em reais, como sempre
tab_x <- descreve(base, explicativas)
print(tab_x)
salva_tabela(tab_x, "descritivas_explicativas",
             titulo = "Estatísticas descritivas das variáveis explicativas (2013-2025)",
             nota = "Valores monetários em R$ de 2025 (IPCA médio anual). Variáveis binárias: a média é a proporção de 1.")

dep_pc <- paste0(DEPENDENTES, "_pc")
# Só nesta tabela: negativos como ausentes, como no ln(1 + x) dos modelos; os zeros ficam.
# A base e as colunas <var>_pc continuam como estão.
base_sem_negativos <- base |> mutate(across(all_of(dep_pc), ~ ifelse(.x < 0, NA, .x)))
tab_y <- descreve(base_sem_negativos, dep_pc)
tab_y[["Variável"]] <- rotulo(DEPENDENTES)
print(tab_y)
salva_tabela(tab_y, "descritivas_dependentes",
             titulo = "Estatísticas descritivas das despesas per capita (R$ de 2025)",
             nota = paste("Despesas pagas por função (Siconfi, Anexo 1-E), deflacionadas pelo IPCA médio anual.",
                          "Valores negativos registrados no Siconfi (sete município-anos) foram tratados como ausentes,",
                          "como nos modelos, em que a despesa entra em ln(1 + valor per capita); os valores iguais a zero foram mantidos."))

# ------------------------------------------------------------------------------
# 2) Séries temporais: média anual entre os municípios
#    - nível: média da despesa per capita (R$)
#    - log:   média de ln(1 + despesa per capita), a mesma forma dos modelos
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
  coluna <- if (escala == "nivel") paste0(v, "_pc") else dep_log(v)
  serie <- base |>
    group_by(ano) |>
    summarise(y = mean(.data[[coluna]], na.rm = TRUE),
              municipios = sum(!is.na(.data[[coluna]])), .groups = "drop")
  eixo_y <- if (escala == "nivel") "Média per capita (R$ de 2025)" else "Média de ln(1 + despesa per capita)"

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

# Figuras do TCC: os 8 grupos em dois painéis 2 x 2, em ln(1 + x) e escalas livres
painel_grupos <- function(grupos, arquivo) {
  dados <- base |>
    select(ano, all_of(dep_log(grupos))) |>
    pivot_longer(-ano, names_to = "variavel", values_to = "valor") |>
    mutate(variavel = sub("^ln1p_(.*)_pc$", "\\1", variavel),
           variavel = factor(rotulo(variavel), levels = rotulo(grupos))) |>
    group_by(ano, variavel) |>
    summarise(y = mean(valor, na.rm = TRUE), .groups = "drop")

  g <- ggplot(dados, aes(ano, y)) +
    geom_rect(data = faixas, inherit.aes = FALSE,
              aes(xmin = ano - 0.5, xmax = ano + 0.5, ymin = -Inf, ymax = Inf, fill = tipo),
              alpha = 0.18) +
    geom_line(color = COR_LINHA, linewidth = 0.7) +
    geom_point(color = COR_LINHA, size = 1.6) +
    facet_wrap(~ variavel, scales = "free_y", ncol = 2) +
    scale_fill_manual(values = CORES_FAIXA, name = NULL) +
    scale_x_continuous(breaks = c(2013, 2016, 2019, 2022, 2025)) +
    scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
    labs(x = NULL, y = "Média de ln(1 + despesa per capita)") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top", panel.grid.minor = element_blank(),
          strip.text = element_text(face = "bold"))
  ggsave(file.path(PASTA_GRAFICOS, arquivo), g, width = 9, height = 8, dpi = 300, bg = "white")
}
painel_grupos(c("habit_urbanismo", "transporte", "saude_saneamento", "assistencia"), "grupos_painel_1.png")
painel_grupos(c("educ_cultura", "administracao", "agricultura", "comunicacoes"), "grupos_painel_2.png")
message("Painéis dos grupos salvos.")

# ------------------------------------------------------------------------------
# 3) Média anual de cada variável, em R$ e em ln(1 + x): só para embasar o texto
#    da seção de evolução das despesas; não vai para o TCC
# ------------------------------------------------------------------------------
medias <- do.call(rbind, lapply(DEPENDENTES, function(v) {
  base |>
    group_by(ano) |>
    summarise(`Média (R$)`    = round(mean(.data[[paste0(v, "_pc")]], na.rm = TRUE), 2),
              `Média ln(1+x)` = round(mean(.data[[dep_log(v)]], na.rm = TRUE), 3),
              .groups = "drop") |>
    mutate(`Variável` = rotulo(v), .before = 1)
}))
print(as.data.frame(medias), row.names = FALSE)
write.csv2(medias, file.path(PASTA_TABELAS, "medias_anuais_grupos.csv"), row.names = FALSE,
           fileEncoding = "UTF-8")
message("Tabela salva: medias_anuais_grupos.csv")

# ------------------------------------------------------------------------------
# 4) Receitas: média anual de ln(1 + receita per capita), as mesmas variáveis
#    dos modelos, no mesmo estilo das figuras dos grupos
# ------------------------------------------------------------------------------
RECEITAS <- c("receita_tributaria_real_pc" = "Receita tributária",
              "transf_correntes_real_pc"   = "Transferências correntes")

dados_rec <- base |>
  select(ano, all_of(paste0("ln1p_", names(RECEITAS)))) |>
  pivot_longer(-ano, names_to = "variavel", values_to = "valor") |>
  mutate(variavel = factor(RECEITAS[sub("^ln1p_", "", variavel)], levels = RECEITAS)) |>
  group_by(ano, variavel) |>
  summarise(y = mean(valor, na.rm = TRUE), .groups = "drop")

g_rec <- ggplot(dados_rec, aes(ano, y)) +
  geom_rect(data = faixas, inherit.aes = FALSE,
            aes(xmin = ano - 0.5, xmax = ano + 0.5, ymin = -Inf, ymax = Inf, fill = tipo),
            alpha = 0.18) +
  geom_line(color = COR_LINHA, linewidth = 0.7) +
  geom_point(color = COR_LINHA, size = 1.6) +
  facet_wrap(~ variavel, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = CORES_FAIXA, name = NULL) +
  scale_x_continuous(breaks = c(2013, 2016, 2019, 2022, 2025)) +
  scale_y_continuous(labels = label_number(accuracy = 0.1, decimal.mark = ",")) +
  labs(x = NULL, y = "Média de ln(1 + receita per capita)") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "top", panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))
ggsave(file.path(PASTA_GRAFICOS, "receitas_painel.png"), g_rec, width = 9, height = 4.5, dpi = 300, bg = "white")
message("Painel das receitas salvo.")

# Média anual das receitas, em ln(1 + x) e em R$: só impressa, para comparar com as despesas
medias_rec <- base |>
  group_by(ano) |>
  summarise(trib_ln    = round(mean(ln1p_receita_tributaria_real_pc, na.rm = TRUE), 3),
            trib_reais = round(mean(receita_tributaria_real_pc, na.rm = TRUE), 2),
            transf_ln    = round(mean(ln1p_transf_correntes_real_pc, na.rm = TRUE), 3),
            transf_reais = round(mean(transf_correntes_real_pc, na.rm = TRUE), 2),
            .groups = "drop")
print(as.data.frame(medias_rec), row.names = FALSE)
