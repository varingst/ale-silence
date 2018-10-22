function! ale_silence#eslint#GetSilenceDirectives() abort
  return {
        \ 'inline':   '// eslint-disable-line %s',
        \ 'nextline': '// eslint-disable-next-line %s',
        \ 'file':     ale#silence#Format('/* eslint %s: 0 */', ': 0 '),
        \ 'start':    '/* eslint-disable %s */',
        \ 'end':      '/* eslint-enable %s */'
        \}
endfunction
