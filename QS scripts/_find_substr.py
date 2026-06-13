# -*- coding: utf-8 -*-
import zipfile
from pathlib import Path

DOCX = Path(__file__).resolve().parent / "1-1天津大学本科生毕业论文模板.docx"


def main() -> None:
    with zipfile.ZipFile(DOCX, "r") as z:
        xml = z.read("word/document.xml").decode("utf-8")
    for needle in ["资源", "消费者", "耦合可写为"]:
        print(needle, xml.find(needle))


if __name__ == "__main__":
    main()
