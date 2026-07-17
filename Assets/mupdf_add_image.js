import mupdf from "mupdf"

var document = mupdf.Document.openDocument(scriptArgs[0])
var page = document.loadPage(Number(scriptArgs[2]))
var annotation = page.createAnnotation("Stamp")
var x = Number(scriptArgs[3])
var y = Number(scriptArgs[4])
var width = Number(scriptArgs[5])
var height = Number(scriptArgs[6])
annotation.setRect([x, y, x + width, y + height])
annotation.setStampImage(new mupdf.Image(scriptArgs[1]))
annotation.update()
page.update()
document.save(scriptArgs[7], "compress,garbage=3")
