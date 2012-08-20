log = ->
  console.log arguments

PADDING = 50
circle_radius = 5
stage = (data) ->
  data = data.slice(1)
  #06/Apr/2012 17:40:02,Info,Built,ASA-6-302015,UDP,172.23.0.10,128.8.10.90,(empty),(empty),64048,53,domain,outbound,1,0
  #Date/time,Syslog priority,Operation,Message code,Protocol,Source IP,Destination IP,Source hostname,Destination hostname,Source port,Destination port,Destination service,Direction,Connections built,Connections torn down
  unit_day = d3.split data, do ()->
    start = new Date(data[0]["Date/time"])
    (d, i)->
      
      d.time = new Date(d["Date/time"])
      d.priority = (if d["Syslog priority"] is "Info" then 0 else 2)
      if d.time - start > 6000 then (start = d.time) else false
  unit_day_max = -1
  unit_day.forEach (d, i)->
    unit_day_max = d3.max [unit_day_max, d.length]
    d.warnings = (item for item in d when item["Syslog priority"] != "Info").length
  
  log unit_day, unit_day_max

  window.g = data
  dlen = data.length
  width = window.innerWidth
  height = window.innerHeight
  fvy = d3.scale.linear().range([ 0, 50 ]).domain([ 0, unit_day_max ])
  fvx = d3.scale.linear().range([ 0, width ]).domain([ 0, unit_day.length ])

  frs = null
  x1 = x0 = undefined
  innerRadius = Math.min(width, height) * .41
  outerRadius = innerRadius * 1.1
  fill = d3.scale.category10().domain([0..10])

  svg = d3.select("body")
    .append("svg")
    .attr("width", width)
    .attr("height", height)
    .call(d3.behavior.zoom()
      .on("zoom", ()->
        log "123", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")"
        center_stage.transition().duration(500).attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")")
      )
    )

  stage = svg.append("svg:g")
    .attr("transform", "translate(#{PADDING}, #{PADDING})")

  force = svg.append("svg:g")
    .attr("transform", "translate(0, " + (height - PADDING * 2) + ")")
  force.append("svg:path").data([ unit_day ]).attr("d", d3.svg.area().x((d, i) ->
    fvx i
  ).y0(50).y1((d) ->
    40 - fvy(d.length)
  )).attr "fill", fill(0)

  force_warning = svg.append("svg:g")
    .attr("transform", "translate(0, " + (height - PADDING * 2) + ")")
  force_warning.append("svg:path").data([ unit_day ]).attr("d", d3.svg.area().x((d, i) ->
    fvx i
  ).y0(50).y1((d) ->
    #log d.warnings, Math.ceil(fvy(d.warnings))
    50 - Math.ceil(fvy(d.warnings)) - 5
  )).attr("fill", fill(3)).attr("opacity", 1)

  force_rect = force_warning
    .append("svg:rect")
    .attr("opacity", 0)
    .attr("width", width)
    .attr("height", 50)
    .attr("pointer-events", "all")
    .attr("cursor", "crosshair")
    .on("mousedown", ->
      frs = fvx.invert(d3.svg.mouse(this)[0])
    )
  #log fvx(data[dlen - 1].time), data[dlen-1]
  active = force
    .append("svg:rect")
    .attr("pointer-events", "none")
    .attr("id", "active")
    .attr("height", 50)
    .attr("width", fvx(data[dlen - 1].time))
    .attr("fill", "lightcoral")
    .attr("fill-opacity", .5)

  title = stage.append("text")
    .attr("x", 50)
    .attr("y", 10)
    .attr("fill", fill(7))
    .attr("font-size", 27)
    .text("PKU VIS summer school 2012 group 3")

  text_time = stage.append("text")
    .attr("x", width-1050)
    .attr("y", height - 200)
    .attr("fill", fill(7))
    .attr("font-size", 100)

  d3.select(window).on("mouseup", ->
    ox0 = x0
    ox1 = x1
    xy = fvx.invert(d3.svg.mouse(active[0][0])[0])
    if frs < xy
      x0 = frs
      x1 = xy
    else if frs > xy
      x0 = xy
      x1 = frs
    else
      return
    return unless ox0 == x0 and ox1 == x1
    data_sub = []
    for i in [x0|0..x1|0]
      data_sub = data_sub.concat unit_day[i]
    text_time.text(data_sub[0].time.toISOString()[..-6])
    draw_center(data_sub)
    frs = null

  ).on "mousemove", ->
    return  unless frs?
    xy = fvx.invert(d3.svg.mouse(active[0][0])[0])
    if frs < xy
      x0 = frs
      x1 = xy
    else if frs > xy
      x0 = xy
      x1 = frs
    else
      return

    tx = d3.scale.linear().domain([ x0, x1 ]).range([ 0, width ])
    active
      .attr("x", fvx(x0))
      .attr("width", fvx(x1) - fvx(x0))
      

  #zoomin = svg
  #  .append("rect")
  #  .attr("transform", "translate(10, #{height-PADDING*4})")
  #  .attr("width", "100")
  #  .attr("height", "50")
  #  .attr("fill", fill(3))
  #  .on("click", (e) ->
  #    console.log "123"
  #  )
  #  .append("text")
  #  .text("ZoomIn")
  #  .attr("fill", fill(0))

  center_stage = svg.append("svg:g").attr("transform", "translate(#{ width /4 }, #{ height /4 })")
  center_force = d3.layout.force().charge(-40).linkDistance(10).size([width/2, height/2])
  center_link = center_node = null
  center_force.on("tick", ()->
    center_link.attr("x1", (d)->
      d.source.x
    ).attr("y1", (d)->
      d.source.y
    ).attr("x2", (d)->
      d.target.x
    ).attr("y2", (d)->
      d.target.y
    )

    center_node.attr("cx", (d)->
      d.x
    ).attr("cy", (d)->
      d.y
    )
  )
  draw_center = (data)->
    nodes = []
    links = []
    data.forEach (d, n)->
      sourceip = d["Source IP"]
      destip = d["Destination IP"]
      snew = dnew = true
      spos = dpos = -1
      
      for i in nodes
        if i.name == sourceip
          spos = _i
          snew = false
        if i.name == destip
          dpos = _i
          dnew = false

      if snew
        spos = nodes.push({name: sourceip, group: if d["priority"] > 1 then 3 else 1}) - 1
      if dnew
        dpos = nodes.push({name: destip, group: 2}) - 1
      
      link = (i for i in links when i.source == spos and i.target == dpos)?[0]
      if not link
        link = {source: spos, target: dpos, value: 1}
        links.push(link)
      else
        link.value++
    log nodes, links
        
    center_force.nodes(nodes).links(links).start()
    center_stage.selectAll("*").remove()
    center_node = center_stage.selectAll("circle")
      .data(nodes)
      .enter()
      .append("circle")
      .attr("class", "node")
      .attr("r", (d)->
        Math.max(d.group * 3, 2)
      ).attr("fill", (d) ->
        fill d.group
      ).call(center_force.drag)
      #.on("hover", (d)->
      #  log d, this
      #)

    #center_node
    #  .append("title").text((d)->
    #    d.name
    #  )

    center_link = center_stage.selectAll("line")
      .data(links)
      .enter()
      .append("line")
      .attr("class", "link")
      .attr("fill", "#EEE")
      .style("stroke-width", (d)->
        Math.min(Math.sqrt(d.value), 10)
      )
      ##
  #draw_center(data)

d3.csv "small.csv", stage
