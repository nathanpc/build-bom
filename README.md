# build-bom

A simple Perl script to build BOMs from schematic files.


## Screenshots

Some screenshots of the program running:

![A little example](http://screencloud.net/img/screenshots/3fd4c504d70fd7133e1ad97c85b27b79.png)

![An example showing the extended view](http://screencloud.net/img/screenshots/3cf883e87e9a75f21541a1b28857c79f.png)


## File Support

build-bom supports the following packages:

  - [EAGLE](http://www.cadsoftusa.com/)
  - [KiCAD](http://www.kicad-pcb.org/)

If you want your package to be added, please [open a Issue](https://github.com/nathanpc/build-bom/issues/new) providing the package name, a schematic file, and a PDF (or image) of the schematic. I'll implement support for your CAD package as soon as possible.


## Exporting

With build-bom you can export your BOMs to the following formats:

  - JSON
  - CSV
  - HTML


## Requirements

This script requires the following libraries to be installed in your Perl system, which can be installed by executing `cpan install <package name>`:

  - [XML::LibXML](http://search.cpan.org/dist/XML-LibXML/LibXML.pod)
  - [JSON](http://search.cpan.org/~makamaka/JSON-2.59/lib/JSON.pm)
  - [File::Slurp](http://search.cpan.org/~uri/File-Slurp-9999.19/lib/File/Slurp.pm)
