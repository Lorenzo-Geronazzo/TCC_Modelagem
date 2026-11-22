# ==============================================================================
# 02c_figuras_slides.R — figuras só para os slides da defesa (formato 16:9)
# ==============================================================================
# Saídas (em ../TCC_latex/apresentacao/figuras/):
#   grupos_slides_A.png (Habitação e Urbanismo | Transporte) e
#   grupos_slides_B.png (Saúde e Saneamento | Assistência Social)
#     — os quatro painéis de grupos_painel_1.png (FIGURA 3 do TCC: média anual de
#       ln(1 + x), base limpa, faixas nos anos eleitorais e pré-eleitorais), dois por
#       figura, lado a lado (1 × 2), com escala do eixo y livre em cada painel.
#   serie_despesa_total_slides.png
#     — mesma série de serie_despesa_total_log.png (FIGURA 1 do TCC: despesa total,
#       média anual de ln(1 + x), base limpa, mesmas faixas), sem título nem nota
#       dentro da imagem (o título do slide já diz o que é); a legenda das faixas fica.
# As duas em 13,33 × 7,5 pol. a 300 dpi, com fontes maiores, para leitura no projetor.
# Eixo y: marcas só em múltiplos de 0,1 (passo de 0,1, 0,2 ou 0,5), para que o
# rótulo com uma casa decimal mostre exatamente o valor da marca (no TCC, as marcas
# automáticas do Transporte caem em 4,25 e 4,75 e o rótulo arredonda).
# Não altera as figuras do TCC: os dados repetem painel_grupos() e grafico_serie()
# do 02_descritivas.R; mudam só o tamanho, as fontes e as marcas do eixo y.
# Se o 02 mudar, mudar aqui também. Não faz parte do rodar_tudo.R.
source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()

PASTA_SLIDES <- normalizePath(here("..", "TCC_latex", "apresentacao"), mustWork = TRUE)
PASTA_FIG_SLIDES <- file.path(PASTA_SLIDES, "figuras")
dir.create(PASTA_FIG_SLIDES, showWarnings = FALSE)

anos <- sort(unique(base$ano))
faixas <- data.frame(
  ano  = c(ANOS_ELEITORAIS, ANOS_PRE_ELEITORAIS),
  tipo = rep(c("Ano eleitoral", "Ano pré-eleitoral"), each = length(ANOS_ELEITORAIS))
) |> filter(ano %in% anos)

COR_LINHA   <- "#1F2937"
CORES_FAIXA <- c("Ano eleitoral" = "#C2410C", "Ano pré-eleitoral" = "#F59E0B")
LARGURA_SLIDE <- 13.333
ALTURA_SLIDE  <- 7.5

# Marcas do eixo y em valores redondos de uma casa decimal: o menor passo
# (0,1, 0,2, 0,5 ou 1) que deixa no máximo 6 marcas dentro dos limites do painel.
marcas_uma_casa <- function(limites) {
  for (passo in c(0.1, 0.2, 0.5, 1)) {
    m <- seq(ceiling(limites[1] / passo - 1e-9) * passo,
             floor(limites[2] / passo + 1e-9) * passo, by = passo)
    if (length(m) <= 6) return(round(m, 1))
  }
}
eixo_y_slides <- scale_y_continuous(breaks = marcas_uma_casa,
                                    labels = label_number(accuracy = 0.1, decimal.mark = ","))

# Elementos comuns às duas figuras: faixas, linha, pontos, legenda e fontes
camadas_slides <- list(
  geom_rect(data = faixas, inherit.aes = FALSE,
            aes(xmin = ano - 0.5, xmax = ano + 0.5, ymin = -Inf, ymax = Inf, fill = tipo),
            alpha = 0.18),
  geom_line(color = COR_LINHA, linewidth = 1.2),
  geom_point(color = COR_LINHA, size = 2.8),
  scale_fill_manual(values = CORES_FAIXA, name = NULL),
  eixo_y_slides,
  theme_minimal(base_size = 24),
  theme(legend.position = "top", panel.grid.minor = element_blank(),
        strip.text   = element_text(face = "bold", size = 24),
        axis.text    = element_text(size = 22),
        axis.title.y = element_text(size = 20),
        legend.text  = element_text(size = 22),
        legend.key.size = unit(1.2, "lines"),
        panel.spacing = unit(1.5, "lines"))
)

salva_slide <- function(g, arquivo) {
  ggsave(file.path(PASTA_FIG_SLIDES, arquivo), g,
         width = LARGURA_SLIDE, height = ALTURA_SLIDE, dpi = 300, bg = "white")
}

# 1) FIGURA 3 em 16:9: dois grupos por figura, lado a lado (ncol = 2 com dois grupos
#    dá 1 × 2), escalas livres; legenda no topo e título do eixo y únicos
painel_grupos_slides <- function(grupos, arquivo) {
  dados <- base |>
    select(ano, all_of(dep_log(grupos))) |>
    pivot_longer(-ano, names_to = "variavel", values_to = "valor") |>
    mutate(variavel = sub("^ln1p_(.*)_pc$", "\\1", variavel),
           variavel = factor(rotulo(variavel), levels = rotulo(grupos))) |>
    group_by(ano, variavel) |>
    summarise(y = mean(valor, na.rm = TRUE), .groups = "drop")

  g <- ggplot(dados, aes(ano, y)) +
    camadas_slides +
    facet_wrap(~ variavel, scales = "free_y", ncol = 2) +
    scale_x_continuous(breaks = c(2013, 2016, 2019, 2022, 2025)) +
    labs(x = NULL, y = "Média do logaritmo da despesa per capita")
  salva_slide(g, arquivo)
  invisible(g)
}

# 2) FIGURA 1 em 16:9: despesa total, sem título nem nota na imagem
serie_total_slides <- function(arquivo) {
  coluna <- dep_log("despesa_total")
  serie <- base |>
    group_by(ano) |>
    summarise(y = mean(.data[[coluna]], na.rm = TRUE), .groups = "drop")

  g <- ggplot(serie, aes(ano, y)) +
    camadas_slides +
    scale_x_continuous(breaks = anos) +
    labs(x = NULL, y = "Média do logaritmo da despesa per capita")
  salva_slide(g, arquivo)
  invisible(g)
}

g_grupos_A <- painel_grupos_slides(c("habit_urbanismo", "transporte"), "grupos_slides_A.png")
g_grupos_B <- painel_grupos_slides(c("saude_saneamento", "assistencia"), "grupos_slides_B.png")
g_total  <- serie_total_slides("serie_despesa_total_slides.png")
message("Figuras dos slides salvas em ", PASTA_FIG_SLIDES)
