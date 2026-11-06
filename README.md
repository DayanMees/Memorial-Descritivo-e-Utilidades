# Agente de Relatórios

Aplicação Streamlit que recebe uma planilha XLSX e gera:

- `RELATORIO_FINAL.docx`: uma página por registro;
- `RELATORIO_DESCIDAS.xlsx`: relatório de legendas com as abas `TRANSPORTADORES`, `COMANDO` e `RAMAL DE ALIMENTAÇÃO`;
- um ZIP contendo os resultados gerados;
- o DWG com as tabelas inseridas, quando um desenho é enviado e o aplicativo roda em um computador com ZWCAD;
- `PACOTE_DESCIDAS_ZWCAD.zip`: dados das tabelas e um comando AutoLISP para inseri-las no desenho aberto no ZWCAD.

## Segurança

A aplicação executa apenas a rotina fixa existente em `processor.py`. Ela não utiliza `exec()` e não executa código enviado por usuários.

## Executar no computador

```bash
python -m venv .venv
```

Ative o ambiente virtual e instale as dependências:

```bash
pip install -r requirements.txt
streamlit run app.py
```

No Windows, depois de instalar o `uv`, basta abrir `Abrir Agente de Relatorios.bat`.

## Publicar gratuitamente no Streamlit Community Cloud

1. Crie um repositório no GitHub.
2. Envie todos os arquivos desta pasta ao repositório.
3. Acesse o Streamlit Community Cloud e conecte sua conta do GitHub.
4. Selecione o repositório, a branch principal e o arquivo `app.py`.
5. Clique em **Deploy**.

A aplicação receberá um endereço `streamlit.app` que poderá ser compartilhado.
Nesse endereço, o aplicativo não tem acesso ao ZWCAD de quem o utiliza: as tabelas
são inseridas pela forma manual descrita abaixo.

## Inserir as tabelas no ZWCAD

Há duas formas de inserir as tabelas. Nas duas, a legenda e as tabelas são
posicionadas a partir do ponto clicado, que corresponde ao canto superior
esquerdo do conjunto. As tabelas são criadas como tabelas nativas do ZWCAD,
em Calibri, e podem ser editadas diretamente no desenho.

**Automática (aplicativo executado com `streamlit run app.py` no computador com
ZWCAD):** envie também o DWG e clique em `Gerar relatórios`. O ZWCAD abre uma cópia do desenho; se aparecer o
aviso de referências não resolvidas, escolha ignorar e continuar. Clique no
ponto de inserção. A altura do texto é calculada pelo tamanho do desenho, e a
cópia é salva e fechada automaticamente, ficando disponível para download.
Se o ZWCAD não for encontrado, defina a variável de ambiente `ZWCAD_PATH`.

**Manual (aplicativo hospedado ou sem ZWCAD):** baixe
`PACOTE_DESCIDAS_ZWCAD.zip` e extraia os arquivos. No ZWCAD, abra o DWG de
destino, use `APPLOAD` para carregar `INSERIR_DESCIDAS.lsp` e execute o comando
`INSERIR_DESCIDAS`. Selecione `RELATORIO_DESCIDAS_CAD.tsv`, clique no ponto de
inserção e aceite a altura de texto sugerida ou informe outra. O botão do pacote
aparece quando há descidas e o DWG não foi gerado automaticamente.

Cada execução insere um novo conjunto; tabelas de execuções anteriores não são
removidas. Na forma manual, salve o resultado como um novo DWG para preservar o
desenho original.

## Estrutura

```text
agente_relatorios/
├── app.py
├── processor.py
├── cad.py
├── Abrir Agente de Relatorios.bat
├── INSERIR_DESCIDAS.lsp
├── requirements.txt
├── supabase_schema.sql
├── .gitignore
├── .streamlit/
│   ├── config.toml
│   └── secrets.toml.example
└── README.md
```

## Supabase

O arquivo `supabase_schema.sql` contém uma tabela inicial para histórico de execuções. A integração foi deixada desativada no MVP para evitar armazenamento de dados antes de configurar autenticação e políticas de segurança.

## Regras preservadas do código original

- a primeira aba do arquivo enviado é usada como base;
- linhas totalmente vazias são removidas;
- o Word mantém uma página por registro;
- registros com `POS` contendo `WF` vão para `RAMAL DE ALIMENTAÇÃO`;
- registros com `WM` preenchido, exceto `WF`, vão para `TRANSPORTADORES`;
- registros de `WC`, `WN`, `WS` ou com campos de comando preenchidos vão para `COMANDO`;
- a coluna artificial `DESCIDA` foi removida; cada aba usa o identificador real do equipamento (`WM`, `WC`/`WN`/`WS` ou `WF`).
