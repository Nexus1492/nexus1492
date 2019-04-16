var sites;
var findAttributes;
var siteSel, typeSel, attrSel, attrSel2;
var color = d3.scaleOrdinal(["#98abc5", "#8a89a6", "#7b6888", "#6b486b", "#a05d56", "#d0743c", "#ff8c00"]);
var APIpath = window.location.origin + "/api.php?";
var storedData;
var csvData;

window.onload = function() {
    siteSel = document.getElementById("site_selector");
    typeSel = document.getElementById("type_selector");
    attrSel = document.getElementById("attr_selector");
    attrSel2 = document.getElementById("attr_selector2");
    zoneSel = document.getElementById("zone_selector");
    
    $('#type_selector').multiselect({buttonWidth: '200px'});
    // Needs some more adjustments due to further code
    //$('#attr_selector').multiselect({buttonWidth: '200px'});
    //$('#attr_selector2').multiselect({buttonWidth: '200px'});
    //$('#zone_selector').multiselect({buttonWidth: '200px'});
    
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            sites = JSON.parse(xhttp.response).data;
            sites.forEach(function(d) {
                var opt = document.createElement("option");
                opt.value = d.code;
                opt.text = d.name;
                siteSel.add(opt);
            });
            
            $('#site_selector').multiselect({
                enableFiltering: true,
                buttonWidth: '200px'
            });
            //somewhat hacky solution to preselect site
            //$('#site_selector').multiselect('select', document.getElementById("excavation-name").innerHTML.split('[').pop().split(']')[0]);
        }
    };
    xhttp.open("GET", APIpath + "function=getSites", true);
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send();
    switchType(typeSel.value)
    var xhttp2 = new XMLHttpRequest();
    xhttp2.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            findAttributes = JSON.parse(xhttp2.response).data;
            findAttributes.forEach(function(d) {
                var opt = document.createElement("option");
                opt.text = d.name;
                attrSel.add(opt);
                opt = document.createElement("option");
                opt.text = d.name;
                attrSel2.add(opt);
            });
        }
    };
    xhttp2.open("GET", APIpath + "function=getFindAttributes", true);
    xhttp2.setRequestHeader("Content-type", "application/json");
    xhttp2.send();
  };
window.addEventListener('resize', reRender);

function drawPie(data) {
  d3.select("#pie").selectAll("*").remove();
  document.getElementById("pie").setAttribute("width", document.getElementById("piechart").offsetWidth);
  document.getElementById("pie").setAttribute("height", document.getElementById("piechart").offsetHeight - 120);
  var svg = d3.select("#pie"),
      width = +svg.attr("width"),
      height = +svg.attr("height"),
      radius = 0.55 * Math.min(width, height) / 2,
      g = svg.append("g").attr("transform", "translate(" + width / 2 + "," + height / 2 + ")");

  var pie = d3.pie()
      .sort(null)
      .value(function(d) { return d.count; });

  var path = d3.arc()
      .outerRadius(1.15*radius)
      .innerRadius(0);

  var start = d3.arc()
      .outerRadius(radius)
      .innerRadius(radius);

  var label = d3.arc()
      .outerRadius(1.2 * radius)
      .innerRadius(1.2 * radius);

  var arc = g.selectAll(".arc")
    .data(pie(data))
    .enter().append("g")
      .attr("class", "arc");

  var noOff = 0;

  arc.append("path")
      .attr("d", path)
      .attr("fill", function(d) { return color(d.data.name); });

  arc.append("text")
      .attr("transform", function(d) {
          var pos =  label.centroid(d);
          pos[0] = 1.4 * radius * (d.startAngle + (d.endAngle - d.startAngle)/2 < Math.PI ? 1 : -1);
          if (d.endAngle-d.startAngle<0.1 && d.endAngle > 1.5 * Math.PI) {
              var offset = ++noOff;
              pos[1] -= offset * 10;
          }
          return "translate(" + pos + ")";
      })
      .attr("font-size", 10)
      .attr("font-family", "sans-serif")
      .attr("dy", "0.35em")
      .style("text-anchor",  function(d) {
          return d.startAngle + (d.endAngle - d.startAngle)/2 < Math.PI ? "start":"end";
       })
      .text(function(d) { return d.data.name; });
  noOff=0;
  arc.append("polyline")
    .attr("stroke", "#000")
    .attr("fill", "none")
    .attr("points", function(d){
			var pos = label.centroid(d);
			var ang = label.centroid(d);
			pos[0] = radius * 1.35 * (d.startAngle + (d.endAngle - d.startAngle)/2 < Math.PI ? 1 : -1);
			if (d.endAngle-d.startAngle<0.1 && d.endAngle > 1.5 * Math.PI) {
				var offset = ++noOff;
				pos[1] -= offset * 10;
				ang[1] -= offset * 10;
				ang[0] -= 10;
			}
			return [start.centroid(d), ang, pos];
		});
}

