# ==============================================================================
# 04_regressoes.R — modelo principal (painel), como Sakurai (2009)
# ==============================================================================
# Uma regressão para cada variável dependente (per capita, R$ de 2025):
#   y_it = b1*ano_eleitoral_t + b2*coalizao_gov_it + b3*coalizao_pres_it
#          + controles_it + tendência + tendência² + efeito do município + erro
# Erros-padrão agrupados por município.
#
# MODELO: "within" = efeitos fixos; "random" = efeitos aleatórios.
# Use o que o 03_hausman.R indicar (Sakurai: efeitos fixos em todas as funções).
MODELO <- "within"

source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()
pbase <- pdata.frame(base, index = c("id_municipio", "ano"))

nome_modelo <- ifelse(MODELO == "within", "efeitos fixos", "efeitos aleatórios")

# ------------------------------------------------------------------------------
# 1) Modelo principal: as 9 variáveis dependentes
# ------------------------------------------------------------------------------
modelos <- list()
for (v in DEPENDENTES) {
  f <- monta_formula(paste0(v, "_pc"), c(INTERESSE, CONTROLES))
  modelos[[rotulo(v)]] <- plm(f, data = pbase, model = MODELO, random.method = METODO_RE)
  message("Estimado: ", rotulo(v))
}

tab <- tabela_regressao(modelos, vars = c(INTERESSE, CONTROLES))
print(tab, row.names = FALSE)
salva_tabela(tab, "regressao_principal",
             titulo = paste0("Ciclo eleitoral e despesas municipais per capita — ", nome_modelo),
             nota = paste("Variáveis dependentes: despesa per capita por grupo de funções (R$ de 2025).",
                          NOTA_EP))
saveRDS(modelos, file.path(PASTA_TABELAS, "modelos_principais.rds"))

# ------------------------------------------------------------------------------
# 2) Comparação pooled x efeitos fixos x efeitos aleatórios (despesa total)
#    Sakurai reporta só efeitos fixos; esta tabela pode ir para o apêndice.
# ------------------------------------------------------------------------------
f_total <- monta_formula("despesa_total_pc", c(INTERESSE, CONTROLES))
comparacao <- list(
  "Pooled (MQO)"       = plm(f_total, data = pbase, model = "pooling"),
  "Efeitos fixos"      = plm(f_total, data = pbase, model = "within"),
  "Efeitos aleatórios" = plm(f_total, data = pbase, model = "random", random.method = METODO_RE)
)
tab_comp <- tabela_regressao(comparacao, vars = c(INTERESSE, CONTROLES))
print(tab_comp, row.names = FALSE)
salva_tabela(tab_comp, "comparacao_estimadores_despesa_total",
             titulo = "Despesa total per capita: pooled, efeitos fixos e efeitos aleatórios",
             nota = NOTA_EP)
