from __future__ import annotations

from io import BytesIO
from pathlib import Path
import zipfile

import streamlit as st

from cad import (
    ZwcadError,
    gerar_pacote_zwcad,
    inserir_tabelas_no_dwg,
    localizar_zwcad,
)
from processor import processar_documento


MAX_FILE_SIZE_MB = 50
MAX_DWG_SIZE_MB = 200
DOCX_MIME = (
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
)
XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

st.set_page_config(
    page_title="Agente de Relatórios",
    page_icon="📄",
    layout="centered",
)

st.title("Agente de Relatórios")
st.write(
    "Envie a planilha-base (XLSX) e, opcionalmente, o desenho em DWG. "
    "A aplicação gera o memorial em Word, o relatório de descidas em Excel "
    "e insere as tabelas no desenho, na posição que você escolher."
)

uploaded_file = st.file_uploader(
    "Planilha-base (XLSX)",
    type=["xlsx"],
    accept_multiple_files=False,
)
uploaded_dwg = st.file_uploader(
    "Desenho (DWG do ZWCAD)",
    type=["dwg"],
    accept_multiple_files=False,
)

zwcad_disponivel = localizar_zwcad() is not None

if uploaded_dwg is not None and not zwcad_disponivel:
    st.warning(
        "O ZWCAD não foi encontrado neste computador, então o DWG não será "
        "alterado. Execute o aplicativo no computador com ZWCAD instalado "
        "(ou defina ZWCAD_PATH), ou baixe o pacote do ZWCAD após gerar os "
        "relatórios e insira as tabelas manualmente."
    )

if uploaded_file is not None:
    file_size_mb = uploaded_file.size / (1024 * 1024)
    st.caption(f"Planilha: {uploaded_file.name} — {file_size_mb:.2f} MB")

    dwg_too_large = (
        uploaded_dwg is not None
        and uploaded_dwg.size / (1024 * 1024) > MAX_DWG_SIZE_MB
    )

    if file_size_mb > MAX_FILE_SIZE_MB:
        st.error(
            f"A planilha excede o limite de {MAX_FILE_SIZE_MB} MB definido "
            "para esta primeira versão."
        )
    elif dwg_too_large:
        st.error(f"O DWG excede o limite de {MAX_DWG_SIZE_MB} MB.")
    elif st.button("Gerar relatórios", type="primary", use_container_width=True):
        result = None
        with st.spinner("Processando a planilha..."):
            try:
                result = processar_documento(uploaded_file.getvalue())
            except ValueError as exc:
                st.error(str(exc))
            except Exception:
                st.exception(
                    RuntimeError(
                        "Ocorreu um erro inesperado durante o processamento."
                    )
                )

        if result is not None:
            dwg_result: bytes | None = None
            tem_descidas = (
                result.total_transportadores
                + result.total_comando
                + result.total_ramal
            ) > 0
            if uploaded_dwg is not None and zwcad_disponivel and tem_descidas:
                st.info(
                    "O ZWCAD será aberto no desenho. Se aparecer o aviso de "
                    "referências não resolvidas, escolha ignorar e continuar. "
                    "Depois, clique no ponto do canto superior esquerdo onde "
                    "as tabelas devem ser inseridas; o desenho será salvo e "
                    "fechado automaticamente."
                )
                with st.spinner("Aguardando a seleção do ponto no ZWCAD..."):
                    try:
                        dwg_result = inserir_tabelas_no_dwg(
                            uploaded_dwg.getvalue(),
                            result.cad_tsv,
                        )
                    except ZwcadError as exc:
                        st.error(str(exc))
                    except Exception:
                        st.exception(
                            RuntimeError(
                                "Ocorreu um erro inesperado ao inserir as "
                                "tabelas no DWG."
                            )
                        )

            if uploaded_dwg is None or dwg_result is not None:
                st.success("Relatórios gerados com sucesso.")
            elif not tem_descidas:
                st.warning(
                    "O Word e o Excel foram gerados, mas a planilha não tem "
                    "descidas para inserir; o DWG não foi alterado."
                )
            else:
                st.warning(
                    "O Word e o Excel foram gerados, mas as tabelas não foram "
                    "inseridas no DWG."
                )

            metric_1, metric_2, metric_3, metric_4 = st.columns(4)
            metric_1.metric("Registros", result.total_registros)
            metric_2.metric("Transportadores", result.total_transportadores)
            metric_3.metric("Comando", result.total_comando)
            metric_4.metric("Ramal", result.total_ramal)

            for warning in result.avisos:
                st.warning(warning)

            dwg_name = (
                Path(uploaded_dwg.name).stem + "_DESCIDAS.dwg"
                if uploaded_dwg is not None
                else ""
            )

            zip_buffer = BytesIO()
            with zipfile.ZipFile(
                zip_buffer,
                mode="w",
                compression=zipfile.ZIP_DEFLATED,
            ) as archive:
                archive.writestr("RELATORIO_FINAL.docx", result.docx)
                archive.writestr("RELATORIO_DESCIDAS.xlsx", result.xlsx)
                if dwg_result is not None:
                    archive.writestr(dwg_name, dwg_result)

            if dwg_result is not None:
                st.download_button(
                    "Baixar desenho DWG com as descidas",
                    data=dwg_result,
                    file_name=dwg_name,
                    mime="application/acad",
                    use_container_width=True,
                    on_click="ignore",
                )
            st.download_button(
                "Baixar relatório Excel",
                data=result.xlsx,
                file_name="RELATORIO_DESCIDAS.xlsx",
                mime=XLSX_MIME,
                use_container_width=True,
                on_click="ignore",
            )
            st.download_button(
                "Baixar relatório Word",
                data=result.docx,
                file_name="RELATORIO_FINAL.docx",
                mime=DOCX_MIME,
                use_container_width=True,
                on_click="ignore",
            )
            st.download_button(
                "Baixar todos os arquivos em ZIP",
                data=zip_buffer.getvalue(),
                file_name="RELATORIOS_GERADOS.zip",
                mime="application/zip",
                use_container_width=True,
                on_click="ignore",
            )
            if dwg_result is None and tem_descidas:
                st.download_button(
                    "Baixar pacote para inserção manual no ZWCAD",
                    data=gerar_pacote_zwcad(result.cad_tsv),
                    file_name="PACOTE_DESCIDAS_ZWCAD.zip",
                    mime="application/zip",
                    use_container_width=True,
                    on_click="ignore",
                )

st.divider()
st.caption(
    "Esta versão executa somente a rotina aprovada do projeto. Ela não "
    "executa código enviado pelos usuários."
)
