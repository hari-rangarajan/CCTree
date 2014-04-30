## About

This is a fork of http://www.vim.org/scripts/script.php?script_id=2368

## Description:
This plugin generates symbol dependency tree (aka call tree, call graph) in real-time inside Vim using a Cscope database. Basic support for functions and macros; global variables, enums, typedefs can be cross-reference with additional processing. Functionality similar to that of tools and IDE's like CBrowser, Kscope, Source navigator, Eclipse, Source Insight. [Project details/Screenshots](http://sites.google.com/site/vimcctree/) 

## Supported languages: 
* [C](http://en.wikipedia.org/wiki/C_(programming_language)) 

## Requirements:
* [Cscope](http://cscope.sourceforge.net/)
* [Vim 7.xx](http://www.vim.org/) 

## Complementary tools
* [ccglue](http://sourceforge.net/projects/ccglue/) Generate cross-reference cctree database files from cscope and/or ctags database files.

## Vim installation
To use with [vundle](https://github.com/gmarik/Vundle.vim) (recommended) simply add:

```vim
Plugin 'hari-rangarajan/CCTree' 
```

in your .vimrc
