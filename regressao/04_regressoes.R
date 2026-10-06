# ==============================================================================
# 04_regressoes.R — modelos principais (painel)
# ==============================================================================
# Dois modelos, cada um com as 9 variáveis dependentes (per capita, R$ de 2025):
#
# Modelo A ("ciclo eleitoral"): efeito fixo de município
#   y_it = ano eleitoral + pré-eleitoral + pandemia (2020) + coalizões
#          + controles (inclui PIB nacional e tendências) + efeito do município
#   Erro-padrão de Driscoll-Kraay: o ano eleitoral é igual para todos os
#   municípios, então o erro precisa ser robusto a choques comuns no ano.
#
# Modelo B ("coalizões"): efeitos fixos de município e de ano
#   y_it = coalizões + controles que variam entre municípios
#          + efeito do município + efeito do ano
#   O efeito de ano separa o alinhamento político do período (sem ele, a
#   coalizão presidencial confunde alinhamento com o governo da época).
#   Erro-padrão agrupado por município.
#
# Ver CLAUDE.md, "Especificação: modelos A e B".
source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()
pbase <- pdata.frame(base, index = c("id_municipio", "ano"))

X_A <- c(INTERESSE_A, CONTROLES)
X_B <- c(INTERESSE_B, CONTROLES_B)

# ------------------------------------------------------------------------------
# 1) Modelo A: efeito fixo de município, erro Driscoll-Kraay
# ------------------------------------------------------------------------------
modelos_A <- list()
for (v in DEPENDENTES) {
  modelos_A[[rotulo(v)]] <- plm(monta_formula(paste0(v, "_pc"), X_A), data = pbase,
                                model = "within", effect = "individual")
  message("Modelo A estimado: ", rotulo(v))
}
tab_A <- tabela_regressao(modelos_A, vars = X_A, vcov_fun = vcov_dk)
print(tab_A, row.names = FALSE)
salva_tabela(tab_A, "regressao_principal_A",
             titulo = "Modelo A (ciclo eleitoral): despesas municipais per capita, efeito fixo de município",
             nota = paste("Variáveis dependentes: despesa per capita por grupo de funções (R$ de 2025).",
                          NOTA_A))

# ------------------------------------------------------------------------------
# 2) Modelo B: efeitos fixos de município e de ano, erro agrupado por município
# ------------------------------------------------------------------------------
modelos_B <- list()
for (v in DEPENDENTES) {
  modelos_B[[rotulo(v)]] <- plm(monta_formula(paste0(v, "_pc"), X_B), data = pbase,
                                model = "within", effect = "twoways")
  message("Modelo B estimado: ", rotulo(v))
}
tab_B <- tabela_regressao(modelos_B, vars = X_B, vcov_fun = vcov_cluster)
print(tab_B, row.names = FALSE)
salva_tabela(tab_B, "regressao_principal_B",
             titulo = "Modelo B (coalizões): despesas municipais per capita, efeitos fixos de município e de ano",
             nota = paste("Variáveis dependentes: despesa per capita por grupo de funções (R$ de 2025).",
                          NOTA_B))

saveRDS(list(A = modelos_A, B = modelos_B), file.path(PASTA_MODELOS, "modelos_principais.rds"))

# ------------------------------------------------------------------------------
# 3) Comparação pooled x efeitos fixos x efeitos aleatórios (despesa total),
#    com a especificação do modelo A e erro de Driscoll-Kraay
# ------------------------------------------------------------------------------
f_total <- monta_formula("despesa_total_pc", X_A)
comparacao <- list(
  "Pooled (MQO)"       = plm(f_total, data = pbase, model = "pooling"),
  "Efeitos fixos"      = plm(f_total, data = pbase, model = "within"),
  "Efeitos aleatórios" = plm(f_total, data = pbase, model = "random", random.method = METODO_RE)
)
tab_comp <- tabela_regressao(comparacao, vars = X_A, vcov_fun = vcov_dk)
print(tab_comp, row.names = FALSE)
salva_tabela(tab_comp, "comparacao_estimadores_despesa_total",
             titulo = "Despesa total per capita (especificação do modelo A): pooled, efeitos fixos e efeitos aleatórios",
             nota = paste("Erros-padrão de Driscoll-Kraay entre parênteses.",
                          "*** p<0,01; ** p<0,05; * p<0,1."))
