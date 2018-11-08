# ALE Silence

_WIP: May be subject to breaking change at any time for any reason._

_Documentation as of now is limited to this file and the tests._

`ale-silence` is a Vim plugin that silences linters. It extends and depends upon the [Asynchronous Lint Engine]( https://github.com/w0rp/ale )

## Usage

Position your cursor on a line with one or more linter errors, run the command
`:ALESilence`, and `ale-silence` will insert the directive needed for the linter
to ignore it.

Demonstration with `rubocop`:

### Linewise

Running `:ALESilence` on the line

```ruby
str = "string with double quotes boooo"
```

results in

```ruby
str = "string with double quotes boooo" # rubocop: disable Style/StringLiterals
```

### Range

Running `:ALESilence` on a range silences the errors within that range.

```ruby
# rubocop: disable Style/StringLiterals
str1 = "string with double quotes boooo"
str2 = "more heresy"
# rubocop: enable Style/StringLiterals
```

### Filewise

Running `:ALESilence!` silences all errors in the file.

Running `:ALESilence!` on a range silences all errors within the range for the
entire file.

### Arguments and Completion

Without arguments, `:ALESilence` silences all reported errors on line/in range.

Given arguments on the form `<linter_name>:<error_code>`, it silences only the
errors given. Command completion provides the reported errors.

### Other Commands

`:ALESilenceShow` lists the silence directives used for linters currently
reporting errors.

`:ALEBrowseDocs <linter_name>` opens the documentation for the specified linter.

`:ALESilenceLookup <linter_name>:<error_code>` opens a the documentation for the
specified error.

The documentation is opened in a web browser, by means of `netrw`, see `:help
netrw`.

### Options and Limitations

The capabilities for in-file silencing vary from linter to linter. Rather than
an _in-line_ directive

```ruby
str = "string with double quotes boooo" # rubocop: disable Style/StringLiterals
```

some take one on the preceding line

```sh
# shellcheck disable=SC1117
printf "%s\n" "$@"
```

For linters that support both _in-line_ and _next-line_ style directives,
`ale-silence` prefers `next-line`. If you'd rather have `in-line`, set

```vim
let g:ale_silence_prefer_inline = 1
" or for current buffer only
let b:ale_silence_prefer_inline = 1
```

Not all linters have directives to silence a _range_ of lines. `ale-silence` will
then walk the range and disable each line using _in-line_ or _next-line_
directives. To turn this off, set

```vim
let g:ale_silence_range_fallback = 0
" or for current buffer only
let b:ale_silence_range_fallback = 0
```

Likewise, you can have a missing _filewise_ directive fall back to disabling a
_range_. This option is off by default. If unsupported, `ale-silence` will
further fall back to _linewise_, depending on
`(g|b):ale_silence_range_fallback`.

```vim
let g:ale_silence_filewise_fallback = 1
" or for current buffer only
let b:ale_silence_filewise_fallback = 1
```

## Linter Support and Extending

As of now, not many linters are supported. To add support for one, create a file
`autoload/ale_silence/<linter_name>.vim`, and implement the following functions:

```vim
function! ale_silence#<linter_name>#GetSilenceDirectives()
  return {
      \ 'inline':    <directive>,
      \ 'nextline':  <directive>,
      \ 'file':      <directive>,
      \ 'start':     <directive>,
      \ 'end':       <directive>,
      \ 'separator': <separator>
      \}
endfunction

function! ale_silence#<linter_name>#GetDocInfo()
  return {
      \ 'docs':        <url>,
      \ 'code_search': <search_url>
      \ }
endfunction
```

```
<directive> is:
  A printf format string, with a single %s:

  'start': "/* eslint-disable %s */"

  The error codes are joined with the value of <separator>, or a single
  space if none is given.

or

  A funcref, taking a variable number of error codes, returning the
  commented directive disabling all errors. You may create one by
  giving a printf format string and a separator to ale#silence#Format():

  'file': ale#silence#Format('/* eslint %s: 0 */', ': 0, ')

<url> is a plain string with the url

  'docs': 'https://eslint.org'

<code_search> is a printf format string with a single %s for the error code:

  'code_search': 'https://eslint.org/docs/rules/%s'

'start' and 'end' are the directives for disabling and enabling the errors in
a range of lines:

  'start': '/* eslint-disable %s */',
  'end':   '/* eslint-enable %s */'

Unsupported directives are simply omitted:

function ale_silence#shellcheck#GetSilenceDirectives()
  return {
      \ 'nextline':  '# shellcheck disable=%s',
      \ 'separator': ','
      \ }
endfunction
```


