# Database 

    bookDB = new Meteor.Collection("book") 
    patronDB = new Meteor.Collection("patron") 
    klyngeDB = new Meteor.Collection("klynge") 
    faustDB = new Meteor.Collection("faust") 
    statDB = new Meteor.Collection("patronstat") 

## Publishing

    if Meteor.isServer
        Meteor.publish "faust", (faust) ->
            klynge = faustDB.findOne {_id: faust}
            console.log klynge
            if not klynge
                []
            else
                [ (faustDB.find {_id: faust}), (statDB.find {_id: klynge.klynge}) ]


# Source code


    if Meteor.isServer
        Meteor.methods
            neighbours: (klynge) ->
                graphNeighbours klynge
            lookupTitle: (klynge) ->
                lookupTitle klynge

    lookupTitle = (klynge) ->
        bibdkurl = "http://bibliotek.dk/vis.php?origin=kommando&term1=lid%3D" 
        klyngeDesc =  klyngeDB.findOne klynge
        return klyngeDesc.title if klyngeDesc.title
        faust = klyngeDesc.faust
        html = (Meteor.http.get bibdkurl + faust).content
        re = /<span id="linkSign-item1"[^<]*<.span..nbsp.([^<]*)/
        title = (html.match re)[1]
        klyngeDB.update {_id: klynge}, {"$set": {"title": title}}
        return title

    objInc = (obj, key) ->
        obj[key] = (obj[key] || 0) + 1

    graphNeighbours = (klynge) ->
        result = {}
        for patron in (bookDB.findOne {_id: klynge}).patrons
            for book in (patronDB.findOne {_id: patron}).books
                objInc result, book
        result


    if Meteor.isClient
        Meteor.startup ->
            Meteor.call "neighbours", "34647226", (err, result) ->
                0
                # console.log result 
                #for klynge of result
                #    Meteor.call "lookupTitle", klynge, (err, result) ->

            Meteor.call "lookupTitle", "34647226", (err, result) ->
                console.log result

            nodes = [{name: "a a"}, {name: "b"}, {name: "c"}, {name: "d"}]
            links = [
                {source: 0, target: 1, weight: 1}
                {source: 1, target: 2, weight: 1}
                {source: 2, target: 3, weight: 1}
                {source: 3, target: 1, weight: 1}
                ]
            drawGraph nodes, links

    drawGraph = (nodes, links) ->
            w = window.innerWidth
            h = window.innerHeight

            svg = d3.select("body").append("svg")
            svg.attr("width", w)
            svg.attr("height", h)

            force = d3.layout.force()
            force.charge -120
            force.linkDistance 30
            force.size [w, h]
            force.nodes nodes
            force.links links
            force.start()


            link = svg
                .selectAll(".link")
                .data(links)
                .enter()
                .append("line")
                .attr("class", "link")
                .style("stroke", "#999")
                .style("stroke-width", 1)

            node = svg
                .selectAll(".node")
                .data(nodes)
                .enter()
                .append("text")
                .style("font", "12px sans-serif")
                .style("text-anchor", "middle")
                .style("text-shadow", "1px 1px 0px white, -1px -1px 0px white, 1px -1px 0px white, -1px 1px 0px white")
                .attr("class", "node")
                .call(force.drag)

            force.on "tick", ->
                link.attr("x1", (d) -> d.source.x)
                    .attr("y1", (d) -> d.source.y)
                    .attr("x2", (d) -> d.target.x)
                    .attr("y2", (d) -> d.target.y)

                node
                    .attr("x", (d) -> d.x)
                    .attr("y", (d) -> d.y + 2)

# Definitions

We need a sample faust number for getting started, this will be removed later on, only used for testing when starting coding

    testFausts = ["29243700", "28682417"]


# Client - patronstat-vis

    if Meteor.isServer
        console.log faustDB.findOne {_id: testFausts[0]}

    if Meteor.isClient
        updatePatronGraphs = ->
            console.log faustDB.findOne {_id: testFausts[0]}
            for elem in document.getElementsByClassName "patronGraph"
                faust = elem.dataset.faust
                if faust
                    Meteor.subscribe "faust", faust
                klynge = (faustDB.findOne {_id: faust})?.klynge
                if klynge
                    elem.innerHTML = "<canvas id=\"canvasFaust#{faust}\" height=150 width=200></canvas>"
                    statEntry = statDB.findOne {_id: klynge}
                    stat = {k:[], m:[]}
                    for key, val of statEntry
                        sex = key[0]
                        age = +key.slice(1)
                        if key isnt "_id"
                            stat[sex][age] = val
                    renderStat (document.getElementById "canvasFaust" + faust), stat

        renderStat = (canvasElem, stat) ->
            console.log stat
            max = 0
            for i in stat.m
                max = Math.max(max, +i) if typeof i is "number"
            for i in stat.k
                max = Math.max(max, +i) if typeof i is "number"
            console.log max
            # return if not max 

            ctx = canvasElem.getContext "2d"

            for x in [5..95] by 5
                ctx.fillRect 2*x, 100, 1, 2

            for x in [10..90] by 10
                w = (ctx.measureText String x).width
                ctx.fillRect 2*x, 100, 1, 5
                ctx.fillText (String x), 2*x-w/2, 114

            ctx.fillStyle = "red"

            drawBar = (x, height) ->
                barHeight = 100*height/max
                ctx.fillRect x, 100-barHeight, 1, barHeight


            for age in [1..100]
                if stat.k[age]
                    drawBar(age*2,stat.k[age]);

            ctx.fillStyle = "blue"
            for age in [1..100]
                if stat.m[age]
                    drawBar(age*2+1,stat.m[age]);

        Deps.autorun updatePatronGraphs
        Meteor.startup updatePatronGraphs
