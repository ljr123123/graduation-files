# -*- coding: utf-8 -*-
"""Inspect/fix OMML equations in thesis template (resource-consumer + chemostat)."""
import re
import shutil
import zipfile
from pathlib import Path

DOCX = Path(__file__).resolve().parent / "1-1天津大学本科生毕业论文模板.docx"
NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
}


def main() -> None:
    if not DOCX.is_file():
        raise SystemExit(f"Missing: {DOCX}")

    backup = DOCX.with_suffix(".docx.bak_formulas")
    shutil.copy2(DOCX, backup)
    print("Backup:", backup)

    with zipfile.ZipFile(DOCX, "r") as zin:
        xml = zin.read("word/document.xml").decode("utf-8")

    # OMML for two equation systems (Word-native). m:oMathPara contains display math.
    # Equation 1: resource-consumer
    omml1 = r"""<m:oMathPara xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><m:oMath><m:d><m:dPr><m:begChr m:val="{"/><m:endChr m:val="}"/><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:m><m:mPr><m:baseJc m:val="center"/><m:plcHide m:val="on"/><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:mPr><m:mr><m:e><m:f><m:fPr><m:type m:val="bar"/></m:fPr><m:num><m:r><m:t>dN</m:t></m:r></m:num><m:den><m:r><m:t>dt</m:t></m:r></m:den></m:f><m:r><m:t>=</m:t></m:r><m:r><m:t>μ</m:t></m:r><m:d><m:dPr><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:r><m:t>S</m:t></m:r></m:e></m:d><m:r><m:t>N</m:t></m:r></m:e></m:mr><m:mr><m:e><m:f><m:fPr><m:type m:val="bar"/></m:fPr><m:num><m:r><m:t>dS</m:t></m:r></m:num><m:den><m:r><m:t>dt</m:t></m:r></m:den></m:f><m:r><m:t>=−</m:t></m:r><m:f><m:fPr><m:type m:val="bar"/></m:fPr><m:num><m:r><m:t>1</m:t></m:r></m:num><m:den><m:r><m:t>Y</m:t></m:r></m:den></m:f><m:r><m:t>μ</m:t></m:r><m:d><m:dPr><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:r><m:t>S</m:t></m:r></m:e></m:d><m:r><m:t>N</m:t></m:r></m:e></m:mr></m:m></m:e></m:d></m:oMath></m:oMathPara>"""

    # Equation 2: chemostat
    omml2 = r"""<m:oMathPara xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><m:oMath><m:d><m:dPr><m:begChr m:val="{"/><m:endChr m:val="}"/><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:m><m:mPr><m:baseJc m:val="center"/><m:plcHide m:val="on"/><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:mPr><m:mr><m:e><m:f><m:fPr><m:type m:val="bar"/></m:fPr><m:num><m:r><m:t>dN</m:t></m:r></m:num><m:den><m:r><m:t>dt</m:t></m:r></m:den></m:f><m:r><m:t>=</m:t></m:r><m:d><m:dPr><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:r><m:t>μ</m:t></m:r><m:d><m:dPr><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:r><m:t>S</m:t></m:r></m:e></m:d><m:r><m:t>−D</m:t></m:r></m:e></m:d><m:r><m:t>N</m:t></m:r></m:e></m:mr><m:mr><m:e><m:f><m:fPr><m:type m:val="bar"/></m:fPr><m:num><m:r><m:t>dS</m:t></m:r></m:num><m:den><m:r><m:t>dt</m:t></m:r></m:den></m:f><m:r><m:t>=D</m:t></m:r><m:d><m:dPr><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:r><m:t>S</m:t></m:r><m:sSub><m:e><m:r><m:t>S</m:t></m:r></m:e><m:sub><m:r><m:t>0</m:t></m:r></m:sub></m:sSub><m:r><m:t>−S</m:t></m:r></m:e></m:d><m:r><m:t>−</m:t></m:r><m:f><m:fPr><m:type m:val="bar"/></m:fPr><m:num><m:r><m:t>1</m:t></m:r></m:num><m:den><m:r><m:t>Y</m:t></m:r></m:den></m:f><m:r><m:t>μ</m:t></m:r><m:d><m:dPr><m:ctrlPr><w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr></m:ctrlPr></m:dPr><m:e><m:r><m:t>S</m:t></m:r></m:e></m:d><m:r><m:t>N</m:t></m:r></m:e></m:mr></m:m></m:e></m:d></m:oMath></m:oMathPara>"""

    # Strip duplicate default xmlns on inner fragments (document already has m: prefix declarations)
    def strip_xmlns_m(s: str) -> str:
        return s.replace(' xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"', "", 1)

    omml1 = strip_xmlns_m(omml1)
    omml2 = strip_xmlns_m(omml2)

    # Build minimal w:p containing only display OMML (Word accepts w:r with m:oMath inside in some builds;
    # standard is w:r/m:oMath inside paragraph)
    def wrap_para(inner_omml: str) -> str:
        return (
            "<w:p>"
            "<w:pPr><w:jc w:val=\"center\"/></w:pPr>"
            "<w:r><w:rPr><w:rFonts w:ascii=\"Cambria Math\" w:hAnsi=\"Cambria Math\"/></w:rPr>"
            f"{inner_omml}"
            "</w:r>"
            "</w:p>"
        )

    p1 = wrap_para(omml1.replace("<m:oMathPara", "<m:oMathPara", 1).replace("<m:oMathPara", "<m:oMathPara", 1))
    # Actually inner_omml should be oMathPara content only inside run - Word often uses:
    # <w:r><m:oMath>...</m:oMath></w:r> for inline; display uses m:oMathPara as sibling of w:r.
    # Correct structure: <w:p>...<m:oMathPara>...</m:oMathPara></w:p>
    p1 = (
        "<w:p xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
        "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\">"
        "<w:pPr><w:jc w:val=\"center\"/></w:pPr>"
        f"{omml1}"
        "</w:p>"
    )
    p2 = (
        "<w:p xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
        "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\">"
        "<w:pPr><w:jc w:val=\"center\"/></w:pPr>"
        f"{omml2}"
        "</w:p>"
    )

    # Remove broken oMathParas that sit between markers (Chinese anchors)
    anchor1 = "并考虑对微生物的维持消耗或产率系数"
    anchor2 = "并同时以相同速率洗出菌体与底物时，常写为"
    i1 = xml.find(anchor1)
    i2 = xml.find(anchor2)
    if i1 == -1 or i2 == -1:
        raise SystemExit("Anchors not found in document.xml")

    def remove_omath_after(idx: int, window: int = 8000) -> tuple[str, bool]:
        chunk = xml[idx : idx + window]
        start = chunk.find("<m:oMathPara")
        if start == -1:
            return xml, False
        start_abs = idx + start
        end_tag = "</m:oMathPara>"
        end = xml.find(end_tag, start_abs)
        if end == -1:
            return xml, False
        end_abs = end + len(end_tag)
        # Remove wrapping w:p if this oMathPara is sole content
        before = xml[max(0, start_abs - 120) : start_abs]
        new_xml = xml[:start_abs] + xml[end_abs:]
        return new_xml, True

    new_xml = xml
    # First broken block: after anchor1, remove first oMathPara in following paragraph
    sub = new_xml[i1 : i1 + 12000]
    m_start = sub.find("<m:oMathPara")
    if m_start == -1:
        # try remove entire empty w:p with only drawing/image
        print("No oMathPara after anchor1; trying w:p with w:drawing only...")
    else:
        new_xml, ok = remove_omath_after(i1)
        print("Removed oMath after anchor1:", ok)
        if ok:
            # insert replacement paragraph right after anchor1's closing </w:t></w:r></w:p> is hard.
            # Simpler: insert p1 immediately after the paragraph that contains anchor1 ends.
            pass

    # More reliable: regex replace first two oMathPara blocks in body that are between our anchors
    parts = new_xml.split(anchor1, 1)
    if len(parts) != 2:
        raise SystemExit("split anchor1 failed")
    head, tail = parts[0], parts[1]
    # Find first <m:oMathPara ... </m:oMathPara> in tail and replace
    m = re.search(r"<m:oMathPara\b.*?</m:oMathPara>", tail, re.DOTALL)
    if not m:
        raise SystemExit("No first oMathPara after anchor1")
    tail = tail[: m.start()] + omml1 + tail[m.end() :]
    new_xml = head + anchor1 + tail

    parts = new_xml.split(anchor2, 1)
    if len(parts) != 2:
        raise SystemExit("split anchor2 failed")
    head, tail = parts[0], parts[1]
    m = re.search(r"<m:oMathPara\b.*?</m:oMathPara>", tail, re.DOTALL)
    if not m:
        raise SystemExit("No second oMathPara after anchor2")
    tail = tail[: m.start()] + omml2 + tail[m.end() :]
    new_xml = head + anchor2 + tail

    # Ensure document root still has namespace declarations (unchanged)
    out_bytes = new_xml.encode("utf-8")
    tmp = DOCX.with_suffix(".docx.tmp")
    shutil.copy2(DOCX, tmp)
    with zipfile.ZipFile(tmp, "r") as zin, zipfile.ZipFile(DOCX, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "word/document.xml":
                data = out_bytes
            zout.writestr(item, data)
    tmp.unlink(missing_ok=True)
    print("Patched:", DOCX)


if __name__ == "__main__":
    main()