function drawHist(data) {
  d3.select("#hist").selectAll("*").remove();

  var margin = {top: 20, right: 20, bottom: 70, left: 40},
    width = document.getElementById("histogram").offsetWidth - margin.left - margin.right,
    height = document.getElementById("histogram").offsetHeight - 100 - margin.top - margin.bottom;

  var svg = d3.select("#hist")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    .append("g")
      .attr("transform",
            "translate(" + margin.left + "," + margin.top + ")");

  height -= 20
  var x = d3.scaleBand().rangeRound([0, width], .05);
  var y = d3.scaleLinear().range([height, 0]);

  x.domain(data.map(function(d) { return d.name; }));
  y.domain([0, d3.max(data, function(d) { return parseInt(d.count); })]);

  svg.append("g")
	.attr("transform", "translate(0," + height + ")")
	.call(d3.axisBottom(x))
		.selectAll("text")
	    .style("text-anchor", "end")
        .attr("dx", "-1.2em")
	    .attr("dy", ".4em")
		.attr("transform", "rotate(-45)")
		.call(wrap, 90, -1.3);

  svg.append("g")
    .call(d3.axisLeft(y));

  svg.selectAll("bar")
      .data(data)
    .enter().append("rect")
      .style("fill", function(d) { return color(d.name); })
      .attr("x", function(d) { return x(d.name); })
      .attr("width", 0.7 * x.bandwidth())
      .attr("transform", "translate(" + 0.15 * x.bandwidth() + ",0)")
      .attr("y", function(d) { return y(d.count); })
      .attr("height", function(d) { return height - y(d.count); });
}

function drawTable(data) {
  var table = document.getElementById("tbl");
  while (table.rows.length > 1) {
            table.deleteRow(1);
  }
  csvData = [];
  csvData.push(['Name', 'Count', 'Percentage'])
  data.forEach(function(d) {
    var row = table.insertRow(-1);
    var cell1 = row.insertCell(0);
    var cell2 = row.insertCell(1);
    var cell3 = row.insertCell(2);
    cell1.innerHTML = d.name;
    cell2.innerHTML = d.count;
    cell3.innerHTML = d.percentage;
    csvData.push([d.name, d.count, d.percentage]);
  });
}

function createInputDiv(id_string, checked) {
    var input_div = document.createElement('div');
    var checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.checked = checked;
    checkbox.id = id_string;
    var btnUp = document.createElement('button');
    btnUp.type = 'button';
    btnUp.setAttribute('onclick', 'up(this.parentNode)');
    btnUp.innerHTML = '&Lambda;';
    var btnDown = document.createElement('button');
    btnDown.type = 'button';
    btnDown.setAttribute('onclick','down(this.parentNode)');
    btnDown.innerHTML = 'V';
    input_div.appendChild(checkbox);
    input_div.appendChild(btnUp);
    input_div.appendChild(btnDown);
    return input_div;
}

