from __future__ import annotations

from io import BytesIO
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

LISP_PATH = Path(__file__).with_name("INSERIR_DESCIDAS.lsp")


class ZwcadError(Exception):
    pass


def localizar_zwcad() -> Path | None:
    configured = os.environ.get("ZWCAD_PATH")
    if configured and Path(configured).is_file():
        return Path(configured)

    for base in (
        os.environ.get("ProgramFiles", r"C:\Program Files"),
        os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
    ):
        vendor = Path(base) / "ZWSOFT"
        if not vendor.is_dir():
            continue
        candidates = sorted(vendor.glob("ZWCAD*/ZWCAD.exe"), reverse=True)
        if candidates:
            return candidates[0]
    return None


def _lisp_path(path: Path) -> str:
    return str(path).replace("\\", "/")


def gerar_pacote_zwcad(cad_tsv: bytes) -> bytes:
    output = BytesIO()
    with zipfile.ZipFile(
        output,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
    ) as archive:
        archive.writestr("RELATORIO_DESCIDAS_CAD.tsv", cad_tsv)
        archive.write(LISP_PATH, arcname=LISP_PATH.name)
    return output.getvalue()


def inserir_tabelas_no_dwg(
    dwg_bytes: bytes,
    cad_tsv: bytes,
    *,
    timeout_seconds: int = 900,
) -> bytes:
    zwcad = localizar_zwcad()
    if zwcad is None:
        raise ZwcadError(
            "O ZWCAD não foi encontrado neste computador. Defina a variável "
            "de ambiente ZWCAD_PATH com o caminho do ZWCAD.exe."
        )

    with tempfile.TemporaryDirectory(
        prefix="descidas_",
        ignore_cleanup_errors=True,
    ) as folder:
        work = Path(folder)
        dwg_path = work / "desenho.dwg"
        tsv_path = work / "dados.tsv"
        done_path = work / "concluido.txt"
        script_path = work / "executar.scr"

        dwg_path.write_bytes(dwg_bytes)
        tsv_path.write_bytes(cad_tsv)
        script = (
            "CMDECHO 0\n"
            f'(load "{_lisp_path(LISP_PATH)}")\n'
            f'(md:interativo "{_lisp_path(tsv_path)}" '
            f'"{_lisp_path(done_path)}")\n'
        )
        try:
            script_path.write_bytes(script.encode("cp1252"))
        except UnicodeEncodeError as exc:
            raise ZwcadError(
                "O caminho da pasta do aplicativo ou da pasta temporária "
                "contém caracteres que o ZWCAD não consegue ler."
            ) from exc

        process = subprocess.Popen(
            [str(zwcad), str(dwg_path), "/b", str(script_path)],
        )
        try:
            process.wait(timeout=timeout_seconds)
        except subprocess.TimeoutExpired as exc:
            process.kill()
            process.wait()
            if not done_path.exists():
                raise ZwcadError(
                    "Tempo esgotado aguardando a seleção do ponto no ZWCAD."
                ) from exc

        if not done_path.exists():
            raise ZwcadError(
                "As tabelas não foram inseridas: nenhum ponto foi selecionado, "
                "o ZWCAD foi fechado antes da conclusão ou o desenho não pôde "
                "ser salvo."
            )

        return dwg_path.read_bytes()
