import json, docopt, os, system


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
  nimcache = project.dir / "nimcache"#$args["<nimcache>"]

var
  bindingPath = project.dir / "binding.gyp"
  bindingExists = fileExists bindingPath

var gyp: JsonNode
var target: JsonNode
if bindingExists:
  gyp = parseJson readFile bindingPath
  target = gyp["targets"][0]
else:
  target = %* { "target_name": project.name }
  gyp = %* { "targets": [target] }

template assess(name: string, cmd: string) =
  var status = execShellCmd(cmd)
  doAssert status == 0, "exit with nonzero status: " & $status & " for command " & cmd


if not args["-C"]:
  var releaseFlag = if args["-r"]: "-d:release " else: "--embedsrc "
  assess "nim c", "nim c --nimcache:" & nimcache & " " & releaseFlag & "--compileOnly --noMain " & projectfile


proc contains_string(node: JsonNode, str: string): bool =
  for elem in node.elems:
    if elem.kind == JString and elem.str == str:
      return true

proc add_flag(node: JsonNode, flag: string) =
  if not node.contains_string flag:
    node.add %flag

var cflags = target["cflags"]
if cflags == nil:
  cflags = %[]
  target["cflags"] = cflags

cflags.add_flag "-w"
if args["-r"]:
  cflags.add_flag "-O3"
  cflags.add_flag "-fno-strict-aliasing"

let nimVersionTag =
  if (system.NimMinor mod 2) == 0: system.NimVersion
  else: "#devel"

if not bindingExists:
  target["include_dirs"] = %["$$HOME/.choosenim/toolchains/nim-" & nimVersionTag & "/lib"]
  target["linkflags"] = %["-ldl"]


var compiledpf = (projectfile).changeFileExt(".c")

target["sources"] = %[]
for targetobj in parsejson(readfile(nimcache / (project.name & ".json")))["link"]:
  target["sources"].add(% ("nimcache" / targetobj.getstr.splitFile.name))


writeFile(bindingPath, gyp.pretty)


var gypflags = "--directory=" & project.dir
if not args["-r"]: gypflags.add(" --debug")

assess "node-gyp", "node-gyp rebuild "  & gypflags
