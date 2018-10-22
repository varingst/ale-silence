
function! ale_silence#rubocop#GetSilenceDirectives() abort
  return {
        \ 'inline': '# rubocop: disable %s',
        \ 'start':  '# rubocop: disable %s',
        \ 'end':    '# rubocop: enable %s',
        \ 'file':   '# rubocop: disable %s'
        \}
endfun
