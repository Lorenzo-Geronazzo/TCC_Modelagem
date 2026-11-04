# ==============================================================================
# 02b_proporcoes_politicas.R — estatísticas descritivas das variáveis políticas
#                              binárias (tabela para o LaTeX)
# ==============================================================================
# Mesmo formato da tabela das explicativas (tab:descritivas). Base limpa
# (carrega_base()), a mesma daquela tabela. Para as coalizões, há também uma
# sublinha por mandato do governador e do presidente, porque o texto usa essa
# variação entre governos. O N fica só com os município-anos com a variável
# preenchida (os vazios são os município-anos sem prefeito definido no ano).
#
# Saída (regressao/saidas/tabelas/):
#   proporcoes_politicas.tex — tabela LaTeX (ambiente table) para o capítulo de
#                              Metodologia; copiar para TCC_latex/tabelas/
source(here::here("regressao", "00_configuracao.R"))
base <- carrega_base()

# Anos de cada mandato de governador e presidente (eleições de 2010, 2014, 2018 e 2022)
MANDATOS <- list("2013--2014" = 2013:2014, "2015--2018" = 2015:2018,
                 "2019--2022" = 2019:2022, "2023--2025" = 2023:2025)

# ------------------------------------------------------------------------------
# 1) Estatísticas: uma linha por variável e uma sublinha por mandato nas coalizões
# ------------------------------------------------------------------------------
estatisticas <- function(rotulo, x) {
  data.frame(rotulo = rotulo, n = sum(!is.na(x)), media = mean(x, na.rm = TRUE),
             dp = sd(x, na.rm = TRUE), minimo = min(x, na.rm = TRUE), maximo = max(x, na.rm = TRUE))
}

# Linha da coalizão seguida das sublinhas, com o rótulo recuado
com_mandatos <- function(rotulo, v) {
  sublinhas <- lapply(names(MANDATOS), function(m) {
    estatisticas(paste0("\\hspace{1em}", m), base[[v]][base$ano %in% MANDATOS[[m]]])
  })
  rbind(estatisticas(rotulo, base[[v]]), do.call(rbind, sublinhas))
}

tab <- rbind(
  estatisticas("Ano eleitoral", base$ano_eleitoral),
  estatisticas("Ano pré-eleitoral", base$pre_eleitoral),
  estatisticas("Pandemia (2020)", base$pandemia_2020),
  com_mandatos("Coalizão governador", "coalizao_gov"),
  com_mandatos("Coalizão presidente", "coalizao_pres"),
  estatisticas("Segundo mandato", base$segundo_mandato)
)
print(tab, digits = 4, row.names = FALSE)

# ------------------------------------------------------------------------------
# 2) Tabela LaTeX (vírgula decimal, 3 casas; ponto de milhar no N)
# ------------------------------------------------------------------------------
linhas <- paste0(
  tab$rotulo, " & ",
  format(tab$n, big.mark = ".", decimal.mark = ",", trim = TRUE), " & ",
  num_virgula(tab$media, 3), " & ",
  num_virgula(tab$dp, 3), " & ",
  num_virgula(tab$minimo, 3), " & ",
  num_virgula(tab$maximo, 3), " \\\\"
)

tex <- c(
  "% Gerado por regressao/02b_proporcoes_politicas.R (projeto Modelagem). Não editar à mão.",
  "\\begin{table}[htbp]",
  "\\caption{Estatísticas descritivas das variáveis políticas binárias (2013--2025)}\\label{tab:politicas}",
  "\\centering",
  "\\footnotesize",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\begin{tabular}{lrrrrr}",
  "\\hline",
  # mesmo formato da tabela das explicativas (tab:descritivas)
  "\\textbf{Variável} & \\textbf{N} & \\textbf{Média} & \\textbf{D. padrão} & \\textbf{Mínimo} & \\textbf{Máximo} \\\\ \\hline",
  linhas,
  "\\hline",
  "\\end{tabular}",
  "\\fonte{Elaboração própria com dados do TSE.}",
  "\\nota{Para variáveis binárias, a média é a proporção de município-anos com valor 1; o N exclui os município-anos sem prefeito definido no ano.}",
  "\\end{table}"
)

arquivo <- file.path(PASTA_TABELAS, "proporcoes_politicas.tex")
con <- file(arquivo, open = "w", encoding = "UTF-8")
writeLines(tex, con)
close(con)
message("Tabela LaTeX salva: ", arquivo)
