" LimitWindowSize.vim: Reduce the current window size by placing an empty padding window next to it. 
"
" DEPENDENCIES:
"   - LimitWindowSize.vim autoload script. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   1.00.009	11-Sep-2010	Moved functions from plugin to separate autoload
"				script. 
"	008	10-Sep-2010	ENH: Now considers 'relativenumber' setting
"				introduced in Vim 7.3. 
"	007	06-Jul-2010	ENH: {width} can now be omitted, falls back to
"				'textwidth' or 80. 
"	006	02-Dec-2009	Factored out s:NetWindowWidth() into
"				ingowindow.vim to allow reuse by other plugins. 
"	005	10-Aug-2009	BF: In a maximized GVIM, the creation of the
"				padding window may lead to a reduction of
"				'columns' to make space for a second scrollbar. 
"				Now recursing in case a padding window has been
"				created in a GVIM. 
"	004	25-Jun-2009	Now using :noautocmd to avoid unnecessary
"				processing while searching for padding window. 
"	003	16-Jan-2009	Now setting v:errmsg on errors. 
"	002	13-Jun-2008	Added -bar to :LimitWindowWidth. 
"	001	10-May-2008	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_LimitWindowSize') || (v:version < 700)
    finish
endif
let g:loaded_LimitWindowSize = 1

" This global setting is about the minimum width in the _current_ buffer. 
" Without this setting, jumping into a padding buffer could increase its width. 
set winwidth=1

command! -bar -nargs=? LimitWindowWidth call LimitWindowSize#LimitWindowWidth(<f-args>)

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
