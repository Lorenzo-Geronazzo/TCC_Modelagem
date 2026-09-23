# Modelagem

Pipeline de construcao do painel municipal com dados do SICONFI, TSE, IBGE e Censo.

## Execução

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python main_code.py
```

O script consulta a Base dos Dados quando os arquivos locais não existem e gera
`painel_final_eleicoes.parquet`. As bases Parquet são ignoradas pelo Git porque
sao arquivos derivados e podem ser recriadas pelo pipeline.

## Testes

```powershell
pytest
```
