"""Genera documento-final.pdf a partir de documento-final.html.

Uso:  python documento/generar-pdf.py

Imprime el HTML a PDF con Microsoft Edge o Google Chrome en modo headless.
Solo usa la biblioteca estandar de Python.
"""

import shutil
import subprocess
import sys
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
ORIGEN = CARPETA / "documento-final.html"
DESTINO = CARPETA / "documento-final.pdf"

NAVEGADORES = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "msedge",
    "google-chrome",
    "chromium",
]


def buscar_navegador():
    for candidato in NAVEGADORES:
        ruta = shutil.which(candidato) or (candidato if Path(candidato).exists() else None)
        if ruta:
            return ruta
    sys.exit("No se encontro Edge ni Chrome para imprimir el PDF.")


def main():
    subprocess.run(
        [
            buscar_navegador(),
            "--headless",
            "--disable-gpu",
            "--no-pdf-header-footer",
            "--print-to-pdf-no-header",
            f"--print-to-pdf={DESTINO}",
            ORIGEN.as_uri(),
        ],
        check=True,
        capture_output=True,
        timeout=120,
    )
    print(f"PDF generado: {DESTINO}")


if __name__ == "__main__":
    main()
