
function! ale_silence#rubocop#GetSilenceDirectives() abort
  return {
        \ 'inline':    '# rubocop: disable %s',
        \ 'start':     '# rubocop: disable %s',
        \ 'end':       '# rubocop: enable %s',
        \ 'file':      '# rubocop: disable %s',
        \ 'separator': ', '
        \}
endfun

function! ale_silence#rubocop#GetDocInfo() abort
  return {
        \ 'docs': 'https://docs.rubocop.org/en/latest/',
        \ 'code_search': 'https://docs.rubocop.org/en/latest/search.html?q=%s',
        \}
endfun