function createDataSelector(sel_name, name, values) {
    var fieldset = document.getElementById(sel_name);
    while (fieldset.hasChildNodes()) {
      fieldset.removeChild(fieldset.lastChild);
    }
    var legend = document.createElement('legend');
    legend.innerHTML = name;
    fieldset.appendChild(legend);
    for (let value of values){
	var input_div = createInputDiv(value, true);
	var lbl = document.createElement('label');
	lbl.innerHTML = ' ' + value;
	input_div.appendChild(lbl);
        fieldset.appendChild(input_div);
    }
    var input_div = createInputDiv('nonsel', false);
    var input_box = document.createElement('input');
    input_box.id = sel_name + '_nonsel_in';
    input_box.value = 'Non selected';
    input_div.appendChild(input_box);
    fieldset.appendChild(input_div);

}

function drawCrossTable(data){
    a1 = new Set();
    a2 = new Set();
    values = new Map([]);
    for (var i = 0; i < data.length; i++){
	var item = data[i];
	a1.add(item.name1);
	a2.add(item.name2);
	values.set(item.name1 + "#" + item.name2, item)
    }
    storedData = values;
    createDataSelector("a1", attrSel.value, a1)
    createDataSelector("a2", attrSel2.value, a2)

    updateCrossTable();
    document.getElementById("cross_table").style.display = 'block';
    document.getElementById("data_selectors").style.display = 'block';
    document.getElementById("selector").style.display = 'block';
    document.getElementById("selector2").style.display = 'block';

}

function updateCrossTable() {
    var values = storedData;
    var table_div = document.getElementById("cross_table");
    var table = document.getElementById("ctbl");
    while (table.rows.length > 0) {
	table.deleteRow(0);
    }
    //table Header
    let line = [""]
    var row = table.insertRow(0);
    var cell = row.insertCell(0);
    var th = document.createElement('th');
    cell.parentNode.replaceChild(th, cell);
    var a1_nonsel = [];
    var a2_nonsel = [];
    for (let elm of document.getElementById("a2").getElementsByTagName('input')) {
	if(elm.type == "checkbox" && elm.checked == true) {
	    var cell = row.insertCell(-1);
	    var th = document.createElement('th');
	    cell.parentNode.replaceChild(th, cell);
	    if (elm.id != "nonsel") {
		    th.innerHTML = elm.id;
		    line.push(elm.id);
	    } else {
		    th.innerHTML = document.getElementById("a2_nonsel_in").value;
		    line.push(document.getElementById("a2_nonsel_in").value)
	    }
	} else if (elm.type == "checkbox" && elm.checked == false && elm.id != "nonsel") {
	    a2_nonsel.push(elm.id)
	}
    }
    csvData = [line];

    for (let elm of document.getElementById("a1").getElementsByTagName('input')) {
	    if (elm.type == "checkbox" && elm.checked == false && elm.id != "nonsel") {
	        a1_nonsel.push(elm.id)
	    }
    }
    // Content
    for (let elm_a1 of document.getElementById("a1").getElementsByTagName('input')) {
	if(elm_a1.type == "checkbox" && elm_a1.checked == true) {
	    line = [];
	    var row = table.insertRow(-1);
	    cell = row.insertCell(0);

	    var th = document.createElement('th');
	    cell.parentNode.replaceChild(th, cell);
	    if (elm_a1.id != "nonsel") {
		    th.innerHTML = elm_a1.id;
		    line.push(elm_a1.id);
	    } else {
		    th.innerHTML = document.getElementById("a1_nonsel_in").value;
		    line.push(document.getElementById("a1_nonsel_in").value);
		    
	    }

	    for (let elm_a2 of document.getElementById("a2").getElementsByTagName('input')) {
		if(elm_a2.type == "checkbox" && elm_a2.checked == true) {
		    cell = row.insertCell(-1);
		    count = 0;
		    if (values.has(elm_a1.id + "#" + elm_a2.id)){
			count = values.get(elm_a1.id + "#" + elm_a2.id).count;
		    } else if(elm_a2.id == "nonsel") {
			for (var nonsel in a2_nonsel) {
			    if (values.has(elm_a1.id + "#" + a2_nonsel[nonsel])){
				count += values.get(elm_a1.id + "#" + a2_nonsel[nonsel]).count;
			    } else if (elm_a1.id == "nonsel") {
				for (var nonsel2 in a1_nonsel) {
				    if (values.has(a1_nonsel[nonsel2] + "#" + a2_nonsel[nonsel])){
					count += values.get(a1_nonsel[nonsel2] + "#" + a2_nonsel[nonsel]).count;
				    }
				}
			    }
			}
		    } else if(elm_a1.id == "nonsel") {
			for (var nonsel in a1_nonsel) {
			    if (values.has(a1_nonsel[nonsel] + "#" + elm_a2.id)){
				count += values.get(a1_nonsel[nonsel] + "#" + elm_a2.id).count;
			    }
			}
		    }
		    line.push(count);
		    if (count > 0) {
			cell.innerHTML = count;
		    } else {
			cell.innerHTML = "";
		    }
		}
	    }
	    csvData.push(line);
	}
    }
}

