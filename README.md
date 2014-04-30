## About

This is a fork of http://www.vim.org/scripts/script.php?script_id=2368

## Description:
Plugin generates symbol dependency tree (aka call tree, call graph) in real-time inside Vim. Basic support for functions and macros; global variables, enums, typedefs can be cross-reference with additional processing. Functionality similar to that of tools and IDE's like CBrowser, Kscope, Source navigator, Eclipse, Source Insight. [Project details/Screenshots](http://sites.google.com/site/vimcctree/). Requires cscope to generate a cscope database; the complementary utility ccglue can be used to convert cscope databases to native cctree databases for instant loading.

## Complementary tools
* [ccglue](http://sourceforge.net/projects/ccglue/) Generate cross-reference cctree database files from cscope and/or ctags database files.

##Features

* Symbol dependency tree analyzer for C using cscope database
* Basic support for functions, and macros
* Extended support for global variables, macros, enum members, typedefs, and also symbols cscope might not detect.
* Native Vim 7 plugin
* Supports using external tools, or perl interpreter to overcome VimScript memory limitations for loading large databases
* Leverages Vim features and Integrates into typical programming work-flow
* Dynamic syntax highlighting for real-time dependency tree flow (customizable)
* Cscope like default short-cuts (customizable)
* Folding support
* Preview/Tag loading
* Manipulate call-tree windows
* Save buffers
* Export to HTML with syntax highlighting (with +conceal)
* Serialization of cross-reference tables
* Similar to Vim's session feature, CCTree can save the built cross-references into a file for reloading any time later
* Can be complemented with native tools [ccglue] for faster cross-reference building in larger projects

## Supported languages: 
* [C](http://en.wikipedia.org/wiki/C_(programming_language)) 

## Requirements:
* [Cscope](http://cscope.sourceforge.net/)
* [Vim 7.xx](http://www.vim.org/) 


## Vim installation
To use with [vundle](https://github.com/gmarik/Vundle.vim) (recommended) simply add:

```vim
Plugin 'hari-rangarajan/CCTree' 
```

in your .vimrc
