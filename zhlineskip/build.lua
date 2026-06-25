module       = "zhlineskip"

unpackfiles  = {module .. ".dtx"}
installfiles = {module .. ".sty", module .. ".ins"}

stdengine    = "pdftex"
checkengines = {"pdftex"}
checkruns    = 1

dofile("../support/build-config.lua")
