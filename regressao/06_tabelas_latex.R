# ==============================================================================
# 06_tabelas_latex.R — tabelas de resultados em LaTeX, a partir dos CSVs
# ==============================================================================
# NÃO reestima nada: lê os .csv que o 04 e o 05 salvaram em regressao/saidas/tabelas/
# e escreve um .tex para cada um, no estilo da Tabela 2 de Sakurai (2009):
# página em paisagem, grupos de despesa nas colunas, variáveis nas linhas,
# erro-padrão entre parênteses embaixo do coeficiente, estrelas, e Observações,
# Municípios e R² no fim. Nos testes com os dois modelos, as linhas marcadas com
# "[modelo A]" e "[modelo B]" no .csv viram dois blocos ("painéis") na tabela.
#
# Saídas (regressao/saidas/tabelas/latex/):
#   regressao_principal_A.tex, regressao_principal_B.tex
#   robustez_R1.tex ... robustez_R16.tex e robustez_R7a.tex
#   robustez_resumo.tex — ano eleitoral e pré-eleitoral no modelo principal, R5, R12 e R14
# Copiar para TCC_latex/tabelas/resultados/.
source(here::here("regressao", "00_configuracao.R"))

# ------------------------------------------------------------------------------
# 1) Títulos e notas (os mesmos textos dos .docx gerados pelo 04 e pelo 05;
#    se mudar um título ou nota lá, mudar aqui também)
# ------------------------------------------------------------------------------
NOTA_DEP <- "Variáveis dependentes: despesa per capita por grupo de funções (R$ de 2025)."
NOTA_DK  <- "Erros-padrão de Driscoll-Kraay entre parênteses. *** p<0,01; ** p<0,05; * p<0,1."

TABELAS <- list(
  regressao_principal_A = list(
    titulo = "Resultados do modelo A (ciclo eleitoral) – efeitos fixos de município",
    nota = paste(NOTA_DEP, NOTA_A, "Os coeficientes de coalizão são apresentados para completude;",
                 "a análise das coalizões usa o modelo B.")),
  regressao_principal_B = list(
    titulo = "Resultados do modelo B (coalizões) – efeitos fixos de município e de ano",
    nota = paste(NOTA_DEP, NOTA_B))
)

# Testes de robustez: código, título (como no 05_robustez.R) e nota
TESTES <- list(
  R1  = list("coalizões sem fusões de partidos"),
  R2  = list("sem prefeitos/governadores de eleição suplementar"),
  R3  = list("variável dependente em log"),
  R4  = list("participação na despesa total (%)"),
  R5  = list("especificação de Sakurai (sem pré-eleitoral e sem pandemia, erro agrupado)",
             paste("Só modelo A: efeito fixo de município, sem ano pré-eleitoral e sem pandemia.", NOTA_EP)),
  R6  = list("inclui prefeito em segundo mandato"),
  R7  = list("PIB municipal per capita (2013-2023)"),
  R7a = list("especificação principal na amostra 2013-2023"),
  R8  = list("Assistência e Previdência somadas (Sakurai, 2009)"),
  R9  = list("só municípios que informam a função em todos os anos"),
  R10 = list("sem limpeza (outliers de despesa e receita original)"),
  R11 = list("dependentes winsorizadas nos percentis 1 e 99 de cada ano"),
  R12 = list("modelo A com erro-padrão agrupado por município",
             paste("Só modelo A: efeito fixo de município.", NOTA_EP)),
  R13 = list("modelo B com erro-padrão de Driscoll-Kraay",
             paste("Só modelo B: efeitos fixos de município e de ano.", NOTA_DK)),
  R14 = list("modelo A sem a dummy de pandemia",
             paste("Só modelo A: efeito fixo de município, sem a dummy de pandemia.", NOTA_DK)),
  R15 = list("sem as variáveis do Censo (jovens, idosos, urbanização)"),
  R16 = list("ano eleitoral e pré-eleitoral separados por eleição (modelo A)",
             paste("Só modelo A: efeito fixo de município; ano eleitoral e pré-eleitoral",
                   "separados por eleição (2020 absorvido pela dummy de pandemia).", NOTA_DK))
)
for (codigo in names(TESTES)) {
  t <- TESTES[[codigo]]
  TABELAS[[paste0("robustez_", codigo)]] <- list(
    titulo = paste0("Robustez ", codigo, " — ", t[[1]]),
    nota   = if (length(t) > 1) t[[2]] else NOTA_AB)
}

