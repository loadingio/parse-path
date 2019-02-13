group = do
  h: {}
  g: {}
  m: 1
  init: -> @ <<< m: 1, g: {}, h: {}
    
  groups: ->
    ret = []
    remap = 1
    for k,v of @g => if @g[k].idx == +k =>
      @g[k].id = remap
      remap++
      ret.push @g[k]
    for k,v of @g => @g[k].id = @g[@g[k].idx].id
    return ret
  get-groups: ->
   @groups!
   for k,v of @g => @g[k].members = []
   for k,v of @h => @g[@g[@h[k]].idx].members.push +k
   ret = []
   for k,v of @g => if +k == v.idx => ret.push v
   return ret

  add: (i) ->
    m = if @h[i]? => @h[i] else @h[i] = @m 
    if !@g[m] => @g[m] = {idx: m}
    if m == @m => @m++
  join: (i, j) ->
    mg = Math.min(@h[i] or @m, @h[j] or @m)
    if !@g[mg] => @g[mg] = {idx: mg}
    [i,j].map ~>
      if @h[it] => @g[@h[it] or @m] = @g[mg]
      @h[it] = mg
    if mg == @m => @m++
    @groups!
