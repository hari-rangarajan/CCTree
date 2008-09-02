" C Call-Tree Explorer (CCTree) <CCTree.vim>
"
"
" Script Info and Documentation 
"=============================================================================
"    Copyright: Copyright (C) August, 2008 Hari Rangarajan
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               cctree.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damamges
"               resulting from the use of this software.
"
" Name Of File: CCTree.vim
"  Description: C Call-Tree Explorer Vim Plugin
"   Maintainer: Hari Rangarajan <hari.rangarajan@gmail.com>
"          URL: http://vim.sourceforge.net/scripts/script.php?script_id=???
"  Last Change: August 31, 2008
"      Version: 0.1 
"
"=============================================================================
" 
"  Description:
"       Plugin generates call-trees for any function or macro in real-time inside
"  Vim.
"
"  Requirements: 1) Cscope
"                2) Vim 7.xx with optional Perl interface (recommended for faster 
"                   database loads, check :version to see whether [+]perl is 
"                   enabled)
"
"                   To configure perl to be included:
"                   ./configure --with-features=XXXX --enable-perlinterp
"
"                Tested on Unix and the following Win32 versions:
"                + Cscope, mlcscope (WIN32)
"                       http://www.geocities.com/shankara_c/cscope.html
"                       http://www.bell-labs.com/project/wwexptools/packages.html
"
"                + Perl (WIN32)
"                       Active Perl 5.8.8
"                
"
"  Installation: 
"               Copy this file to ~/.vim/plugins/
"               or to /vimfiles/plugins/  (on Win32 platforms) 
" 
"               It might also be possible to load it as a filetype plugin
"               ~/.vim/ftplugin/c/
"
"               Need to set :filetype plugin on 
"           
"
"  Usage:
"           Build cscope database with -c option, for example:
"           > cscope -b -c -i cscope.files
"
"           Load database with command ":CCTreeLoadDB"
"           (Please note that it might take a while depending on the 
"           database size)
"
"           To unload database, use command ":CCTreeUnLoadDB"
"
"           Default Mappings:
"             Get reverse call tree for symbol  <C-\><
"             Get forward call tree for symbol  <C-\>>
"             Increase depth of tree and update <C-\>=
"             Decrease depth of tree and update <C-\>-
"
"             Open symbol in other window       <CR>
"             Preview symbol in other window    <Ctrl-P>
"
"          Command List:
"             CCTreeLoadDB                
"             CCTreeUnLoadDB             
"             CCTreeTraceForward          <symbolname>
"             CCTreeTraceReverse          <symbolname>     
"             CCTreeRecurseDepthPlus     
"             CCTreeRecurseDepthMinus    
"
"
"
"          Settings:
"               Customize behavior by changing the variable settings
"
"               Cscope database file, g:CCTreeCscopeDb = "cscope.out"
"               Maximum call levels,   g:CCTreeRecursiveDepth = 3
"               Maximum visible(unfolded) level, g:CCTreeMinVisibleDepth = 3
"               Orientation of window,  g:CCTreeOrientation = "leftabove"
"                (standard vim options for split: [right|left][above|below])
"             
"  Limitations:
"           The accuracy of the call-tree will only be as good as the cscope 
"           database generation.
"           NOTE: Different flavors of Cscope have some known
"                 limitations due to the lexical analysis engine. This results
"                 in incorrectly identified function blocks, etc.
"
"  History:
"           Version 0.1:
"                Cross-referencing support for only functions and macros
"                Functions inside macro definitions will be incorrectly
"                attributed to the top level calling function
"
"               TODO: Work is in progress on a more complex database
"               cross-ref mechanism that can support symbols, enums, and 
"               global variables.
"
"=============================================================================

if !exists('loaded_cctree') && v:version >= 700
  " First time loading the cctree plugin
  let loaded_cctree = 1
else
   finish 
endif

" Global variables 
" Modify in .vimrc to modify default behavior
let g:CCTreeCscopeDb = "cscope.out"
let g:CCTreeRecursiveDepth = 3
let g:CCTreeMinVisibleDepth = 3
let g:CCTreeOrientation = "leftabove"

" Plugin related local variables
let s:pluginname = 'CCTree'
let s:windowtitle = 'CCTree-Preview'
let s:CCTreekeyword = ''

