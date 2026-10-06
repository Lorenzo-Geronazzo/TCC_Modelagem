# ==============================================================================
# rodar_tudo.R — roda a análise inteira, na ordem
# ==============================================================================
# Abra o projeto pelo TCC_Modelagem.Rproj e rode este arquivo (botão "Source"),
# ou rode cada script separadamente, na mesma ordem.

# O pacote here é usado para achar os arquivos antes de o 00_configuracao.R
# instalar os demais pacotes; por isso é instalado aqui, se faltar.
if (!requireNamespace("here", quietly = TRUE)) install.packages("here", repos = "https://cloud.r-project.org")

source(here::here("regressao", "01_base_regressao.R"))
source(here::here("regressao", "01b_cobertura.R"))
source(here::here("regressao", "02_descritivas.R"))
source(here::here("regressao", "02b_proporcoes_politicas.R"))
source(here::here("regressao", "03_hausman.R"))
source(here::here("regressao", "04_regressoes.R"))
source(here::here("regressao", "05_robustez.R"))
