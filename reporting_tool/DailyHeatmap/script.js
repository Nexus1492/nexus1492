var sites;
var siteSel, zoneSel, datePick1, datePick2;
var APIpath = window.location.origin + "/api.php?";
var storedData;

window.onload = function() {
    siteSel = document.getElementById("site_selector");
    zoneSel = document.getElementById("zone_selector");
    datePick1 = document.getElementById("datepicker1");
    datePick2 = document.getElementById("datepicker2");
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            sites = JSON.parse(xhttp.response).data;
            sites.forEach(function(d) {
                var opt = document.createElement("option");
                opt.text = d.code;
                siteSel.add(opt);
            });
        }
    };
    xhttp.open("GET", APIpath + "function=getSites", true);
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send();
  };
window.addEventListener('resize', reRender);

function drawHeatMap(data) {
    d3.select("#heatmap").selectAll("*").remove();
    data.forEach(function(d) {
	d.row = ((d.X1*10)+(d.X2));
	d.col = ((d.Y1*10)+(d.Y2));
    });
    var gridSize = 10,
	h = gridSize-2,
	w = gridSize-2,
	rectPadding = 6;

    var colorLow = 'green', colorMed = 'yellow', colorHigh = 'red';

    var margin = {top: 20, right: 20, bottom: 20, left: 20},
	width = 850 - margin.left - margin.right,
	height = 850 - margin.top - margin.bottom;

    var colorScale = d3.scaleLinear()
        .domain([0, 300, 600])
        .range([colorLow, colorMed, colorHigh]);

    var svg = d3.select("#heatmap").append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
	.append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    // Define the div for the tooltip
    var div = d3.select("#heatmap").append("div")
        .attr("class", "tooltip")
        .style("display", "none");


    var heatMap = svg.selectAll(".heatmap");

    heatMap.data(pairs(100, 100))
	.enter().append("svg:rect")
        .attr("x", function(d) { return d.row * w; })
        .attr("y", function(d) { return d.col * h; })
        .attr("width", function(d) { return w; })
        .attr("height", function(d) { return h; })
        .style("fill", "none")
        .style("stroke-width", .25)
        .style("stroke", '#777');

    heatMap.data(pairs(10, 10))
	.enter().append("svg:rect")
        .attr("x", function(d) { return d.row * w*10; })
        .attr("y", function(d) { return d.col * h*10; })
        .attr("width", function(d) { return w*10; })
        .attr("height", function(d) { return h*10; })
        .style("fill", "none")
        .style("stroke-width", .5)
        .style("stroke", '#000');

    heatMap.data(data)
	.enter().append("svg:rect")
        .attr("x", function(d) { return d.row * w; })
        .attr("y", function(d) { return d.col * h; })
        .attr("width", function(d) { return w; })
        .attr("height", function(d) { return h; })
        .style("fill", function(d) { return colorScale(d.CNT); })
        .append("svg:title")
        .text(function(d) { return d.zone + "-" + d.sector + "-" + d.square + ": " + d.CNT; });
}

function createCharts() {
  var data;
  var siteID = sites.find(x => x.code === siteSel.value).id;
  var zone = zoneSel.value;
  var start = datePick1.value;
  var end = datePick2.value;
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      data = JSON.parse(xhttp.response).data;
      drawHeatMap(data);
      document.getElementById("heatmap").style.display = 'block';
    }
  };
  xhttp.open("GET", APIpath + "function=getHeatMapDataD&site=" + siteID + "&zone=" + zone +"&start=" + start + "&end=" + end, true);
  xhttp.setRequestHeader("Content-type", "application/json");
  xhttp.send(null);
}

function reRender() {
  if (document.getElementById("heatmap").style.display != 'none') {
    createCharts();
  }
}

function switchInput(callSwitchType) {
    document.getElementById("heatmap").style.display = 'none';
}

function updateZones() {
    // TODO get this thing to work on reload
    var siteID = sites.find(x => x.code === siteSel.value).id;
    document.getElementById('zone_selector').options.length = 0

    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
	if (this.readyState == 4 && this.status == 200) {
	    var zones = JSON.parse(xhttp.response).data;
	    zones.forEach(function(d) {
		var opt = document.createElement("option");
		opt.text = d.zone;
		zoneSel.add(opt);
	    });
	}
    };
    xhttp.open("GET", APIpath + "function=getZones&site=" + siteID, true);
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send();
}

function pairs(max_i, max_j) {
    var res = [];
    for (var i = 0; i < max_i; i++) {
	for (var j = 0; j < max_j; j++) {
	    res.push({col:i, row:j});
	}
    }
    return res;
}