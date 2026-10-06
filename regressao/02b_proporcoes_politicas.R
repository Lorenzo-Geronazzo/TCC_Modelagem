# ==============================================================================
# 02b_proporcoes_politicas.R — proporção de município-anos com prefeito alinhado
#                              e em segundo mandato, por ano (tabela para o LaTeX)
# ==============================================================================
# Para as dummies políticas, média e desvio-padrão dizem pouco; o que interessa é
# a proporção de municípios com valor 1 em cada ano. Base limpa (carrega_base()).
# Percentuais calculados sobre os município-anos com a variável preenchida
# (os vazios, como os 49 municípios sem prefeito em 2025, ficam fora da conta).
#
# Saída (regressao/saidas/tabelas/):
#   proporcoes_politicas.tex — tabela LaTeX (ambiente table) para o capítulo de
#                              Metodologia; copiar para TCC_latex/tabelas/
source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()

# ------------------------------------------------------------------------------
# 1) Proporções por ano
# ------------------------------------------------------------------------------
# % de 1 entre os valores não vazios
perc_um <- function(x) 100 * mean(x == 1, na.rm = TRUE)

tab <- base |>
  group_by(ano) |>
  summarise(municipios = n(),
            gov        = perc_um(coalizao_gov),
            pres       = perc_um(coalizao_pres),
            segundo    = perc_um(segundo_mandato),
            .groups = "drop") |>
  arrange(ano)
print(tab)

# ------------------------------------------------------------------------------
# 2) Tabela LaTeX (vírgula decimal, uma casa; ponto de milhar no nº de municípios)
# ------------------------------------------------------------------------------
linhas <- paste0(
  tab$ano, " & ",
  format(tab$municipios, big.mark = ".", decimal.mark = ","), " & ",
  num_virgula(tab$gov, 1), " & ",
  num_virgula(tab$pres, 1), " & ",
  num_virgula(tab$segundo, 1), " \\\\"
)

tex <- c(
  "% Gerado por regressao/02b_proporcoes_politicas.R (projeto Modelagem). Não editar à mão.",
  "\\begin{table}[htbp]",
  "\\caption{Proporção de município-anos com prefeito alinhado e em segundo mandato, por ano (\\%)}\\label{tab:politicas}",
  "\\centering",
  "\\footnotesize",
  "\\begin{tabular}{lrrrr}",
  "\\hline",
  # cabeçalho em duas linhas, para a tabela caber na largura do texto
  " & & \\textbf{Coalizão com} & \\textbf{Coalizão com} & \\textbf{Segundo} \\\\",
  "\\textbf{Ano} & \\textbf{Municípios} & \\textbf{o governador} & \\textbf{o presidente} & \\textbf{mandato} \\\\ \\hline",
  linhas,
  "\\hline",
  "\\end{tabular}",
  "\\fonte{Elaboração própria com dados do TSE.}",
  "\\end{table}"
)

arquivo <- file.path(PASTA_TABELAS, "proporcoes_politicas.tex")
con <- file(arquivo, open = "w", encoding = "UTF-8")
writeLines(tex, con)
close(con)
message("Tabela LaTeX salva: ", arquivo)