function drawHeatMap(data) {
    d3.select("#heatmap_draw").selectAll("*").remove();
    data.forEach(function(d) {
        d.row = ((d.X1*10)+(d.X2));
        d.col = ((d.Y1*10)+(d.Y2));
    });
    var gridSize = 10,
        h = gridSize-2,
        w = gridSize-2,
        rectPadding = 6;

    var colorLow = 'green', colorMed = 'yellow', colorHigh = 'red', colorVeryHigh = 'blue';

    var margin = {top: 20, right: 20, bottom: 20, left: 20},
        width = 850 - margin.left - margin.right,
        height = 850 - margin.top - margin.bottom;

    var colorScale = d3.scaleLinear()
        .domain([0, 10, 20, 50])
        .range([colorLow, colorMed, colorHigh, colorVeryHigh]);

    var svg = d3.select("#heatmap_draw").append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .attr("id", "hm")
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
    //        .style("fill", function(d) { return colorScale(d.CNT); })
        .style("fill", function(d) { return colorScale(calcCnt(d.numbers)); })
        .append("svg:title")
        .text(function(d) { return d.zone + "-" + d.sector + "-" + d.square + ": " + calcCnt(d.numbers); });
}

function calcCnt(jsonObj) {
    sum = 0;
    for(var x in jsonObj) {
        sum += 1;
    }
    return sum;
}

function applyUserSelection() {
    if (typeSel.value == 'cross') {
        updateCrossTable();
    } else if (typeSel.value == 'spu') {
	drawHist(filterData());
        drawTable(filterData());
    } else if (typeSel.value == 'vpft') {
	drawPie(filterData());
        drawHist(filterData());
        drawTable(filterData());
    }
}

function filterData() {
    var data = [];
    var data_dict = {};
    var nonselCnt = 0;
    var nonselPercent = 0;
    var boxes = document.getElementById("a1").getElementsByTagName('input');
    for (var i in storedData) {
	data_dict[storedData[i].name] = storedData[i];
    }
    var nonselPos = -1;
    var ctr = 0
    for (let elm of document.getElementById("a1").getElementsByTagName('input')) {
	if(elm.type == "checkbox" && elm.checked == true) {
	    if(elm.id == "nonsel") {
		nonselPos = ctr;
		data.push(null);
	    } else {
		data.push(data_dict[elm.id]);
	    }
	    ctr += 1;
	} else if (elm.type == "checkbox" && elm.id != 'nonsel') {
	    nonselCnt += Number(data_dict[elm.id].count);
	    nonselPercent += Number(data_dict[elm.id].percentage);
	}
    }
    if (nonselPos >= 0) {
	data[nonselPos] = {name:document.getElementById("a1_nonsel_in").value, count:nonselCnt, percentage:nonselPercent}
    }
    return data;
}

