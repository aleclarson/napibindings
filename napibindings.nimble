version  = "0.1.0"
author  = "andrew breidenbach"
description  = "bindings for node api"
license  = "MIT"
skipDirs  = @["test", ".git"]
bin  = @["../bin/napibuild"]
binDir  = "../bin"
srcDir  = "src"

requires "https://github.com/docopt/docopt.nim#master"