" Disable perl 
let s:allow_perl = 1


" Other state variables
let s:currentkeyword = ''
let s:currentdirection = ''
let s:dbloaded = 0
let s:symtable = {}
let s:save_statusline = ''
let s:lastbufname = ''

" Turn on/off debugs
let s:tag_debug=0

" Use the Decho plugin for debugging
function! DBGecho(...)
    if s:tag_debug
        Decho(a:000)
    endif
endfunction

function! DBGredir(...)
    if s:tag_debug
        Decho(a:000)
    endif
endfunction


function! s:CCTreeGetIdentifier(line)
    return matchlist(a:line, '^\t\(.\)\(.*\)')
endfunction


function! s:CCTreeSymbolCreate(name, symtable)
    try 
        let retval = a:symtable[a:name]
    catch
        let a:symtable[a:name] = {}
        let retval = a:symtable[a:name]
        let retval['name']= a:name
        let retval['child'] = {}
        let retval['parent'] = {}
    finally
    endtry
    return retval
endfunction

function! s:CCTreeSymbolCalled(funcentry, newfunc)
    if !has_key(a:funcentry['child'], a:newfunc['name'])
        let a:funcentry['child'][a:newfunc['name']] = []
    endif
endfunction

function! s:CCTreeSymbolCallee(funcentry, newfunc)
    if !has_key(a:funcentry['parent'], a:newfunc['name'])
        let a:funcentry['parent'][a:newfunc['name']] = []
    endif
endfunction


function! s:CCTreeInitStatusLine()
    let s:symlastprogress = 0
    let s:symprogress = 0
    let s:cursym = 0
    let s:currentstatus = ''
    let s:statusextra = ''
    
    let s:save_statusline = &statusline
    setlocal statusline=%{CCTreeStatusLine()}
endfunction
        
function! s:CCTreeRestoreStatusLine()
    let &statusline = s:save_statusline
endfunction

function! s:CCTreeBusyStatusLineUpdate(msg)
    let s:currentstatus = a:msg
    redrawstatus
endfunction

function! s:CCTreeBusyStatusLineExtraInfo(msg)
    let s:statusextra = a:msg
    redrawstatus
endfunction

function! CCTreeStatusLine()
    return s:pluginname. " ". s:currentstatus. " -- ". s:statusextra
endfunction

function! s:CCTreeWarningMsg(msg)
    echohl WarningMsg
    echo a:msg
    echohl None
endfunction

