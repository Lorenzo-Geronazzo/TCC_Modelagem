# ==============================================================================
# 03_hausman.R — pooled, efeitos fixos, efeitos aleatórios e teste de Hausman
# ==============================================================================
# Para cada variável dependente:
#   - estima pooled (MQO), efeitos fixos (within) e efeitos aleatórios;
#   - teste de Hausman clássico (H0: efeitos aleatórios é consistente e eficiente);
#   - teste de Hausman robusto (versão de Mundlak, com erros agrupados por município),
#     porque o clássico supõe erros homocedásticos e sem correlação no tempo.
# Rejeitar H0 (p < 0,05) => usar efeitos fixos, como em Sakurai (2009).
# Saída: tabelas/hausman.(csv|docx)
source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()
pbase <- pdata.frame(base, index = c("id_municipio", "ano"))

resultados <- list()
for (v in DEPENDENTES) {
  y <- paste0(v, "_pc")
  f <- monta_formula(y, c(INTERESSE_A, CONTROLES))   # modelo A
  message("Hausman: ", rotulo(v))

  fe <- plm(f, data = pbase, model = "within")
  re <- plm(f, data = pbase, model = "random", random.method = METODO_RE)
  h_classico <- phtest(fe, re)
  h_robusto  <- tryCatch(
    hausman_mundlak(base, y, c(INTERESSE_A, CONTROLES)),
    error = function(e) { message("  Hausman robusto falhou: ", conditionMessage(e)); NULL }
  )

  resultados[[v]] <- data.frame(
    `Variável dependente`  = rotulo(v),
    `Hausman (χ²)`         = round(unname(h_classico$statistic), 2),
    `p-valor`              = signif(h_classico$p.value, 3),
    `Hausman robusto`      = if (is.null(h_robusto)) NA else round(unname(h_robusto$statistic), 2),
    `p-valor (robusto)`    = if (is.null(h_robusto)) NA else signif(h_robusto$p.value, 3),
    `Indicado (clássico)`  = ifelse(h_classico$p.value < 0.05, "Efeitos fixos", "Efeitos aleatórios"),
    `Indicado (robusto)`   = if (is.null(h_robusto)) NA else
                               ifelse(h_robusto$p.value < 0.05, "Efeitos fixos", "Efeitos aleatórios"),
    # Tamanho da amostra do modelo de efeitos fixos (município-anos e municípios)
    `Observações`          = nobs(fe),
    `Municípios`           = pdim(fe)$nT$n,
    check.names = FALSE
  )
}
tab_h <- do.call(rbind, resultados)
print(tab_h, row.names = FALSE)
salva_tabela(tab_h, "hausman",
             titulo = "Teste de Hausman: efeitos fixos x efeitos aleatórios",
             nota = paste("H0: o estimador de efeitos aleatórios é consistente e eficiente.",
                          "Robusto: teste de Mundlak (médias por município das explicativas), com erros agrupados por município."))