function createCharts() {
  var data;
  var siteID = siteSel.value; //sites.find(x => x.code === siteSel.value).id;
  if (typeSel.value === "spu") {
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            data = JSON.parse(xhttp.response).data;
            document.getElementById('table').style.display='block';
	    document.getElementById('histogram').className='unitHistogram';
            createDataSelector("a1", "Unit", data.map(function(element){return element.name;}));
	    document.getElementById("data_selectors").style.display = 'block';
	    document.getElementById("selector").style.display = 'block';
	    storedData = data;
	    drawHist(data);
            drawTable(data);
        }
    };
    xhttp.open("GET", APIpath + "function=getUnitCounts&site=" + siteID, true);
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send();
  } else if (typeSel.value === "vpft") {
    var attrID = findAttributes.find(x => x.name === attrSel.value).id;
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            data = JSON.parse(xhttp.response).data;
            document.getElementById('table').style.display='block';
	    document.getElementById('piechart').className='piechart';
            document.getElementById('histogram').className='histogram';
	    createDataSelector("a1", attrSel.value, data.map(function(element){return element.name;}));
	    document.getElementById("data_selectors").style.display = 'block';
	    document.getElementById("selector").style.display = 'block';
	    storedData = data;
	    drawPie(data);
            drawHist(data);
            drawTable(data);
        }
    };
    xhttp.open("GET", APIpath + "function=getAttributeCounts&site=" + siteID + "&attribute=" + attrID, true);
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send();
  } else if (typeSel.value === "cross") {
      var attrID1 = findAttributes.find(x => x.name === attrSel.value).id;
      var attrID2 = findAttributes.find(x => x.name === attrSel2.value).id;
      var xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function() {
	  if (this.readyState == 4 && this.status == 200) {
	      data = JSON.parse(xhttp.response).data;
	      drawCrossTable(data);
	  }
      };
      xhttp.open("GET", APIpath + "function=getAttributeCountsPair&site=" + siteID + "&attribute1=" + attrID1 + "&attribute2=" + attrID2, true);
      xhttp.setRequestHeader("Content-type", "application/json");
      xhttp.send(null);
  } else if (typeSel.value === "hm") {
      var zone = zoneSel.value;
      var xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function() {
	  if (this.readyState == 4 && this.status == 200) {
	      data = JSON.parse(xhttp.response).data;
	      drawHeatMap(data);
	      document.getElementById("heatmap").style.display = 'block';
	  }
      };
      xhttp.open("GET", APIpath + "function=getHeatMapData&site=" + siteID + "&zone=" + zone, true);
      xhttp.setRequestHeader("Content-type", "application/json");
      xhttp.send(null);
  }
}

function reRender() {
  if (document.getElementById('table').style.display != 'none') {
    createCharts();
  }
}

function switchInput(callSwitchType) {
    if(callSwitchType == 1) {
      switchType(typeSel.value);
    }
    document.getElementById('histogram').className='hiddenHistogram';
    document.getElementById('piechart').className='hiddenPie';
    document.getElementById('table').style.display='none';
    document.getElementById('cross_table').style.display='none';
    document.getElementById("data_selectors").style.display = 'none';
    document.getElementById("selector2").style.display = 'none';
    document.getElementById("heatmap").style.display = 'none';
}

function switchType(newType) {
  if(newType==="vpft") {
      document.getElementById('attr_chooser').className = 'enabled';
      document.getElementById('attr_chooser2').className = 'disabled';
      document.getElementById('zone_chooser').className = 'disabled';

  } else if (newType==="cross"){
      document.getElementById('attr_chooser').className = 'enabled';
      document.getElementById('attr_chooser2').className = 'enabled';
      document.getElementById('zone_chooser').className = 'disabled';
  } else if (newType==="hm") {
      document.getElementById('attr_chooser').className = 'disabled';
      document.getElementById('attr_chooser2').className = 'disabled';
      updateZones();
      document.getElementById('zone_chooser').className = 'enabled';
  } else{
      document.getElementById('attr_chooser').className = 'disabled';
      document.getElementById('attr_chooser2').className = 'disabled';
      document.getElementById('zone_chooser').className = 'disabled';
  }
}

