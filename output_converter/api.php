<?php
ini_set('memory_limit', '2048M');
ini_set('display_errors', 'On');
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
header("Content-Type:application/json");

$fun=$_GET['function'];
switch ($fun) {
	case 'getSites':
		getSites();
		break;
	case 'getData':
	    getData();
	    break;
	default:
		response(400,"Invalid Request",NULL);
}

function getData() {
	$mysqli = dbConnection();
    $mysqli->set_charset('utf8mb4');  
    $sql = 'SELECT id FROM _excavations';
	if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
    	exit;
	}
	
	$sites = explode(',', $_GET['sites']);
    $sites_checked  = array();
    while($row = $result->fetch_assoc()) {
        $cur_id = $row['id'];
        foreach($sites as $site_id) {
            if ($site_id == $cur_id) {
                $sites_checked[] = $cur_id;
                break;
            }
        } 
    }
    $result->free();
    $mysqli->close();

    $result = array();
    if ($_GET['getLayers']) {
        $result['layers'] = getLayers($sites_checked);
    }
    if ($_GET['getFinds']) {
        $result['finds'] = getFinds($sites_checked);
    }
    //if ($_GET['getExcavations']) {
        //$result['excavations'] = array();
    //}
	response(200, "OK", $result);
}

function getLayers($sites_checked) {
	$mysqli = dbConnection();
    $mysqli->set_charset('utf8mb4');  
	$sql = sprintf('SELECT * FROM _layer WHERE excavation IN (%s) LIMIT ?', implode(',', $sites_checked));
	if ($stmt = $mysqli->prepare($sql)) {
		$limit=$_GET['limit'];
	    $stmt->bind_param('i', $limit);
	    $stmt->execute();
	    $result = $stmt->get_result();
	    $stmt->close();
	}
	$resultArray= array();
	while($row = $result->fetch_assoc()) {
	    $row['numbers'] = parseJSONAndReplaceKeys($row['numbers'], 'property', '_find_types', $mysqli);
	    $row['weights'] = parseJSONAndReplaceKeys($row['weights'], 'property', '_find_types', $mysqli);
	    $row['counts'] = parseJSONAndReplaceKeys($row['counts'], 'property', '_count_properties', $mysqli);
        $resultArray[] = $row;
    }
    $result->free();
    $mysqli->close();
	return $resultArray;
}

function getFinds($sites_checked) {
	$mysqli = dbConnection();
    $mysqli->set_charset('utf8mb4');
	$sql = sprintf('SELECT * FROM _find f WHERE excavation IN (%s) LIMIT ?', implode(',', $sites_checked));
	if ($stmt = $mysqli->prepare($sql)) {
		$limit=$_GET['limit'];
	    $stmt->bind_param('i', $limit);
	    $stmt->execute();
	    $result = $stmt->get_result();
	    $stmt->close();
	}
	$resultArray= array();
	while($row = $result->fetch_assoc()) {
	    $row['attribute_values'] = parseJSONAndReplaceKeys($row['attribute_values'], 'name', '_find_attributes', $mysqli);
	    $row['attribute_values'] = codebookLookup($row['attribute_values'], $mysqli);
        $resultArray[] = $row;
    }
    $result->free();
    $mysqli->close();
	return $resultArray;
}

function codebookLookup($attribute_values, $mysqli) {
    $lookup = [];
    $sql = "SELECT id, code, value_string FROM _find_attribute_values";
    if ($stmt = $mysqli->prepare($sql)) {
	    $stmt->execute();
	    $result = $stmt->get_result();
	    $stmt->close();
	}
    while($row = $result->fetch_assoc()) {
        $lookup[$row['id']] = $row;
    }
    // TODO add multi value support
    foreach ($attribute_values as $key => $value) {
        $attribute_values[$key]['code'] = $lookup[$value[0]]['code'];
        $attribute_values[$key]['name'] = $lookup[$value[0]]['value_string'];
        $attribute_values[$key]['id'] = $value[0];
        
        unset($attribute_values[$key][0]);
    }
    return $attribute_values;
}

function parseJSONAndReplaceKeys($json, $lookup_name ,$lookup_table, $mysqli) {
    if ($json === "" || $json === null || $json === "{}" || $json === "[]") {
        return array();
    }
    $lookup = [];
    $sql = "SELECT id, " . $lookup_name . " name FROM " . $lookup_table;
    if ($stmt = $mysqli->prepare($sql)) {
	    $stmt->execute();
	    $result = $stmt->get_result();
	    $stmt->close();
	}
    while($row = $result->fetch_assoc()) {
        $lookup[$row['id']] = $row['name'];
    }
    
    $data = json_decode($json, true);
    // TODO Figure out how to treat mallformd JSON
    if (!is_array($data)) {
        return [];
    }    
    
    foreach($data as $key => $value){
        if (array_key_exists($key, $lookup)) {
            $data[$lookup[$key]] = $value;
        } else {
            $data[$lookup_table . "#" . $key] = $value;
        }
        unset($data[$key]);
    }
    return $data;
}

function getSites() {
	$mysqli = dbConnection();
	$sql = 'SELECT id, code FROM _excavations';
	if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
    	exit;
	}
	$resultArray= array();
	while($row = $result->fetch_assoc()) {
        $resultArray[] = $row;
    }
    $result->free();
    $mysqli->close();
	response(200, "List of Sites", $resultArray);
}

function dbConnection() {
    global $username, $passwd, $dbname;
    
    if (!isset($username)) $username = 'root';
    if (!isset($passwd))   $passwd   = 'pw';
    if (!isset($dbname))   $dbname   = 'online_system';
    $mysqli = new mysqli('127.0.0.1', $username, $passwd, $dbname, 3306);
    if ($mysqli->connect_errno) {
      response(503,"Service Unavailable",NULL);
      exit;
    }
    return $mysqli;
}

function response($status,$status_message,$data) {
	//header("HTTP/1.1 ".$status_message);
	//header("HTTP/1.1");
	
	$response['status']=$status;
	$response['status_message']=$status_message;
	$response['data']=$data;
	
	$json_response = json_encode($response);
	echo $json_response;
}
?>
