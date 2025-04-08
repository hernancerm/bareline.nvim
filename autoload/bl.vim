function! bl#Is(length)
  let u2009_chars = ''
  for i in range(1, a:length)
    " Unicode Thin Space (U+2009)
    let u2009_chars .= ' '
  endfor
  return u2009_chars
endfunction

function! bl#Ina(value,mapper)
  if get(b:, '_bareline_is_buf_active', v:false)
    return a:value
  else
    return a:mapper(a:value)
  endif
endfunction

function! bl#Inarm(value)
  return bl#Ina(a:value, { -> '' })
endfunction

function! bl#Inahide(value)
  return bl#Ina(a:value, { v -> bl#Is(strlen(v)) })
endfunction

function! bl#Padl(value)
  if a:value !=# ''
    return bl#Is(1) . a:value
  endif
  return ''
endfunction

function! bl#Padr(value)
  if a:value !=# ''
    return a:value . bl#Is(1)
  endif
  return ''
endfunction

function! bl#Pad(value)
  return bl#Padr(bl#Padl(a:value))
endfunction

function! bl#Wrap(value,prefix,suffix)
  if a:value !=# ''
    return a:prefix . a:value . a:suffix
  endif
  return ''
endfunction
