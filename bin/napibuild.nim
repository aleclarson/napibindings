import json, docopt, os


const doc = """
NapiBuild.
Usage:
  napibuild <projectfile> [options]

Options:
  -C          do not recompile projectfile
  -r          release build
"""
let args = docopt(doc)

var
  projectfile = $args["<projectfile>"]
  project = splitFile(projectfile)
  nimbase = getEnv("HOME") & "/.choosenim/toolchains/nim-1.4.8/lib"
  nimcache = project.dir / "nimcache"#$args["<nimcache>"]

var
  bindingPath = project.dir / "binding.gyp"
  bindingExists = fileExists bindingPath
  target =
    if bindingExists: parseJson readFile bindingPath
    else: %* { "target_name": project.name }
  gyp = %* { "targets": [target] }

echo "binding exists: " & bindingExists.repr

template assess(name: string, cmd: string) =
  var status = execShellCmd(cmd)
  doAssert status == 0, "exit with nonzero status: " & $status & " for command " & cmd


if not args["-C"]:
  var releaseFlag = if args["-r"]: "-d:release " else: "--embedsrc "
  assess "nim c", "nim c --nimcache:" & nimcache & " " & releaseFlag & "--compileOnly --noMain " & projectfile


target["cflags"] = %["-w"]
if args["-r"]:
  target["cflags"].add(%"-O3")
  target["cflags"].add(%"-fno-strict-aliasing")

if not bindingExists:
  target["include_dirs"] = %[ nimbase ]
  target["linkflags"] = %["-ldl"]


var compiledpf = (projectfile).changeFileExt(".c")

target["sources"] = %[]
for targetobj in parsejson(readfile(nimcache / (project.name & ".json")))["link"]:
  target["sources"].add(% ("nimcache" / targetobj.getstr.splitFile.name))


writeFile(bindingPath, gyp.pretty)


var gypflags = "--directory=" & project.dir
if not args["-r"]: gypflags.add(" --debug")

assess "node-gyp", "node-gyp rebuild "  & gypflags
