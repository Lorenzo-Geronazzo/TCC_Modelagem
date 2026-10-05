# ==============================================================================
# 01b_cobertura.R — tabela de cobertura das funções de despesa (decisão sobre zeros)
# ==============================================================================
# Pergunta: quantos municípios informam cada função em todos os anos, em parte
# dos anos ou em nenhum? Serve para decidir o que fazer com as ausências
# (CLAUDE.md, "A VER DEPOIS", item 1: ausência não é zero).
#
# Entrada: dados/finais/painel_final_real.parquet
# Saída:   regressao/saidas/tabelas/cobertura_funcoes.csv/.docx
#          regressao/saidas/tabelas/cobertura_grupos.csv/.docx
#          regressao/saidas/tabelas/cobertura_por_ano.csv
#
# Definições (por município):
#   anos_siconfi = nº de anos em que o município aparece no Siconfi (qualquer função)
#   anos_com_valor = nº de anos em que a função aparece com valor > 0
#   "Todos os anos"  : anos_com_valor == anos_siconfi
#   "Parte dos anos" : 0 < anos_com_valor < anos_siconfi
#   "Nenhum ano"     : anos_com_valor == 0
#   "Com buraco"     : dentro de "Parte dos anos", informa, deixa de informar e
#                      volta a informar (é o caso que gera variação artificial no
#                      efeito fixo)
# Linhas com valor exatamente 0 são contadas à parte (o município lançou a conta
# com zero, o que é diferente de não lançar).
source(here::here("regressao", "00_configuracao.R"))

# ------------------------------------------------------------------------------
# 1) Leitura: só as linhas de função (3.FF.000), sem o total 3.00.000
# ------------------------------------------------------------------------------
painel <- arrow::read_parquet(PAINEL_FINAL_REAL,
                              col_select = all_of(c("ano", "id_municipio", "id_conta_bd", "valor_real")))
funcoes <- painel |>
  mutate(id_municipio = as.character(id_municipio), ano = as.integer(ano)) |>
  filter(grepl("^3\\.\\d\\d\\.000$", id_conta_bd), id_conta_bd != "3.00.000") |>
  group_by(ano, id_municipio, id_conta_bd) |>
  summarise(valor_real = sum(valor_real, na.rm = TRUE), .groups = "drop")
rm(painel); invisible(gc())

# Anos em que cada município aparece no Siconfi
anos_siconfi <- funcoes |>
  distinct(id_municipio, ano) |>
  count(id_municipio, name = "anos_siconfi")

# ------------------------------------------------------------------------------
# 2) Função de classificação (serve para função isolada e para grupo)
#    'valores' tem uma linha por município-ano em que a conta aparece
# ------------------------------------------------------------------------------
classifica <- function(valores) {
  por_mun <- valores |>
    filter(valor > 0) |>
    group_by(id_municipio) |>
    summarise(anos_com_valor = n(),
              # buraco: entre o 1º e o último ano informado falta algum ano
              com_buraco = (max(ano) - min(ano) + 1) > n(),
              .groups = "drop")
  anos_siconfi |>
    left_join(por_mun, by = "id_municipio") |>
    mutate(anos_com_valor = ifelse(is.na(anos_com_valor), 0L, anos_com_valor),
           com_buraco = ifelse(is.na(com_buraco), FALSE, com_buraco),
           classe = case_when(anos_com_valor == anos_siconfi ~ "todos",
                              anos_com_valor == 0            ~ "nenhum",
                              TRUE                           ~ "parte"))
}

resume <- function(cl, valores, nome) {
  data.frame(
    "Conta"                     = nome,
    "Todos os anos"             = sum(cl$classe == "todos"),
    "Parte dos anos"            = sum(cl$classe == "parte"),
    "Parte: com buraco"         = sum(cl$classe == "parte" & cl$com_buraco),
    "Nenhum ano"                = sum(cl$classe == "nenhum"),
    "Linhas com valor zero"     = sum(valores$valor == 0),
    "Média de municípios/ano"   = round(nrow(filter(valores, valor > 0)) / n_distinct(funcoes$ano)),
    check.names = FALSE
  )
}

# ------------------------------------------------------------------------------
# 3) Cobertura de cada função usada nas variáveis dependentes
# ------------------------------------------------------------------------------
codigos <- unique(unlist(GRUPOS))
tab_funcoes <- do.call(rbind, lapply(sort(codigos), function(cod) {
  v <- funcoes |> filter(id_conta_bd == cod) |> select(ano, id_municipio, valor = valor_real)
  resume(classifica(v), v, cod)
}))

# ------------------------------------------------------------------------------
# 4) Cobertura dos grupos (mesma regra do 01: soma das funções informadas)
# ------------------------------------------------------------------------------
tab_grupos <- do.call(rbind, lapply(names(GRUPOS), function(g) {
  v <- funcoes |>
    filter(id_conta_bd %in% GRUPOS[[g]]) |>
    group_by(ano, id_municipio) |>
    summarise(valor = sum(valor_real), .groups = "drop")
  resume(classifica(v), v, g)
}))

# ------------------------------------------------------------------------------
# 5) Nº de municípios com valor > 0, por ano e função (para ver tendência)
# ------------------------------------------------------------------------------
tab_ano <- funcoes |>
  filter(id_conta_bd %in% codigos, valor_real > 0) |>
  count(ano, id_conta_bd) |>
  tidyr::pivot_wider(names_from = id_conta_bd, values_from = n) |>
  arrange(ano)
total_ano <- anos_siconfi |> nrow()

# ------------------------------------------------------------------------------
# 6) Resultados
# ------------------------------------------------------------------------------
message("Municípios no Siconfi (algum ano): ", total_ano)
message("Municípios presentes nos 13 anos: ", sum(anos_siconfi$anos_siconfi == 13))
message("\nCobertura por função:"); print(tab_funcoes, row.names = FALSE)
message("\nCobertura por grupo:");  print(tab_grupos, row.names = FALSE)
message("\nMunicípios com valor > 0, por ano:"); print(as.data.frame(tab_ano), row.names = FALSE)

salva_tabela(tab_funcoes, "cobertura_funcoes")
salva_tabela(tab_grupos, "cobertura_grupos")
write.csv2(tab_ano, file.path(PASTA_TABELAS, "cobertura_por_ano.csv"), row.names = FALSE,
           fileEncoding = "UTF-8")
message("Tabela salva: cobertura_por_ano (.csv)")