function updateZones() {
    // TODO get this thing to work on reload
    var siteID = siteSel.value; //sites.find(x => x.code === siteSel.value).id;
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

function saveAsImg(node){
  var html = d3.select("#" + node)
        .attr("version", 1.1)
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .node().outerHTML;

  var fileName;
  if (typeSel.value === "spu") {
    fileName = siteSel.value
  } else if (typeSel.value === "vpft") {
    fileName = siteSel.value +"_"+attrSel.value
  } else {
    fileName = "download"
  }
  fileName += ".png"


  var canvas = document.createElement("canvas"),
    context = canvas.getContext("2d");
  canvas.setAttribute("width", document.getElementById(node).parentNode.offsetWidth +50);
  canvas.setAttribute("height", document.getElementById(node).parentNode.offsetHeight - 70);

  var image = new Image;
  image.src = 'data:image/svg+xml;base64,'+ btoa(html);
  image.onload = function() {
    context.drawImage(image, 25, 25);
    var canvasdata = canvas.toDataURL("image/png");
    var a = document.createElement("a");
    document.body.appendChild(a);
    a.download = fileName;
    a.href = canvasdata;
    a.click();
    a.parentNode.removeChild(a);
  };
}

function saveAsSvg(node){
  var html = d3.select("#" + node)
        .attr("version", 1.1)
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .node().outerHTML;

  var fileName;
  if (typeSel.value === "spu") {
    fileName = siteSel.value
  } else if (typeSel.value === "vpft") {
    fileName = siteSel.value +"_"+attrSel.value
  } else {
    fileName = "download"
  }
  fileName += ".svg"
  var a = document.createElement("a");
  document.body.appendChild(a);
  a.download = fileName;
  a.href = 'data:image/svg+xml;base64,'+ btoa(html);;
  a.click();
  a.parentNode.removeChild(a);
}

function downloadTable() {
    let lines = [];
    for (let line of csvData) {
        lines.push('"' + line.join('","') + '"');
    }
    let csv = lines.join("\n");
    var element = document.createElement('a');
    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(csv));
    element.setAttribute('download', 'data.csv');

    element.style.display = 'none';
    document.body.appendChild(element);

    element.click();

    document.body.removeChild(element);
}

function wrap(text, width, xOffset) {
    text.each(function() {
		var text = d3.select(this),
			words = text.text().split(/\s+/).reverse(),
			word,
			line = [],
			lineNumber = 0,
			lineHeight = 1.1, // ems
			y = text.attr("y"),
			dy = parseFloat(text.attr("dy")),
			tspan = text.text(null).append("tspan").attr("x", 0).attr("y", y).attr("dy", dy + "em");
		while (word = words.pop()) {
			line.push(word);
			tspan.text(line.join(" "));
			if (tspan.node().getComputedTextLength() > width) {
				line.pop();
				tspan.text(line.join(" "));
				line = [word];
				tspan = text.append("tspan")
					          .attr("x", 0)
					          .attr("y", y)
				              .attr("dy", ++lineNumber * lineHeight + dy + "em")
					          .attr("dx", xOffset + "em")
					          .text(word);
			}
		}
	});
}

function down(node){
    var next = node;
    do {
	next = next.nextSibling;
    } while (next && next.nodeType != 1);
    if (next) {
	node.parentNode.insertBefore(next, node);
    }
}

function up(node) {
    var previous = node;
    do {
	previous = previous.previousSibling;
    } while (previous && previous.nodeType != 1);
    if (previous) {
	node.parentNode.insertBefore(node, previous);
    }
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
