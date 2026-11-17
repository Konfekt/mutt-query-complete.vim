if exists('g:loaded_muttquery') || &cp
  finish
endif
let g:loaded_muttquery = 1

let s:keepcpo         = &cpo
set cpo&vim
" ------------------------------------------------------------------------------

if !exists('g:muttquery_filetypes')
  let g:muttquery_filetypes = [ 'mail' ]
endif

augroup muttquery
  autocmd!
  if !empty(g:muttquery_filetypes)
    exe 'autocmd FileType ' join(g:muttquery_filetypes, ',')
          \ 'call muttquery#SetMuttQueryCommand() |' .
          \ 'setlocal omnifunc=muttquery#CompleteQuery'
  endif
augroup end

" ------------------------------------------------------------------------------
let &cpo= s:keepcpo
unlet s:keepcpo
