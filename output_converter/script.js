var siteSel, typeSel, dataSel;
var apiPath = "http://localhost:8888/dataconverter/api.php?"
var allData, cols_per_file, getExcavations, getLayers, getFinds;

function getColData() {
    waitingDialog.show('Loading Cols for selection...');
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            allData = JSON.parse(this.response).data;
            cols_per_file = [];
            for (table in allData) {
                cols_per_file[table] = extractCols(allData[table]);
                let sel = table === 'layers' ? 'a1' : 'a2';
                createDataSelector(sel, table, Object.keys(cols_per_file[table]));
            }
            document.getElementById('form-dl-options').style.display = "none";
            document.getElementById('btn-dl').style.display = "block";
            waitingDialog.hide();
        }
    };
    let selData = dataSel.val();
    getExcavations = selData.indexOf('excavation') > -1 ? 1: 0;
    getLayers = selData.indexOf('layer') > -1? 1: 0;
    getFinds = selData.indexOf('find') > -1? 1: 0;
    xhttp.open("GET", apiPath + "function=getData&getLayers="+getLayers+"&getFinds="+getFinds+"&getExcavations="+getExcavations+"&limit=500&sites="+siteSel.val().toString(), true);
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send(); 
}

function download() {
    let convertedData = {};
    let type = typeSel.val();
    if (getLayers) {
        convertedData['layers.' + type] = convertTable('layers', 'a1', type);
    }
    if (getFinds) {
        convertedData['finds.' + type] = convertTable('finds', 'a2', type);
    }
    createZipAndDownload(convertedData);
}

function convertTable(name, colSel, type) {
    let selCols = [];
    let colLookup = cols_per_file[name];
    let tableData = allData[name];
    let sqlHead = "";
    for (let elm of document.getElementById(colSel).getElementsByTagName('input')) {
        if(elm.type == "checkbox" && elm.checked == true) {
            selCols.push(elm.id)
        }
    }
    let lines = [];
    if (type === 'sql') {
        sqlHead = 'INSERT INTO ' + name + ' ("' + selCols.join('","') + '") VALUES ';
    } else if (type === 'csv') {
        lines.push(selCols.join(','));
    }
    for (let row of allData[name]) {
        let rowData = [];
        for (let col of selCols) {
            if (colLookup[col].length > 1) {
                let k0 = colLookup[col][0]
                let k1 = colLookup[col][1]
                let k2 = colLookup[col][2]
                if (row.hasOwnProperty(k0) && row[k0].hasOwnProperty(k1) && row[k0][k1].hasOwnProperty(k2)) {
                    rowData.push(row[k0][k1][k2]);
                } else {
                    rowData.push("");
                }
            } else {
                if (row.hasOwnProperty(col)) {
                    rowData.push(row[col]);
                } else {
                    rowData.push("");
                }
            }
        }
        if (type === 'sql') {
            lines.push('("' + rowData.join('","') + '")');
        } else if (type === 'csv') {
            lines.push('"' + rowData.join('","') + '"');
        }
    }
    if (type === 'sql') {
        return sqlHead + lines.join(',\n') + ';'
    } else if (type === 'csv') {
        return lines.join('\n');
    }
}

function extractCols(data) {
    let cols = {};
    for (let row of data) {
        for (col in row) {
            if (col === 'numbers' || col === 'weights' || col === 'counts') {
                for (let subCol in row[col]) {
                    for (let subSubCol in row[col][subCol]) {
                        let fullName = col === 'counts' ? col + '#' : ''
                        fullName += subCol + "#" + subSubCol;
                        if (!(cols.hasOwnProperty(fullName))) {
                            cols[fullName] = [col, subCol, subSubCol];
                        }
                    }
                }
            } else  if (col === 'attribute_values') {
                for (let subCol in row[col]) {
                    if (!(cols.hasOwnProperty(subCol))) {
                        cols[subCol] = [col, subCol, 'name'];
                        cols[subCol + '_code'] = [col, subCol, 'code'];
                        cols[subCol + '_database_id'] = [col, subCol, 'id'];
                    }
                }
            } else if (!(cols.hasOwnProperty(col))) {
                cols[col] = [col];
            }
        }
    }
    return cols
}

function createZipAndDownload(files) {
    // console.log(files);
    var zip = new JSZip();
    for (let filename in files) {
        // console.log(filename);
        zip.file(filename, files[filename]);
    }
    zip.generateAsync({type:"blob"})
      .then(function(content) {
          saveAs(content, "data_export.zip");
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
    btnUp.className = 'btn btn-outline-info';
    btnUp.setAttribute('onclick', 'up(this.parentNode)');
    btnUp.innerHTML = '&Lambda;';
    var btnDown = document.createElement('button');
    btnDown.type = 'button';
    btnDown.className = 'btn btn-secondary';
    btnDown.setAttribute('onclick','down(this.parentNode)');
    btnDown.innerHTML = 'V';
    input_div.appendChild(btnUp);
    input_div.appendChild(btnDown);
    input_div.appendChild(checkbox);
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
	    lbl.innerHTML = '  ' + value;
	    input_div.appendChild(lbl);
        fieldset.appendChild(input_div);
    }    
}

function down(node){
    let next = node;
    do {
	    next = next.nextSibling;
    } while (next && next.nodeType != 1);
    if (next) {
	    node.parentNode.insertBefore(next, node);
    }
}

function up(node) {
    let previous = node;
    do {
	    previous = previous.previousSibling;
    } while (previous && previous.nodeType != 1);
    if (previous) {
	    node.parentNode.insertBefore(node, previous);
    }
}

window.onload = function() {
    siteSel = $('#sites');
    typeSel = $('#type_selector');
    dataSel = $('#data_selector');
    
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            let sites = JSON.parse(this.response).data;
            let sSel = document.getElementById('sites');
            sites.forEach(function(d) {
                var opt = document.createElement("option");
                opt.text = d.code;
                opt.value = d.id;
                sSel.add(opt);
            });
            siteSel.multiselect({
                enableFiltering: true,
                includeSelectAllOption: true,
                buttonWidth: '200px'
            });
        }
    };
    xhttp.open("GET", "http://localhost:8888/dataconverter/api.php?function=getSites", true);
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send();
   
    typeSel.multiselect({buttonWidth: '200px'});
    dataSel.multiselect({includeSelectAllOption: true, buttonWidth: '200px'});


}