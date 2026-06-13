# -*- coding: utf-8 -*-
import re
import zipfile
from pathlib import Path

DOCX = Path(__file__).resolve().parent / "1-1天津大学本科生毕业论文模板.docx"
ANCHOR = "资源—消费者耦合可写为"
OUT = Path(__file__).resolve().parent / "_omml_good_ref.xml"


def main() -> None:
    with zipfile.ZipFile(DOCX, "r") as z:
        xml = z.read("word/document.xml").decode("utf-8")
    idx = xml.find(ANCHOR)
    sub = xml[idx : idx + 12000]
    m = re.search(r"<m:oMathPara\b.*?</m:oMathPara>", sub, re.DOTALL)
    if not m:
        raise SystemExit("not found")
    OUT.write_text(m.group(0), encoding="utf-8")
    print("wrote", OUT, "len", len(m.group(0)))


if __name__ == "__main__":
    main()
