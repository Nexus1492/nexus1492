<?php
header("Content-Type:application/json");

$fun=$_GET['function'];
switch ($fun) {
	case 'getConfig':
		getConfig();
		break;
	case 'getConverter':
	    getConverter();
	    break;
	default:
		response(400,"Invalid Request",NULL);
}

function buildUpdateURL() {
	$ssl      = ( ! empty( $_SERVER['HTTPS'] ) && $_SERVER['HTTPS'] == 'on' );
    $sp       = strtolower( $_SERVER['SERVER_PROTOCOL'] );
    $protocol = substr( $sp, 0, strpos( $sp, '/' ) ) . ( ( $ssl ) ? 's' : '' );
    $port     = $_SERVER['SERVER_PORT'];
    $port     = ( ( ! $ssl && $port=='80' ) || ( $ssl && $port=='443' ) ) ? '' : ':'.$port;
    $host     = $_SERVER['SERVER_NAME'] . $port;
	return $protocol . '://' . $host . $_SERVER['SCRIPT_NAME'] . '?function=getConfig';
}

function getConfig() {
	response(200, "OK", getConfigFromDB());
}

function getConfigFromDB() {
    $resultArray= array();
	$mysqli = dbConnection();
	
	$resultArray['config_url'] = buildUpdateURL();
	$resultArray['update_time'] = date('c');
	
	$resultArray['find'] = array();
	$resultArray['find']['order'] = [1=> 'id', 2=> 'sherd_nr', 3=> 'layer_id', 4=> 'sherd_type', 5=> 'wall_thickness', 6=> 'JSON/attribute_values', 7=> 'rim_diameter', 8=> 'rim_percentage', 9=> 'remarks', 10=> 'source_key'];
	
	$resultArray['find']['codebook'] = array();
	$sql = 'SELECT code, attribute_id, id from _find_attribute_values WHERE active = 1';
	if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
    	exit;
	}
	while($row = $result->fetch_assoc()) {
        $resultArray['find']['codebook'][] = $row;
    }
    
	$resultArray['find']['codebook_other'] = array();
    $sql = 'SELECT code, attribute_id, id from _find_attribute_values WHERE value1 LIKE "%other%"';
	if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
    	exit;
	}
	while($row = $result->fetch_assoc()) {
        $resultArray['find']['codebook_other'][] = $row;
    }
    
	$resultArray['find']['attribute_values'] = array();
	$sql = 'SELECT name, id from _find_attributes WHERE active = 1';
	if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
    	exit;
	}
    while($row = $result->fetch_assoc()) {
        $resultArray['find']['attribute_values'][] = $row;
    }
    $result->free();
    
	$resultArray['layer'] = array();
	$resultArray['layer']['order'] = [1=> 'id', 2=> 'find_type', 3=> 'find_number', 4=> 'zone', 5=> 'sector', 6=> 'square', 7=> 'layer', 8=> 'unit', 9=> 'feature', 10=> 'stratigraphic', 11=> 'JSON/numbers', 12=> 'JSON/weights', 13=> 'JSON/counts', 14=> 'remarks', 15=> 'source_key'];
	
	$resultArray['layer']['counts'] = array();
	$sql = 'SELECT property, id from _count_properties WHERE active = 1';
	if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
    	exit;
	}
    while($row = $result->fetch_assoc()) {
        $resultArray['layer']['counts'][] = $row;
    }
    $result->free();
    
	$resultArray['layer']['weights'] = array();
	$resultArray['layer']['numbers'] = array();
	$sql = 'SELECT property, id from _find_types';
	if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
    	exit;
	}
    while($row = $result->fetch_assoc()) {
	    $resultArray['layer']['weights'][] = $row;
	    $resultArray['layer']['numbers'][] = ['id'=> $row['id'], 'property'=> $row['property'] . '_lt'];
	    $resultArray['layer']['numbers'][] = ['id'=> $row['id'], 'property'=> $row['property'] . '_gt'];
    }
    $result->free();
    
    $mysqli->close();
    return $resultArray;
}

function getConverter() {
    $filename = 'converter.zip';
    if(file_exists($filename)){
        $zip = new ZipArchive;
        if ($zip->open($filename) === TRUE) {
            $zip->addFromString("data.json", json_encode(getConfigFromDB()));
            $zip->close();
        }

        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        header('Content-Type: ' . finfo_file($finfo, $filename));
        finfo_close($finfo);
        
        header('Content-Disposition: attachment; filename='.basename($filename));
        
        header('Expires: 0');
        header('Cache-Control: must-revalidate');
        header('Pragma: public');
    
        header('Content-Length: ' . filesize($filename));
        
        ob_clean();
        flush();
        readfile($filename);
        exit;
    }
    response(500, "Converter Unavailable", NULL);
}

function dbConnection() {
	//$mysqli = new mysqli('p:localhost', 'WebAppUser', 'WebAppUser', 'WebApp', NULL, '/usr/local/mariadb/data/mariadb.sock');
	$mysqli = new mysqli($host='127.0.0.1', $username='root', $passwd='pw', $dbname='online_system', $port=3306);
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