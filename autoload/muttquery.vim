function! muttquery#SetMuttQueryCommand() abort
  if !exists('g:muttquery_command')
    let g:muttquery_command = ''

    let muttexes = ['neomutt', 'mutt']
    for muttexe in muttexes
      if executable(muttexe) | let mutt = muttexe | break | endif
    endfor

    if exists('mutt')
      silent let output = split(system(mutt . ' -Q "query_command"'), '\n')

      for line in output
        let query_command = matchstr(line, '\v^' . 'query_command' . '\="' . '\zs[^"]+\ze' . '"$')
        if !empty(query_command)
          let g:muttquery_command = query_command
          break
        endif
      endfor
    else
      " pedestrian's way
      let muttrcs = ['~/.config/neomutt/neomuttrc', '~/.config/neomutt/muttrc', '~/.config/mutt/neomuttrc',
            \ '~/.config/mutt/muttrc', '~/.neomutt/neomuttrc', '~/.neomutt/muttrc', '~/.mutt/neomuttrc',
            \ '~/.mutt/muttrc', '~/.neomuttrc', '~/.muttrc']
      let muttrc_content = []
      for muttrc in muttrc
        if filereadable(expand(muttrc)) | let muttrc_content = readfile(expand(muttrc)) | break | endif
      endfor

      for line in muttrc_content
        let query_command = matchstr(line,'\v^\s*set\s+' . 'query_command' . '\s*\=\s*"' . '\zs[^"]+\ze' . '"$')
        if !empty(query_command)
          let g:muttquery_command = resolve(exepath(query_command))
          break
        endif
      endfor
    endif
  endif
  if empty(g:muttquery_command) ||
        \ !filereadable(exepath(expand(split(g:muttquery_command)[0])))
    echoerr 'The command ' . g:muttquery_command . ' is no valid executable.'
    echoerr 'Please set $query_command in ~/.muttrc or g:muttquery_command in ~/.vimrc to a valid executable!'
    let g:muttquery_command = ''
  endif
endfunction

function! muttquery#CompleteQuery(findstart, base) abort
  if a:findstart
    " locate the start of the word
    let col = col('.')-1
    let text_before_cursor = getline('.')[0 : col - 1]
    if text_before_cursor =~? '\v^%(To|B?cc):'
      " in an address line we stop when we encounter the next email address
      let start = match(text_before_cursor, '\v[^,;:]+$')
    else
      " ... otherwise the next space character
      let start = match(text_before_cursor, '\v<\S+$')
    endif
    return start
  else
    let results = []
    if !empty(g:muttquery_command)
      let query_command = substitute(g:muttquery_command, '%s', a:base, '')
      silent let lines = split(system(query_command), '\n')
    endif

    if empty(lines)
      return []
    endif

    let results = []

    for line in lines
      if empty(line)
        continue
      endif
      if line =~? '^\d\+ addresses found:$'
        continue
      endif

      let words = split(line, '\t')

      if len(words) < 2
        continue
      endif

      let dict = {}
      let address = words[0]
      " remove "
      let name = words[1]

      " add to completion menu
      let dict['word'] = '"' . name . '"' . ' <' . address . '>'
      let dict['abbr'] = strlen(name) < 35 ? name : name[0:30] . '...'
      let dict['menu'] = '<' . address . '>'

      call add(results, dict)
    endfor

    return uniq(results, 'i')
  endif
endfunction
