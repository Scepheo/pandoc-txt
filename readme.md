# pandoc-txt

A custom writer for [pandoc](https://pandoc.org/), that transforms your
beautiful documents into plain old text files.

## Usage

To use this, make sure pandoc is installed and download [txt.lua](src/txt.lua).
Then, from the folder containing txt.lua, run:

```bash
pandoc <input file> -t txt.lua
```

Pipe the output to wherever you want it.
