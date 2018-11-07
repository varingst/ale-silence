" shellcheck filewise is the same directive, but at second line of file
function! ale_silence#shellcheck#GetSilenceDirectives() abort
  return {
        \ 'nextline': '# shellcheck disable=%s',
        \ 'separator': ','
        \}
endfunction
