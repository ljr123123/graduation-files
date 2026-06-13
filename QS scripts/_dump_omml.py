# -*- coding: utf-8 -*-
import re
import zipfile
from pathlib import Path

DOCX = Path(__file__).resolve().parent / "1-1天津大学本科生毕业论文模板.docx"


def main() -> None:
    with zipfile.ZipFile(DOCX, "r") as z:
        xml = z.read("word/document.xml").decode("utf-8")
    blocks = re.findall(r"<m:oMathPara\b.*?</m:oMathPara>", xml, re.DOTALL)
    print("count", len(blocks))
    for i, b in enumerate(blocks[:15]):
        print("---", i, "len", len(b))
        print(b[:800])
        print()


if __name__ == "__main__":
    main()
