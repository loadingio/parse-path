parse-path = (path, trianglify = false) ->
  [shape,hole] = [[],[]]
  svg = document.createElementNS \http://www.w3.org/2000/svg, \svg
  svg.style <<< position: \absolute, opacity: 0, z-index: -1, top: 0
  # appendChild is required to get correct result from complex shapes.
  document.body.appendChild svg
  ds = []
  t1 = Date.now!
  paths = path.replace(/Z/g,'z').split \\z
    .filter -> it
    .map ->
      ds.push it
      path = document.createElementNS \http://www.w3.org/2000/svg, \path
      path.setAttribute \d, it
      svg.appendChild path
      box = path.getBoundingClientRect!
      len = path.getTotalLength!
      pts = []
      # TODO 50 samples made here. we may want to use sth like bisect with a threshold distance
      # so we can have a dynamic point sample count. 
      for i from 0 to (len + 1) by (if len => (len / 50) else 1) =>
        p = path.getPointAtLength i
        pts.push p.x * 0.005 - 0.8, 0.1 - p.y * 0.02
      sum = 0
      for i from 0 til pts.length - 2 by 2 =>
        j = (i + 2) % pts.length
        sum += (pts[j] - pts[i]) / (pts[j + 1] + pts[i + 1])
      return {path: path, box: box, dir: (sum > 0), data: pts, size: box.width * box.height}
    .filter -> it
  shapes = []
  shape = null
  # check if p1 and p2 intersect. ratio: ratio of inside point. 0 = any point. 1 = all points.
  intersect = (p1, p2, ratio = 0.5) ->
    skip = 0 # skip how many points per check. since we have quite a lot points, this can speed up a bit.
    skip = skip * 2 + 2
    [b1, b2] = [p1.box, p2.box]
    # bounding box not intersect - return false directly.
    if !(b1.x < b2.x + b2.width and b1.x + b1.width > b2.x and
    b1.y < b2.y + b2.height and b1.y + b1.height > b2.y) => return false
    # for check p1 in p2 and p2 in p1
    for m from 0 to 1 =>
      count = 0
      is-inside = true
      [p1,p2] = [p2,p1]
      total = (p1.data.length / (skip or 1)) or 1
      # for each point
      for k from 0 til p1.data.length by skip =>
        [x, y] = [p1.data[k], p1.data[k + 1]]
        inside = false
        # base on https://github.com/substack/point-in-polygon
        for i from 0 til p2.data.length by skip =>
          j = (i + skip) % p2.data.length
          [xi, yi] = [p2.data[i], p2.data[i + 1]]
          [xj, yj] = [p2.data[j], p2.data[j + 1]]
          if (yi > y) != (yj > y) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) => inside = !inside
        is-inside = is-inside and inside
        if inside => count++
        # 1. this ensure that every point is inside. doesn't work well if font is not designed properly
        #    for example, SVG from `堡` with 裝甲明朝 works incorrectly.
        if ratio == 1 => continue
        # 2. alternatively, this ensure any point is inside
        # howevere for our scenario we may want to ensure a certain amount of points is inside
        # to consider them as intersect.
        if ratio == 0 =>
          if inside => return true else continue
        # 3. last, a percentage is check based on given ratio.
        if count /total >= ratio => return true
      if is-inside => return true
    return is-inside
  # group polygons by intersection
  group.init!
  for i from 0 til paths.length => group.add i
  for i from 0 til paths.length =>
    for j from i + 1 til paths.length =>
      if intersect paths[i], paths[j] => group.join i, j
  # {key: {members: [indice, ...], idx: <idx>, id: <id>}, ...}
  gs = group.get-groups!
  if trianglify =>
    for g in gs =>
      shape = {shape: [], hole: [], hole-idx: []}
      base = g.members.map(-> paths[it])
      base.sort (a,b) -> b.size - a.size
      base = base.0
      for idx in g.members =>
        p = paths[idx]
        # https://oreillymedia.github.io/Using_SVG/extras/ch06-fill-rule.html#callout_online_extras_CO3-1
        # check above link to see if there is any misunderstanding - properly there is.
        # SVG doesn't use clkwis/counterclkwis, but to see if they are in the same direction.
        # then, SVG uses fill-rule ( evenodd or nonezero ) to determine how to deal with holes.
        # default is none-zero -> if there is overlap, there is hole.
        # EVENODD: use the first polygon as base for checking direction.
        # if p.dir == base.dir => shape.shape ++= p.data 
        # NONEZERO: use the first polygon as base, otherwise holes.
        if p == base => shape.shape ++= p.data
        else 
          shape.hole-idx.push shape.hole.length / 2
          shape.hole ++= p.data
      shape.hole-idx = shape.hole-idx.map -> it + shape.shape.length / 2
      shapes.push shape
    ret = {faces: [], pts: [], groups: []}
    g = 1
    # earcut for each group to get faces. group idx also provided here.
    for shape in shapes =>
      pts = shape.shape ++ shape.hole
      faces = earcut pts, shape.hole-idx
      faces = faces.map -> it + (ret.pts.length / 2)
      ret.faces ++= faces
      ret.pts ++= pts
      for i from 0 til pts.length / 2 => ret.groups.push g
      g++
  else
    ret = []
    for g in gs => ret.push g.members.map((i)->ds[i]).join('z')
  svg.parentNode.removeChild svg
  return ret
