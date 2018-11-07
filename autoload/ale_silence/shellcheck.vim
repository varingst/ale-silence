" shellcheck filewise is the same directive, but at second line of file
function! ale_silence#shellcheck#GetSilenceDirectives() abort
  return {
        \ 'nextline': '# shellcheck disable=%s',
        \ 'separator': ','
        \}
endfunction

function! ale_silence#shellcheck#GetDocInfo() abort
  return {
        \ 'docs': 'https://github.com/koalaman/shellcheck/wiki',
        \ 'code_search': 'https://https://github.com/koalaman/shellcheck/wiki/%s'
        \}
endfunction
