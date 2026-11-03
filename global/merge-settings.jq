def merge($managed):
  if type == "object" and ($managed | type) == "object" then
    reduce ($managed | keys_unsorted[]) as $key (.;
      .[$key] = (if .[$key] == null then $managed[$key] else (.[$key] | merge($managed[$key])) end))
  elif type == "array" and ($managed | type) == "array" then
    . + ($managed - .)
  else
    $managed
  end;

merge($managed[0])
