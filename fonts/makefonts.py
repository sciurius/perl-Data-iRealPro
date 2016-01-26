#!/usr/bin/python

import fontforge
import sys
import os
import struct
import psMat

src = fontforge.open("Myriad-CnSemibold.ttf")

src.fontname = "Myriad-UcnSemibold"
src.fullname = "Myriad Ultra-Condensed Semibold"
src.copyright = "As free as Myriad-CnSemibold."
src.version = "001.200"
src.em = 1024;

cnd = psMat.scale(0.7,1)
src.selection.all()
for glyph in src.selection.byGlyphs:
   glyph.transform(cnd)
src.generate("Myriad-UcnSemibold.ttf")

src = fontforge.open("FreeSans.ttf")

src.fontname = "FreeSansCn"
src.fullname = "Free Sans Condensed"
src.copyright = "As free as Free Sans."
src.version = "001.200"
src.em = 1024;

cnd = psMat.scale(0.7,1)
src.selection.all()
for glyph in src.selection.byGlyphs:
   glyph.transform(cnd)
src.generate("FreeSansCn.ttf")

src = fontforge.open("Bravura.otf")
src.generate("Bravura.ttf")

src.fontname = "BravuraCn"
src.fullname = "Bravura Condensed"
src.copyright = "As free as Bravura."
src.version = "001.200"
src.em = 1024;

cnd = psMat.scale(0.7,1)
src.selection.all()
for glyph in src.selection.byGlyphs:
   glyph.transform(cnd)
src.generate("BravuraCn.ttf")
