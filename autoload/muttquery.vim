" mutt-query-complete: complete e-mail addresses by mutt's query_command.

let s:muttrcs = [
      \ '~/.config/neomutt/neomuttrc', '~/.config/neomutt/muttrc',
      \ '~/.config/mutt/neomuttrc', '~/.config/mutt/muttrc',
      \ '~/.neomutt/neomuttrc', '~/.neomutt/muttrc',
      \ '~/.mutt/neomuttrc', '~/.mutt/muttrc',
      \ '~/.neomuttrc', '~/.muttrc']

" The value of a query_command assignment, as printed by `mutt -Q` or written
" in a muttrc: double-quoted with backslash escapes, or single-quoted, and
" optionally followed by blanks and a comment.
let s:assignment = '\v^\s*%(set\s+)?query_command\s*\=\s*'
      \ . '%("(%([^"\\]|\\.)*)"|''([^'']*)'')\s*%(#.*)?$'

" Return the query_command assigned in the first matching line of {lines}.
function! s:parse(lines) abort
  for line in a:lines
    let m = matchlist(line, s:assignment)
    if !empty(m) && !empty(m[1] . m[2])
      return empty(m[1]) ? m[2] : substitute(m[1], '\\\(.\)', '\1', 'g')
    endif
  endfor
  return ''
endfunction

" Ask neomutt or mutt for query_command; without either, or if it reports
" nothing, for example on an error in the muttrc, read the first muttrc found.
function! s:detect() abort
  let mutt = get(filter(['neomutt', 'mutt'], 'executable(v:val)'), 0, '')
  if !empty(mutt)
    silent let command = s:parse(systemlist(mutt . ' -Q query_command'))
    if !empty(command)
      return command
    endif
  endif
  for muttrc in s:muttrcs
    if filereadable(expand(muttrc))
      return s:parse(readfile(expand(muttrc)))
    endif
  endfor
  return ''
endfunction

function! muttquery#SetMuttQueryCommand() abort
  if !exists('g:muttquery_command')
    let g:muttquery_command = s:detect()
  endif
  let executable = get(split(g:muttquery_command), 0, '')
  if empty(executable) || !executable(expand(executable))
    let error_text = (empty(executable) ? 'No mutt query_command found. '
          \ : 'The command ' . g:muttquery_command . ' is no valid executable. ')
          \ . 'Please set $query_command in ~/.muttrc or g:muttquery_command in ~/.vimrc to a valid executable!'
    let g:muttquery_command = ''
    echoerr error_text
  endif
endfunction

" Insert the shell-quoted {query} into {command} the way mutt does: replace %s,
" together with quotes around it, or append the query if there is no %s.
function! s:query_command(command, query) abort
  let query = shellescape(a:query)
  if stridx(a:command, '%s') < 0
    return a:command . ' ' . query
  endif
  return substitute(a:command, '\([''"]\=\)%s\1', '\=query', '')
endfunction

function! muttquery#CompleteQuery(findstart, base) abort
  if a:findstart
    let text_before_cursor = strpart(getline('.'), 0, col('.') - 1)
    if text_before_cursor =~? '\v^%(%(Reply-|Mail-Followup-)?To|B?cc|From):'
      " in an address line, the query starts after the previous separator
      " and the blanks that follow it
      return match(text_before_cursor, '\v[^,;:[:blank:]][^,;:]*$')
    endif
    " ... otherwise at the start of the word before the cursor
    return match(text_before_cursor, '\v<\S+$')
  endif

  if empty(get(g:, 'muttquery_command', ''))
    return []
  endif
  silent let lines = systemlist(s:query_command(g:muttquery_command, a:base))

  let results = []
  " Each result line reads: address <Tab> name [<Tab> other]. Lines without a
  " tab, such as the leading status line, are skipped.
  for line in lines
    let fields = split(line, '\t', 1)
    if len(fields) < 2 || fields[0] !~# '\S'
      continue
    endif
    let [address, name] = fields[0:1]
    if empty(name)
      let word = address
      let abbr = address
    else
      let word = '"' . escape(name, '"\') . '" <' . address . '>'
      let abbr = strchars(name) < 35 ? name : strcharpart(name, 0, 31) . '...'
    endif
    call add(results, {'word': word, 'abbr': abbr, 'menu': '<' . address . '>'})
  endfor

  return uniq(results, 'i')
endfunction