PAINEIS <- c(A = "Modelo A (ciclo eleitoral)", B = "Modelo B (coalizões)")
RODAPE  <- c("Observações", "Municípios", "R²")

# ------------------------------------------------------------------------------
# 2) Funções auxiliares
# ------------------------------------------------------------------------------
# Escapa os caracteres especiais do LaTeX em texto comum
escapa <- function(x) {
  x <- gsub("%", "\\%", x, fixed = TRUE)
  x <- gsub("&", "\\&", x, fixed = TRUE)
  x <- gsub("_", "\\_", x, fixed = TRUE)
  x <- gsub("$", "\\$", x, fixed = TRUE)
  x <- gsub("²", "\\textsuperscript{2}", x, fixed = TRUE)
  x
}

# Nota: texto escapado, com as estrelas em sobrescrito e "<" em modo matemático
escapa_nota <- function(x) {
  x <- escapa(x)
  x <- gsub("(\\*+) p<", "\\\\textsuperscript{\\1}p$<$", x)
  x
}

# Célula numérica: sinal de menos como $-$ e estrelas em sobrescrito
formata_celula <- function(x) {
  x <- sub("^-", "$-$", x)
  x <- sub("(\\*+)$", "\\\\textsuperscript{\\1}", x)
  x
}

le_csv <- function(nome) {
  read.csv2(file.path(PASTA_TABELAS, paste0(nome, ".csv")), colClasses = "character",
            check.names = FALSE, fileEncoding = "UTF-8", na.strings = character(0))
}

# Uma linha da tabela: rótulo & célula & célula ... \\
linha_tex <- function(rotulo, celulas) {
  paste0(paste(c(escapa(rotulo), formata_celula(celulas)), collapse = " & "), " \\\\")
}

# Largura aproximada (em pt) de uma célula na fonte da tabela (Helvetica,
# \footnotesize = 10pt): algarismos, vírgula/ponto, parênteses, sinal de menos
# ($-$) e estrelas em sobrescrito. Serve para dimensionar as colunas.
largura_celula <- function(x) {
  algarismos <- nchar(gsub("[^0-9]", "", x))
  pontuacao  <- nchar(gsub("[^,.]", "", x))
  parenteses <- nchar(gsub("[^()]", "", x))
  estrelas   <- nchar(gsub("[^*]", "", x))
  negativo   <- grepl("^-", x)
  5.56 * algarismos + 2.78 * pontuacao + 3.33 * parenteses + 2.87 * estrelas + 7.78 * negativo
}

# Rótulos longos (mais de 24 caracteres) são quebrados em duas partes, numa
# palavra perto do meio: a 2ª parte vai na linha do erro-padrão, que não tem
# rótulo. Assim a tabela não fica mais alta. Devolve c(parte 1, parte 2).
quebra_rotulo <- function(r) {
  if (nchar(r) <= 24 || !grepl(" ", r)) return(c(r, ""))
  palavras <- strsplit(r, " ")[[1]]
  k <- seq_len(length(palavras) - 1)                 # quebra depois da palavra k
  tam1 <- vapply(k, function(i) nchar(paste(palavras[1:i], collapse = " ")), numeric(1))
  i <- k[which.min(abs(tam1 - (nchar(r) - tam1 - 1)))]
  c(paste(palavras[1:i], collapse = " "), paste(palavras[-(1:i)], collapse = " "))
}

