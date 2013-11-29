" LimitWindowSize.vim: Reduce the current window size by placing an empty padding window next to it.
"                                      X                                       X
"                                      X
" DEPENDENCIES:
"   - ingo/msg.vim autoload script
"   - ingo/window/dimensions.vim autoload script
"
" Copyright: (C) 2010-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.01.003	25-Oct-2013	Use ingo/msg.vim.
"				Add workaround for when a :LimitWindowWidth
"				command is issued from a still minimized GVIM in
"				the process of restoring its window. The check
"				for the window width then needs to be delayed
"				until after the VimResized event.
"   1.01.002	08-Apr-2013	Move ingowindow.vim functions into ingo-library.
"   1.00.001	11-Sep-2010	file creation

function! s:HasPaddingWindow()
    let l:winNr = winnr()
    noautocmd wincmd l
    if bufname('') =~# '^\[Padding\%(\d\+\)\?\]$'
	return 1
    else
	" Return to original window.
	execute 'noautocmd' l:winNr . 'wincmd w'
	return 0
    endif
endfunction

function! s:CreatePaddingWindow( width )
    if a:width < 2
	" The vertical window separator (|) takes up one space, and the net
	" width must be at least 1. Smaller widths cannot be created.
	return 0
    endif

    " The name of the padding buffer must be unique to avoid an E95 error.
    let l:paddingName = '[Padding]'
    let l:paddingCnt = 0
    while bufexists(l:paddingName)
	let l:paddingCnt += 1
	let l:paddingName = '[Padding' . l:paddingCnt . ']'
    endwhile

    silent execute 'belowright ' . (a:width - 1) . 'vnew +file\ ' . l:paddingName

    " The padding buffer is read-only and empty.
    setlocal filetype=nofile
    setlocal statusline=%f  " Show just the padding name in the statusline, no line numbers etc.
    setlocal nonumber
    if exists('+relativenumber') | setlocal norelativenumber | endif
    setlocal bufhidden=delete
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nocursorline
    setlocal nocursorcolumn
    " Note: Somehow, the :file command needs to be applied once during opening
    " and once again at the end. Otherwise (when :LimitWindowWidth is executed
    " from a ftplugin), the filename isn't set correctly (it is listed as ""),
    " causing the netrw plugin to take over the padding buffer.
    " Note: :silent is used to suppress the duplicate "[Padding] 1 line" message
    " which may result from the duplicate :file command.
    silent execute 'file ' . l:paddingName

    return 1
endfunction

function! LimitWindowSize#LimitWindowWidth( ... )
    let l:width = (a:0 ? a:1 : (&textwidth > 0 ? &textwidth : 80))
    if l:width <= 0
	call ingo#msg#ErrorMsg('Must specify positive window width!')
	return
    endif

    if &columns <= 16
	" With GVIM on Windows in minimized fullscreen mode (and a remote
	" command that restores the GVIM window, edits a file, whose ftplugin
	" executes :LimitWindowWidth), the value of 'columns' is 16, and
	" LimitWindow's check aborts the limiting. In this case, we need to
	" re-schedule the command for when GVIM has been restored to its
	" maximized state. But check for the same window and buffer in case the
	" VimResized event isn't thrown shortly thereafter.
	augroup LimitWindowSizeDelayedLimit
	    execute printf('autocmd! VimResized * if winnr() == %d && bufnr("") == %d | call LimitWindowSize#LimitWindowWidth(%d) | endif | autocmd! LimitWindowSizeDelayedLimit', winnr(), bufnr(''), l:width)
	augroup END
	return
    endif

    let l:paddingWindowWidth = ingo#window#dimensions#NetWindowWidth() - l:width
    if l:paddingWindowWidth == 0
	return
    endif

    let l:winNr = winnr()
    let l:isCreatedPaddingWindow = 0
    if s:HasPaddingWindow()
	if l:paddingWindowWidth > 0
	    " Must increase existing padding window.
	    execute l:paddingWindowWidth . 'wincmd >'
	elseif l:paddingWindowWidth < 0
	    if - l:paddingWindowWidth >= winwidth(0)
		" The entire padding window gets eaten by the increased window
		" size, so remove it.
		wincmd c
	    else
		" Reduce width of padding window.
		execute - l:paddingWindowWidth . 'wincmd <'
	    endif
	else
	    throw 'ASSERT: l:paddingWindowWidth != 0'
	endif
    elseif l:paddingWindowWidth > 0
	let l:isCreatedPaddingWindow = s:CreatePaddingWindow(l:paddingWindowWidth)
    endif

    " Return to original window.
    execute l:winNr . 'wincmd w'

    if has('gui_running') && l:isCreatedPaddingWindow
	" If a padding window has been created, there may now be an additional
	" scrollbar (in case there wasn't a vertical split yet and 'guioptions'
	" contains either "rL" or "lR"). Normally, the GVIM window expands
	" horizontally to accommodate the second scrollbar, but if the window is
	" maximized, this is not possible, and the value of 'columns' is
	" decreased (typically by 2) instead. In that case, the desired window
	" width is off by the decrease of available columns.
	" To fix this, we recursively invoke the function again, so that it
	" re-checks the current window width and in case of a discrepancy
	" reduces the width of the padding window.
	call LimitWindowSize#LimitWindowWidth( l:width )
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
