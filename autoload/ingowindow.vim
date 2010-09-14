" ingowindow.vim: Custom window functions. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
" REVISION	DATE		REMARKS 
"	007	10-Sep-2010	ingowindow#NetWindowWidth() now considers
"				'relativenumber' setting introduced in Vim 7.3. 
"	006	02-Dec-2009	Added ingowindow#WindowDecorationColumns() and
"				ingowindow#NetWindowWidth(), taken from
"				LimitWindowWidth.vim. 
"				ENH: Implemented support for adjusted
"				numberwidth and sign column to
"				ingowindow#WindowDecorationColumns(). 
"	005	27-Jun-2009	Added augroup. 
"	004	04-Aug-2008	ingowindow#FoldedLines() also returns number of
"				folds in range. 
"	003	03-Aug-2008	Added ingowindow#FoldedLines() and 
"				ingowindow#NetVisibleLines(). 
"	002	31-Jul-2008	Added ingowindow#UndefineMappingForCmdwin(). 
"	001	31-Jul-2008	Moved common window movement mappings from
"				ingowindowmappings.vim
"				file creation

" Special windows are preview, quickfix (and location lists, which is also of
" type 'quickfix'). 
function! ingowindow#IsSpecialWindow(...)
    let l:winnr = (a:0 > 0 ? a:1 : winnr())
    return getwinvar(l:winnr, '&previewwindow') || getwinvar(l:winnr, '&buftype') == 'quickfix'
endfunction
function! ingowindow#SaveSpecialWindowSize()
    let s:specialWindowSizes = {}
    for w in range(1, winnr('$'))
	if ingowindow#IsSpecialWindow(w)
	    let s:specialWindowSizes[w] = [winwidth(w), winheight(w)]
	endif
    endfor
endfunction
function! ingowindow#RestoreSpecialWindowSize()
    for w in keys(s:specialWindowSizes)
	execute 'vert' w.'resize' s:specialWindowSizes[w][0]
	execute        w.'resize' s:specialWindowSizes[w][1]
    endfor
endfunction



" The command-line window is implemented as a window, so normal mode mappings
" apply here as well. However, certain actions cannot be performed in this
" special window. The 'CmdwinEnter' event can be used to redefine problematic
" normal mode mappings. 
let s:CmdwinMappings = {}
function! ingowindow#UndefineMappingForCmdwin( mappings, ... )
"*******************************************************************************
"* PURPOSE:
"   Register mappings that should be undefined in the command-line window. 
"   Previously registered mappings equal to a:mappings will be overwritten. 
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   :nnoremap <buffer> the a:mapping
"* INPUTS:
"   a:mapping	    Mapping (or list of mappings) to be undefined. 
"   a:alternative   Optional mapping to be used instead. If omitted, the
"		    a:mapping is undefined (i.e. mapped to itself). If empty,
"		    a:mapping is mapped to <Nop>. 
"* RETURN VALUES: 
"   1 if accepted; 0 if autocmds not available
"*******************************************************************************
    let l:alternative = (a:0 > 0 ? (empty(a:1) ? '<Nop>' : a:1) : '')

    if type(a:mappings) == type([])
	let l:mappings = a:mappings
    elseif type(a:mappings) == type('')
	let l:mappings = [ a:mappings ]
    else
	throw 'passed invalid type ' . type(a:mappings)
    endif
    for l:mapping in l:mappings
	let s:CmdwinMappings[ l:mapping ] = l:alternative
    endfor
    return has('autocmd')
endfunction
function! s:UndefineMappings()
    for l:mapping in keys(s:CmdwinMappings)
	let l:alternative = s:CmdwinMappings[ l:mapping ]
	execute 'nnoremap <buffer> ' . l:mapping . ' ' . (empty(l:alternative) ? l:mapping : l:alternative)
    endfor
endfunction
if has('autocmd')
    augroup ingowindow
	autocmd!
	autocmd CmdwinEnter * call <SID>UndefineMappings()
    augroup END
endif




" Determine the number of lines in the passed range that lie hidden in a closed
" fold; that is, everything but the first line of a closed fold. 
" Returns [ number of folds in range, number of folded away (i.e. invisible)
" lines ]. Sum both values to get the total number of lines in a fold in the
" passed range. 
function! ingowindow#FoldedLines( startLine, endLine )
    let l:foldCnt = 0
    let l:foldedAwayLines = 0
    let l:line = a:startLine

    while l:line < a:endLine
	if foldclosed(l:line) == l:line
	    let l:foldCnt += 1
	    let l:foldend = foldclosedend(l:line)
	    let l:foldedAwayLines += (l:foldend > a:endLine ? a:endLine : l:foldend) - l:line
	    let l:line = l:foldend
	endif
	let l:line += 1
    endwhile

    return [ l:foldCnt, l:foldedAwayLines ]
endfunction

" Determine the number of lines in the passed range that aren't folded away;
" folded ranges count only as one line. Visible doesn't mean "currently
" displayed in the window"; for that, you can create the difference of the start
" and end winline(). 
function! ingowindow#NetVisibleLines( startLine, endLine )
    return a:endLine - a:startLine + 1 - ingowindow#FoldedLines(a:startLine, a:endLine)[1]
endfunction



" Determine the number of virtual columns of the current window that are not
" used for displaying buffer contents, but contain window decoration like line
" numbers, fold column and signs. 
function! ingowindow#WindowDecorationColumns()
    let l:decorationColumns = 0

    let l:maxNumber = 0
    " Note: 'numberwidth' is only the minimal width, can be more if...
    if &l:number
	" ...the buffer has many lines. 
	let l:maxNumber = line('$')
    elseif exists('+relativenumber') && &l:relativenumber
	" ...the window width has more digits. 
	let l:maxNumber = winheight(0)
    endif
    if l:maxNumber > 0
	let l:actualNumberWidth = strlen(string(l:maxNumber)) + 1
	let l:decorationColumns += (l:actualNumberWidth > &l:numberwidth ? l:actualNumberWidth : &l:numberwidth)
    endif

    if has('folding')
	let l:decorationColumns += &l:foldcolumn
    endif

    if has('signs')
	redir => l:signsOutput
	silent execute 'sign place buffer=' . bufnr('')
	redir END

	" The ':sign place' output contains two header lines. 
	" The sign column is fixed at two columns. 
	if len(split(l:signsOutput, "\n")) > 2
	    let l:decorationColumns += 2
	endif
    endif

    return l:decorationColumns
endfunction

" Determine the number of virtual columns of the current window that are
" available for displaying buffer contents. 
function! ingowindow#NetWindowWidth()
    return winwidth(0) - ingowindow#WindowDecorationColumns()
endfunction

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax : 