# Especificação das colunas. Cada coluna de números tem a largura da sua maior
# célula (mínimo de 60pt, para palavras do cabeçalho como "Saneamento" não
# quebrarem); a 1ª coluna (variáveis) fica com o resto da largura da página.
# Com poucas colunas, a tabela não ocupa a página inteira: 1ª coluna com 25%
# e números com 72pt.
# celulas: data frame só com as colunas de números (texto, como no .csv)
espec_colunas <- function(celulas) {
  n <- ncol(celulas)
  larguras <- vapply(celulas, function(col) max(largura_celula(col)), numeric(1))
  if (n >= 6) {
    larguras <- pmax(60, ceiling(larguras + 1))
    primeira <- sprintf("\\dimexpr\\linewidth-%dpt\\relax", sum(larguras) + 6 * n)
  } else {
    larguras <- pmax(72, ceiling(larguras + 2))
    primeira <- "0.25\\linewidth"
  }
  paste0("@{}>{\\raggedright\\arraybackslash}p{", primeira, "}",
         paste0(">{\\centering\\arraybackslash}p{", larguras, "pt}", collapse = ""), "@{}")
}

# Monta o ambiente completo (paisagem + table + tabular).
# Tabelas longas (o modelo A) têm as linhas um pouco mais juntas, para caber na página.
monta_tabela <- function(nome, titulo, celulas, corpo, nota_tex) {
  colunas <- names(celulas)
  c("% Gerado por regressao/06_tabelas_latex.R (projeto Modelagem). Não editar à mão.",
    "\\begin{landscape}",
    "\\begin{table}[htbp]",
    sprintf("\\caption{%s}\\label{tab:%s}", escapa(titulo), nome),
    "\\centering",
    "\\footnotesize",
    "\\setlength{\\tabcolsep}{3pt}",
    if (length(corpo) > 25) "\\renewcommand{\\arraystretch}{0.9}",
    sprintf("\\begin{tabular}{%s}", espec_colunas(celulas)),
    "\\hline",
    # \hspace{0pt} deixa o LaTeX hifenizar a 1ª palavra do cabeçalho, se ela não couber
    paste0(paste(c("\\textbf{Variável}", paste0("\\textbf{\\hspace{0pt}", escapa(colunas), "}")),
                 collapse = " & "), " \\\\ \\hline"),
    corpo,
    "\\hline",
    "\\end{tabular}",
    "\\fonte{Elaboração própria.}",
    sprintf("\\nota{%s}", nota_tex),
    "\\end{table}",
    "\\end{landscape}")
}

salva_tex <- function(linhas, nome) {
  con <- file(file.path(PASTA_TAB_LATEX, paste0(nome, ".tex")), open = "w", encoding = "UTF-8")
  writeLines(linhas, con)
  close(con)
  message("Tabela LaTeX salva: ", nome, ".tex")
}

# ------------------------------------------------------------------------------
# 3) Uma tabela .tex para cada .csv
# ------------------------------------------------------------------------------
converte <- function(nome, titulo, nota) {
  tab <- le_csv(nome)
  rotulos <- tab[["Variável"]]
  colunas <- names(tab)[-1]

  # Modelo de cada linha: "[modelo A]" / "[modelo B]" no rótulo; a linha do
  # erro-padrão (rótulo vazio) herda o modelo da linha de cima
  modelo <- sub("^.*\\[modelo ([AB])\\]$", "\\1", rotulos)
  modelo[!grepl("\\[modelo [AB]\\]$", rotulos)] <- NA
  for (i in seq_along(modelo)) if (is.na(modelo[i]) && i > 1 && rotulos[i] == "") modelo[i] <- modelo[i - 1]
  rotulos <- sub(" \\[modelo [AB]\\]$", "", rotulos)
  # rótulo longo: a 2ª parte passa para a linha do erro-padrão (logo abaixo)
  for (i in seq_len(length(rotulos) - 1)) {
    if (rotulos[i] != "" && rotulos[i + 1] == "") {
      partes <- quebra_rotulo(rotulos[i])
      rotulos[i] <- partes[1]
      rotulos[i + 1] <- partes[2]
    }
  }
  com_paineis <- any(!is.na(modelo))
  if (!com_paineis) modelo[] <- "-"

  corpo <- character(0)
  blocos <- unique(modelo)
  for (b in blocos) {
    linhas_b <- which(modelo == b)
    if (com_paineis) {
      # espaço antes do 2º painel; título do painel em itálico
      if (b != blocos[1]) corpo[length(corpo)] <- paste0(corpo[length(corpo)], "[6pt]")
      corpo <- c(corpo, sprintf("\\multicolumn{%d}{@{}l}{\\textit{%s}} \\\\", length(colunas) + 1, PAINEIS[b]))
    }
    for (i in linhas_b) {
      if (rotulos[i] == RODAPE[1]) corpo <- c(corpo, "\\hline")
      corpo <- c(corpo, linha_tex(rotulos[i], unlist(tab[i, -1])))
    }
  }
  salva_tex(monta_tabela(nome, titulo, tab[-1], corpo, escapa_nota(nota)), nome)
}

