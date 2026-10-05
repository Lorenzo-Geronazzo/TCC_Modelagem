# ==============================================================================
# 01_base_regressao.R — monta a base de regressão (uma linha por município-ano)
# ==============================================================================
# Entrada: dados/finais/painel_final_real.parquet (uma linha por município x ano x conta)
# Saída:   dados/finais/base_regressao.rds        (uma linha por município x ano)
#
# Passos:
#   1. Lê só as colunas necessárias do painel.
#   2. Separa as linhas de FUNÇÃO (id_conta_bd 3.FF.000, sem o total 3.00.000).
#   3. Soma as funções em cada grupo (variáveis dependentes) e a despesa total.
#   4. Junta os atributos do município-ano (política, receitas, controles).
#   5. Cria per capita, ano eleitoral, pré-eleitoral e tendências.
source(here::here("regressao", "00_configuracao.R"))

# ------------------------------------------------------------------------------
# 1) Leitura
# ------------------------------------------------------------------------------
COLUNAS_CONTA <- c("ano", "id_municipio", "id_conta_bd", "valor_real")
COLUNAS_MUNICIPIO_ANO <- c(
  "ano", "id_municipio", "sigla_uf", "populacao",
  "receita_tributaria_real_pc", "transf_correntes_real_pc",
  "perc_jovens", "perc_idosos", "grau_urb",
  "pib_nacional_real", "pib_real",
  "partido_prefeito", "coalizao_gov", "coalizao_pres",
  "coalizao_gov_sem_fusao", "coalizao_pres_sem_fusao",
  "segundo_mandato", "prefeito_suplementar", "governador_suplementar"
)
colunas <- unique(c(COLUNAS_CONTA, COLUNAS_MUNICIPIO_ANO))

message("Lendo o painel (pode demorar um pouco)...")
painel <- tryCatch(
  arrow::read_parquet(PAINEL_FINAL_REAL, col_select = all_of(colunas)),
  error = function(e) {
    existentes <- names(arrow::open_dataset(PAINEL_FINAL_REAL)$schema)
    stop("Colunas não encontradas no painel: ",
         paste(setdiff(colunas, existentes), collapse = ", "),
         "\nConfira os nomes com: names(arrow::open_dataset(PAINEL_FINAL_REAL)$schema)")
  }
)
painel <- painel |> mutate(id_municipio = as.character(id_municipio), ano = as.integer(ano))
message("Painel: ", format(nrow(painel), big.mark = ".", decimal.mark = ","), " linhas")

# ------------------------------------------------------------------------------
# 2) Só as linhas de função (3.FF.000), sem o total 3.00.000
#    (o mesmo dinheiro aparece no total, na função e na subfunção: nunca somar tudo)
# ------------------------------------------------------------------------------
funcoes <- painel |>
  filter(grepl("^3\\.\\d\\d\\.000$", id_conta_bd), id_conta_bd != "3.00.000") |>
  group_by(ano, id_municipio, id_conta_bd) |>
  summarise(valor_real = sum(valor_real, na.rm = TRUE), .groups = "drop")

message("Funções distintas encontradas: ", n_distinct(funcoes$id_conta_bd), " (esperado: 28)")

# ------------------------------------------------------------------------------
# 3) Grupos (variáveis dependentes) e despesa total
#    Regra para valores ausentes (ver CLAUDE.md, "Ausência ≠ zero"):
#    - dentro de um grupo, soma as funções que o município informou;
#      se nenhuma função do grupo aparece, o grupo fica vazio (NA), não zero.
#    - despesa total = soma das 28 funções informadas.
# ------------------------------------------------------------------------------
soma_grupo <- function(codigos) {
  funcoes |>
    filter(id_conta_bd %in% codigos) |>
    group_by(ano, id_municipio) |>
    summarise(valor = sum(valor_real, na.rm = TRUE), .groups = "drop")
}

dependentes <- funcoes |>
  group_by(ano, id_municipio) |>
  summarise(despesa_total = sum(valor_real, na.rm = TRUE), .groups = "drop")

for (g in names(GRUPOS)) {
  dependentes <- dependentes |>
    left_join(soma_grupo(GRUPOS[[g]]) |> rename(!!g := valor), by = c("ano", "id_municipio"))
}

# ------------------------------------------------------------------------------
# 4) Atributos do município-ano (repetidos em todas as linhas de conta)
# ------------------------------------------------------------------------------
atributos <- painel |>
  select(all_of(COLUNAS_MUNICIPIO_ANO)) |>
  distinct()

repetidos <- sum(duplicated(atributos[, c("ano", "id_municipio")]))
if (repetidos > 0) stop("Há ", repetidos, " município-anos com atributos diferentes entre linhas. Conferir o painel.")

base <- dependentes |> left_join(atributos, by = c("ano", "id_municipio"))
rm(painel, funcoes); invisible(gc())

# ------------------------------------------------------------------------------
# 5) Per capita, participações, dummies de tempo e transformações
# ------------------------------------------------------------------------------
todas_dep <- c("despesa_total", names(GRUPOS))

base <- base |>
  mutate(
    # Per capita (R$ de 2025 por habitante)
    across(all_of(todas_dep), ~ .x / populacao, .names = "{.col}_pc"),
    # Participação de cada grupo na despesa total (%), para robustez
    across(all_of(names(GRUPOS)), ~ 100 * .x / despesa_total, .names = "{.col}_part"),
    # Calendário eleitoral
    ano_eleitoral = as.integer(ano %in% ANOS_ELEITORAIS),
    pre_eleitoral = as.integer(ano %in% ANOS_PRE_ELEITORAIS),
    # Tendências (2013 = 1), como Sakurai (2009)
    tendencia  = ano - 2012,
    tendencia2 = tendencia^2,
    # Controles transformados
    ln_populacao     = log(populacao),
    pib_nacional_tri = pib_nacional_real / 1e12,                       # R$ trilhões
    ln_pib_mun_pc    = log(ifelse(pib_real > 0, pib_real / populacao, NA))  # só até 2023
  )

# Log das dependentes per capita (zero ou negativo vira NA)
# (o NA é colocado antes do log, para não gerar o aviso "NaNs produced")
for (v in todas_dep) {
  pc <- base[[paste0(v, "_pc")]]
  base[[paste0("ln_", v, "_pc")]] <- log(ifelse(pc > 0, pc, NA))
}

# ------------------------------------------------------------------------------
# 6) Conferências e salvamento
# ------------------------------------------------------------------------------
message("\nBase de regressão: ", format(nrow(base), big.mark = ".", decimal.mark = ","), " município-anos, ",
        n_distinct(base$id_municipio), " municípios")
message("Município-anos por ano:")
print(table(base$ano))

message("\nValores vazios por variável dependente per capita (%):")
vazios <- sapply(paste0(DEPENDENTES, "_pc"), function(v) round(100 * mean(is.na(base[[v]])), 1))
print(vazios)

message("\nMunicípio-anos com valor zero e com valor negativo, por variável dependente:")
print(data.frame(
  variavel = DEPENDENTES,
  zero     = sapply(DEPENDENTES, function(v) sum(base[[v]] == 0, na.rm = TRUE)),
  negativo = sapply(DEPENDENTES, function(v) sum(base[[v]] < 0, na.rm = TRUE)),
  row.names = NULL
))

message("\nValores vazios nas explicativas (%):")
print(sapply(c(INTERESSE, CONTROLES), function(v) round(100 * mean(is.na(base[[v]])), 1)))

saveRDS(base, BASE_REGRESSAO)
message("\nSalvo: ", BASE_REGRESSAO)
