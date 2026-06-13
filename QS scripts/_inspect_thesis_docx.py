# -*- coding: utf-8 -*-
from pathlib import Path
import docx

here = Path(__file__).resolve().parent
path = list(here.glob("1-1*.docx"))[0]
d = docx.Document(str(path))
for i in range(11, 18):
    p = d.paragraphs[i]
    print("===", i, repr(p.text))
    for r in p.runs:
        print("  run:", repr(r.text), "tab" if "\t" in r.text else "")