for (nome in names(TABELAS)) converte(nome, TABELAS[[nome]]$titulo, TABELAS[[nome]]$nota)

# ------------------------------------------------------------------------------
# 4) Tabela-resumo da robustez do ciclo eleitoral (modelo A)
#    Blocos: modelo principal, R5 (Sakurai), R12 (erro agrupado), R14 (sem pandemia)
# ------------------------------------------------------------------------------
# Devolve as duas linhas (coeficiente e erro-padrão) de uma variável num .csv,
# só com as colunas de números
pega_linhas <- function(nome, rotulo) {
  tab <- le_csv(nome)
  i <- match(rotulo, tab[["Variável"]])
  if (is.na(i)) stop("Linha '", rotulo, "' não encontrada em ", nome, ".csv")
  tab[c(i, i + 1), -1]
}

colunas_resumo <- names(le_csv("regressao_principal_A"))[-1]
for (nome in c("robustez_R5", "robustez_R12", "robustez_R14")) {
  stopifnot(identical(names(le_csv(nome))[-1], colunas_resumo))   # mesmas colunas, mesma ordem
}

BLOCOS_RESUMO <- list(
  list("Modelo principal (erro de Driscoll-Kraay)", "regressao_principal_A", ""),
  list("R5: especificação de Sakurai (2009) (erro agrupado por município)", "robustez_R5", " [modelo A]"),
  list("R12: erro-padrão agrupado por município", "robustez_R12", " [modelo A]"),
  list("R14: sem a dummy de pandemia (erro de Driscoll-Kraay)", "robustez_R14", " [modelo A]")
)
corpo <- character(0)
celulas_resumo <- NULL   # todas as células usadas (para a largura das colunas)
for (k in seq_along(BLOCOS_RESUMO)) {
  bl <- BLOCOS_RESUMO[[k]]
  if (k > 1) corpo[length(corpo)] <- paste0(corpo[length(corpo)], "[6pt]")
  corpo <- c(corpo, sprintf("\\multicolumn{%d}{@{}l}{\\textit{%s}} \\\\",
                            length(colunas_resumo) + 1, escapa(bl[[1]])))
  variaveis <- c("Ano eleitoral", "Ano pré-eleitoral")
  if (bl[[2]] == "robustez_R5") variaveis <- "Ano eleitoral"   # o R5 não tem ano pré-eleitoral
  for (v in variaveis) {
    duas <- pega_linhas(bl[[2]], paste0(v, bl[[3]]))
    corpo <- c(corpo, linha_tex(v, unlist(duas[1, ])), linha_tex("", unlist(duas[2, ])))
    celulas_resumo <- rbind(celulas_resumo, duas)
  }
}
nota_resumo <- paste(
  "Coeficientes do modelo A (efeito fixo de município), em R\\$ de 2025 per capita.",
  "Modelo principal e R14: erros-padrão de Driscoll-Kraay;",
  "R5 e R12: erros-padrão agrupados por município.",
  "O R5 segue \\textcite{sakurai2009}: sem ano pré-eleitoral e sem dummy de pandemia;",
  "o R14 retira só a dummy de pandemia, e 2020 volta a contar como ano eleitoral.",
  "Erros-padrão entre parênteses. \\textsuperscript{***}p$<$0,01; \\textsuperscript{**}p$<$0,05; \\textsuperscript{*}p$<$0,1.")
salva_tex(monta_tabela("robustez_resumo",
                       "Robustez do ciclo eleitoral: modelo principal e testes selecionados",
                       celulas_resumo, corpo, nota_resumo),
          "robustez_resumo")