if has('perl') && s:allow_perl == 1
function! s:CCTreeLoadDB()
perl << PERL_EOF
    VIM::DoCommand("let curfunc =  {}");
    VIM::DoCommand("let newfunc =  {}");
    VIM::DoCommand("let s:symtable = {}");

    $insidefunc = 0;

    VIM::DoCommand("call s:CCTreeInitStatusLine()");
    VIM::DoCommand("call s:CCTreeBusyStatusLineUpdate('Loading database')");
    open (CSCOPEDB, VIM::Eval("g:CCTreeCscopeDb"));
    my @lines = <CSCOPEDB>;
   
    if ($lines[0] !~ /cscope.*\-c/ ) {
        VIM::DoCommand("call s:CCTreeWarningMsg
                \('Cscope database was not found or built with -c flag')");
        VIM::DoCommand("call s:CCTreeRestoreStatusLine()");
        die;
    }

    $linesmax = @lines;
    $lines1percent = $linesmax/100;
    $linescount = 0;
    $linesprogress = 0;
    
    VIM::DoCommand("call 
                    \s:CCTreeBusyStatusLineUpdate('Reading database')");
    foreach $line (@lines) {
        $_ = $line;
        $linescount += 1;
        if ($linescount > $lines1percent) {
            $linescount = 0;
            $linesprogress += 1;
            VIM::DoCommand("let s:symprogress = ".$linesprogress);
            VIM::DoCommand("call s:CCTreeBusyStatusLineExtraInfo(\"Processing ". 
                    \ $linesprogress. "\%, total ". $linesmax. " items\")");
       }
       ($symchar, $symbol) = /^\t(.)(.*)/;
        if ($symchar =~ /\$/) {
            $insidefunc = 1;
            VIM::DoCommand("let curfunc = 
                        \s:CCTreeSymbolCreate('".$symbol."',s:symtable)");
        } 
        elsif ($symchar =~ /\#/) {
            VIM::DoCommand("call 
                        \s:CCTreeSymbolCreate('".$symbol."',s:symtable)");
        }
        elsif ($symchar =~ /\`/ && $insidefunc == 1) {
            VIM::DoCommand("let newfunc = 
                        \s:CCTreeSymbolCreate('".$symbol."',s:symtable)");
            VIM::DoCommand("call s:CCTreeSymbolCalled(curfunc, newfunc)");
            VIM::DoCommand("call s:CCTreeSymbolCallee(newfunc, curfunc)");
       } 
            elsif ($symchar =~ /\}/) {
            $insidefunc = 0;
       }
    }
    VIM::DoCommand("let &statusline = s:save_statusline");
    VIM::DoCommand("echomsg 'Done building database'");
    
    VIM::DoCommand("let s:dbloaded = 1");
    close(CSCOPEDB);
PERL_EOF
endfunction

    else 

function! s:CCTreeLoadDB()
    let curfunc =  {}
    let newfunc =  {}
    let s:symtable = {}
    let s:dbloaded = 0
 
    call s:CCTreeBusyStatusLineUpdate('Loading database')
    let symbols = readfile(g:CCTreeCscopeDb)
    if empty(symbols)    
        call s:CCTreeWarningMsg("Cscope database not found")
        call s:CCTreeRestoreStatusLine()
        return
    endif

    let s:symcount = len(symbols)
    let s:symcount1percent = s:symcount/100
    let s:symprogress = 0
    let s:symcur = 0
    let symindex = 0
    let symlocalstart = 0
    let symlocalcount = 0

    " Grab previous status line
    call s:CCTreeInitStatusLine()
    
    call s:CCTreeBusyStatusLineUpdate('Reading database')
    " Check if database was built uncompressed
    if symbols[0] !~ "cscope.*\-c"
        call s:CCTreeWarningMsg("Cscope database was not built with -c flag")
        call s:CCTreeRestoreStatusLine()
        return
    endif

    for a in symbols
        let s:symcur += 1
        if s:symcount1percent < s:symcur
            let s:symcur = 0
            let s:symprogress += 1
            call s:CCTreeBusyStatusLineExtraInfo("Processing ". s:symprogress. 
                        \ "\%, total ". s:symcount. " items")
            redrawstatus
        endif

        let s:symlastprogress = s:symprogress

        if a[0] == "\t"
            if a[1] == "`" && curfunc != {}
                let newfunc = s:CCTreeSymbolCreate(a[2:], s:symtable)
                call s:CCTreeSymbolCalled(curfunc, newfunc)
                call s:CCTreeSymbolCallee(newfunc, curfunc)
            elseif a[1] == "$"
                let curfunc = s:CCTreeSymbolCreate(a[2:], s:symtable)
            elseif a[1] == "#"
                call s:CCTreeSymbolCreate(a[2:], s:symtable)
            elseif a[1] == "}"
                let curfunc = {}
            endif
        endif
    endfor

    call s:CCTreeRestoreStatusLine()
    let s:dbloaded = 1
    echomsg "Done building database"
endfunction

endif

function! s:CCTreeUnloadDB()
    unlet s:symtable
    let s:dbloaded = 0
endfunction 


function! s:CCTreeGetCallsForSymbol(symname, depth, direction)
    if (a:depth > g:CCTreeRecursiveDepth) 
        return {}
    endif

    if !has_key(s:symtable, a:symname)
        return {}            
    endif

    let symentry = s:symtable[a:symname]

    let calltree_dict = {}
    let calltree_dict['entry'] = a:symname

    for entry in keys(symentry[a:direction])
        if !has_key(calltree_dict, 'childlinks')
            let calltree_dict['childlinks'] = []
        endif
        let tmpDict = 
                \s:CCTreeGetCallsForSymbol(entry, a:depth+1, a:direction)
        call add(calltree_dict['childlinks'], tmpDict)
    endfor
    return calltree_dict
endfunction

func! s:FindOpenBuffer(filename)
    let bnrList = tabpagebuflist(tabpagenr())

    for bufnrs in bnrList
        if (bufname(bufnrs) == a:filename)
            let newWinnr = bufwinnr(bufnrs)
            exec newWinnr.'wincmd w'
            return 1
        endif
    endfor
    " Could not find the buffer
    return 0
endfunction

function! s:CCTreePreviewWindowLeave()
    call s:FindOpenBuffer(s:lastbufname)
endfunction

function! CCTreePreviewStatusLine()
    let rtitle= s:windowtitle. ' -- '. s:currentkeyword. 
            \'[Depth: '. g:CCTreeRecursiveDepth.','
    
    if s:currentdirection == 'parent' 
        let rtitle .= "(Reverse)"
    else
        let rtitle .= "(Forward)"
    endif

    return rtitle.']'
endfunction

function! s:CCTreePreviewWindowEnter()
    let s:lastbufname = bufname("%")
    if s:FindOpenBuffer(s:windowtitle) == 0
        exec  g:CCTreeOrientation." split ". s:windowtitle
        setlocal buftype=nofile
        setlocal bufhidden=wipe
        setlocal noswapfile
        setlocal nonumber
        setlocal noruler
 "       syntax on
        setlocal statusline=%=%{CCTreePreviewStatusLine()}

        call s:CCTreeBufferKeyMappingsCreate() 
        nmap <buffer> <C-p>  :CCTreePreviewBufferUsingTag<CR>
        nmap <buffer> <CR>  :CCTreeLoadBufferUsingTag<CR>
    endif
        setlocal foldmethod=expr
        setlocal foldexpr=s:CCTreeFoldExpr(getline(v:lnum))
        setlocal foldtext=CCTreeFoldText()
        let &l:foldlevel=g:CCTreeMinVisibleDepth
endfunction   


function! s:CCTreeDisplayTreeForALevel(dict, str, level)
    if !has_key(a:dict, 'entry')
        return
    endif

    let dashtxt = repeat(" ", a:level*2)."|".repeat("-", a:level)
    if s:currentdirection == 'parent' 
        let directiontxt = "< "
    else
        let directiontxt = "> "
    endif
    call setline(".", a:str. dashtxt. directiontxt. a:dict['entry'])
    exec "normal o"
    let &foldlevel = a:level
    if has_key(a:dict, 'childlinks')
        for a in a:dict['childlinks']
            call s:CCTreeDisplayTreeForALevel(a, substitute(a:str.dashtxt, "-", " ", "g"), a:level+1)
        endfor
    endif
endfunction

function! s:CCTreeDisplayTreeInWindow(atree)
    call s:CCTreePreviewWindowEnter()
    setlocal modifiable
    1,$d
    call s:CCTreeDisplayTreeForALevel(a:atree, '',  0) 
    exec "normal gg"
    " Need to force this again
    let &l:foldlevel=g:CCTreeMinVisibleDepth
    setlocal nomodifiable
    call s:CCTreePreviewWindowLeave()
endfunction

function! s:CCTreeFoldExpr(line)
    let len = strlen(matchstr(a:line,'|-\+'))
    if len == 0
        let len = 1
    endif
    return len
endfunction


" Find a better way of doing this
function! s:Power(exp, base)
    let retval = 1  
    let cnt = a:exp
    while cnt > 0
        let retval = retval * a:base
        let cnt = cnt - 1
    endwhile
    return retval
endfunction

function! CCTreeFoldText()
    return repeat(" ", v:foldlevel-1 + (s:Power(v:foldlevel, 2))).'|'.v:folddashes. (v:foldend - v:foldstart + 1). ' items'
endfunction


function! s:CCTreeStoreState(symbol, direction)
    let s:currentkeyword = a:symbol
    let s:currentdirection = a:direction
endfunction

function! s:CCTreeDBIsLoaded()
    if s:dbloaded == 0
        call s:CCTreeWarningMsg('CCTree database not loaded')
        return 0
    endif
    return 1
endfunction

function! s:CCTreeTraceForwardTreeForSymbol(symbol)
    if (s:CCTreeDBIsLoaded() == 0) 
        return
    endif
    let atree = s:CCTreeGetCallsForSymbol(a:symbol, 0, 'child')
    call s:CCTreeStoreState(a:symbol, 'child')
    call s:CCTreeUpdateForCurrentSymbol()
endfunction

function! s:CCTreeTraceReverseTreeForSymbol(symbol)
    if (s:CCTreeDBIsLoaded() == 0) 
        return
    endif
    let atree = s:CCTreeGetCallsForSymbol(a:symbol, 0, 'parent')
    call s:CCTreeStoreState(a:symbol, 'parent')
    call s:CCTreeUpdateForCurrentSymbol()
endfunction

function! s:CCTreeUpdateForCurrentSymbol()
    if s:currentkeyword != ''
        let atree = s:CCTreeGetCallsForSymbol(s:currentkeyword, 0, s:currentdirection)
        call s:CCTreeDisplayTreeInWindow(atree)
    endif
endfunction


function! s:CCTreeGetCurrentKeyword()
    let s:CCTreekeyword = matchstr(expand("<cword>"), '\k\+')
endfunction

function! s:CCTreeLoadBufferFromKeyword()
    call s:CCTreeGetCurrentKeyword()
    let g:dbg = s:CCTreekeyword
    try 
        exec 'wincmd p'
    catch
        call s:CCTreeWarningMsg('No buffer to load file')
    finally
        if (cscope_connection() > 0)
            exec "cstag ".s:CCTreekeyword
        else
            exec "tag ".s:CCTreekeyword
        endif
    endtry
endfunction
    
function! s:CCTreePreviewBufferFromKeyword()
    call s:CCTreeGetCurrentKeyword()
    exec "ptag ".s:CCTreekeyword
endfunction

function! s:CCTreeRecursiveDepthIncrease()
    let g:CCTreeRecursiveDepth += 1
    call s:CCTreeUpdateForCurrentSymbol()
endfunction

function! s:CCTreeRecursiveDepthDecrease()
    let g:CCTreeRecursiveDepth -= 1
    call s:CCTreeUpdateForCurrentSymbol()
endfunction


function! s:CCTreeCursorHoldHandle()
    call s:CCTreeGetCurrentKeyword()

    if s:CCTreekeyword == ''
        match none
    else 
       exec "match CCTreeKeyword /\\<".s:CCTreekeyword."\\>/"
    endif
endfunction

augroup CCTreeGeneral
    au!
    autocmd CursorHold CCTree-Preview call s:CCTreeCursorHoldHandle()
augroup END

highlight link CCTreeKeyword Tag

" Define commands
command! -nargs=0 CCTreeLoadDB                 call s:CCTreeLoadDB()
command! -nargs=0 CCTreeUnLoadDB               call s:CCTreeUnloadDB()
command! -nargs=1 -complete=tag CCTreeTraceForward   
                                              \ call s:CCTreeTraceForwardTreeForSymbol(<f-args>)
command! -nargs=1 -complete=tag CCTreeTraceReverse  
                                              \ call s:CCTreeTraceReverseTreeForSymbol(<f-args>)
command! -nargs=0 CCTreeLoadBufferUsingTag call s:CCTreeLoadBufferFromKeyword()
command! -nargs=0 CCTreePreviewBufferUsingTag call s:CCTreePreviewBufferFromKeyword()
command! -nargs=0 CCTreeRecurseDepthPlus call s:CCTreeRecursiveDepthIncrease()
command! -nargs=0 CCTreeRecurseDepthMinus call s:CCTreeRecursiveDepthDecrease()

function! s:CCTreeBufferKeyMappingsCreate()
     nmap <buffer> <C-\>< :CCTreeTraceReverse <C-R>=expand("<cword>")<CR><CR> 
     nmap <buffer> <C-\>> :CCTreeTraceForward <C-R>=expand("<cword>")<CR><CR> 
     nmap <buffer> <C-\>= :CCTreeRecurseDepthPlus<CR> 
     nmap <buffer> <C-\>- :CCTreeRecurseDepthMinus<CR> 
endfunction

augroup CCTreeMaps
au!
" Header files get detected as cpp?
autocmd FileType * if &ft == 'c'|| &ft == 'cpp' |call s:CCTreeBufferKeyMappingsCreate()| endif
augroup END
