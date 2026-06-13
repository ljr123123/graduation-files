# -*- coding: utf-8 -*-
import re
import zipfile
from pathlib import Path

DOCX = Path(__file__).resolve().parent / "1-1天津大学本科生毕业论文模板.docx"
OUT = Path(__file__).resolve().parent / "_omml_snippets.xml"


def main() -> None:
    with zipfile.ZipFile(DOCX, "r") as z:
        xml = z.read("word/document.xml").decode("utf-8")
    a1 = "并考虑对微生物的维持消耗或产率系数"
    a2 = "并同时以相同速率洗出菌体与底物时，常写为"
    i1, i2 = xml.find(a1), xml.find(a2)
    chunks = []
    for name, idx in [("after_anchor1", i1), ("after_anchor2", i2)]:
        if idx == -1:
            chunks.append(f"<!-- missing {name} -->\n")
            continue
        sub = xml[idx : idx + 15000]
        blocks = list(re.finditer(r"<m:oMathPara\b.*?</m:oMathPara>", sub, re.DOTALL))
        chunks.append(f"<!-- {name} idx={idx} first_omath_offset={blocks[0].start() if blocks else -1} -->\n")
        if blocks:
            chunks.append(sub[blocks[0].start() : blocks[0].end()])
            chunks.append("\n\n")
    OUT.write_text("".join(chunks), encoding="utf-8")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
