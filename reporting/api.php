<?php
ini_set('display_errors', 'On');
header('Access-Control-Allow-Origin: *');
header("Content-Type:application/json");

$fun=$_GET['function'];
switch ($fun) {
    case 'getFindAttributes':
        getFindAttributes();
        break;
    case 'getSites':
        getSites();
        break;
    case 'getUnitCounts':
        getUnitCounts();
        break;
    case 'getAttributeCounts':
        getAttributeCounts();
        break;
    case 'getAttributeCountsPair':
        getAttributeCountsPair();
        break;
    case 'getHeatMapData':
        getHeatMapData();
        break;
    case 'getZones':
        getZones();
        break;
    default:
        response(400,"Invalid Request",NULL);
}

function getFindAttributes() {
    $mysqli = dbConnection();
    $sql = 'SELECT id, name from _find_attributes';
    if (!$result = $mysqli->query($sql)) {
        response(503,"Service Unavailable", NULL);
        exit;
    }
    $resultArray= [["id"=>"typ", "name"=>"Full Typology"],
                   ["id"=>"typ1", "name"=>"Vessle shape, Wall profile"],
                   ["id"=>"typ2", "name"=>"Lip shape, Rim profile"]];
    while($row = $result->fetch_assoc()) {
        $resultArray[] = $row;
    }
    $result->free();
    $mysqli->close();
    response(200, "List of find attributes", $resultArray);
}

function getSites() {
    $mysqli = dbConnection();
    $sql = 'SELECT id, code from _excavations';
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

function getUnitCounts() {
    $mysqli = dbConnection();
    $result;
    $sql = "SELECT unit name, count(1) count, count(1)/t.cnt*100 percentage FROM _find f JOIN _layer l ON f.layer_id=l.id CROSS JOIN (SELECT COUNT(1) AS cnt FROM _find c WHERE excavation = ?) t WHERE f.excavation = ? GROUP BY unit ORDER BY cast(unit as unsigned)";
    if ($stmt = $mysqli->prepare($sql)) {
        $site=$_GET['site'];
        $stmt->bind_param('ii', $site, $site);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $resultArray= array();
    while($row = $result->fetch_assoc()) {
        $resultArray[] = $row;
    }
    $mysqli->close();
    response(200, "List of Units and Counts", $resultArray);
}

function getZones() {
    $mysqli = dbConnection();
    $result;
    $sql = "SELECT DISTINCT zone FROM _layer WHERE excavation = ?";
    if ($stmt = $mysqli->prepare($sql)) {
        $site=$_GET['site'];
        $stmt->bind_param('i', $site);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $resultArray= array();
    while($row = $result->fetch_assoc()) {
        $resultArray[] = $row;
    }
    $mysqli->close();
    response(200, "List of Units and Counts", $resultArray);
}


function getAttributeCounts() {
    $mysqli = dbConnection();
    $attribute = $_GET['attribute'];
    $site = $_GET['site'];
    $result;
    $SELECT;
    $FROM;
    $GROUPBY;
    switch ($attribute) {
        case 'typ':
            $SELECT = "CONCAT(IFNULL(v1a.value_string, 'Not specified'), ' / ', IFNULL(v1b.value_string, 'Not specified'), ' / ', IFNULL(v1c.value_string, 'Not specified'), ' / ',IFNULL(v1d.value_string, 'Not specified'))";
            $FROM = "LEFT JOIN _find_attribute_values v1a ON JSON_VALUE(attribute_values,  CONCAT('$.', 1, '[0]')) = v1a.id LEFT JOIN _find_attribute_values v1b ON JSON_VALUE(attribute_values,  CONCAT('$.', 2, '[0]')) = v1b.id LEFT JOIN _find_attribute_values v1c ON JSON_VALUE(attribute_values,  CONCAT('$.', 3, '[0]')) = v1c.id LEFT JOIN _find_attribute_values v1d ON JSON_VALUE(attribute_values,  CONCAT('$.', 4, '[0]')) = v1d.id";
            $GROUPBY = "v1a.id, v1b.id, v1c.id, v1d.id";
            break;
        case 'typ1':
            $SELECT = "CONCAT(IFNULL(v1a.value_string, 'Not specified'), ' / ', IFNULL(v1b.value_string, 'Not specified'))";
            $FROM = "LEFT JOIN _find_attribute_values v1a ON JSON_VALUE(attribute_values,  CONCAT('$.', 1, '[0]')) = v1a.id LEFT JOIN _find_attribute_values v1b ON JSON_VALUE(attribute_values,  CONCAT('$.', 2, '[0]')) = v1b.id";
            $GROUPBY = "v1a.id, v1b.id";
            break;
        case 'typ2':
            $SELECT = "CONCAT(IFNULL(v1a.value_string, 'Not specified'), ' / ', IFNULL(v1b.value_string, 'Not specified'))";
            $FROM = "LEFT JOIN _find_attribute_values v1a ON JSON_VALUE(attribute_values,  CONCAT('$.', 3, '[0]')) = v1a.id LEFT JOIN _find_attribute_values v1b ON JSON_VALUE(attribute_values,  CONCAT('$.', 4, '[0]')) = v1b.id";
            $GROUPBY = "v1a.id, v1b.id";
            break;
        default:
            $SELECT = "IFNULL(v1.value_string, 'Not specified')";
            $FROM = "LEFT JOIN _find_attribute_values v1 ON JSON_VALUE(attribute_values,  CONCAT('$.', " . intval($attribute) . ", '[0]')) = v1.id";
            $GROUPBY = "v1.id";
            break;
    }
    $SELECT = "SELECT " . $SELECT . " name, count(1) count, count(1)/t.cnt*100 percentage ";
    $FROM = "FROM _find " . $FROM . " CROSS JOIN (SELECT COUNT(1) AS cnt FROM _find c WHERE excavation = ?) t ";
    $WHERE = "WHERE excavation = ? GROUP BY " . $GROUPBY . " ORDER BY count DESC";
    $sql = $SELECT . $FROM . $WHERE;
    if ($stmt = $mysqli->prepare($sql)) {
        $stmt->bind_param('ii', $site, $site);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $resultArray= array();
    while($row = $result->fetch_assoc()) {
        $resultArray[] = $row;
    }
    $mysqli->close();
    response(200, $sql, $resultArray);
}

function getAttributeCountsPair() {
    $mysqli = dbConnection();
    $attribute1 = $_GET['attribute1'];
    $attribute2 = $_GET['attribute2'];
    $site = $_GET['site'];
    $result;
    $SELECT1;
    $SELECT2;
    $FROM1;
    $FROM2;
    $GROUPBY1;
    $GROUPBY2;
    switch ($attribute1) {
        case 'typ':
            $SELECT1 = "CONCAT(IFNULL(v1a.value_string, 'Not specified'), ' / ', IFNULL(v1b.value_string, 'Not specified'), ' / ', IFNULL(v1c.value_string, 'Not specified'), ' / ',IFNULL(v1d.value_string, 'Not specified'))";
            $FROM1 = "LEFT JOIN _find_attribute_values v1a ON JSON_VALUE(attribute_values,  CONCAT('$.', 1, '[0]')) = v1a.id LEFT JOIN _find_attribute_values v1b ON JSON_VALUE(attribute_values,  CONCAT('$.', 2, '[0]')) = v1b.id LEFT JOIN _find_attribute_values v1c ON JSON_VALUE(attribute_values,  CONCAT('$.', 3, '[0]')) = v1c.id LEFT JOIN _find_attribute_values v1d ON JSON_VALUE(attribute_values,  CONCAT('$.', 4, '[0]')) = v1d.id";
                $GROUPBY1 = "v1a.id, v1b.id, v1c.id, v1d.id";
            break;
        case 'typ1':
            $SELECT1 = "CONCAT(IFNULL(v1a.value_string, 'Not specified'), ' / ', IFNULL(v1b.value_string, 'Not specified'))";
            $FROM1 = "LEFT JOIN _find_attribute_values v1a ON JSON_VALUE(attribute_values,  CONCAT('$.', 1, '[0]')) = v1a.id LEFT JOIN _find_attribute_values v1b ON JSON_VALUE(attribute_values,  CONCAT('$.', 2, '[0]')) = v1b.id";
            $GROUPBY1 = "v1a.id, v1b.id";
            break;
        case 'typ2':
            $SELECT1 = "CONCAT(IFNULL(v1a.value_string, 'Not specified'), ' / ', IFNULL(v1b.value_string, 'Not specified'))";
            $FROM1 = "LEFT JOIN _find_attribute_values v1a ON JSON_VALUE(attribute_values,  CONCAT('$.', 3, '[0]')) = v1a.id LEFT JOIN _find_attribute_values v1b ON JSON_VALUE(attribute_values,  CONCAT('$.', 4, '[0]')) = v1b.id";
            $GROUPBY1 = "v1a.id, v1b.id";
            break;
        default:
            $SELECT1 = "IFNULL(v1.value_string, 'Not specified')";
            $FROM1 = "LEFT JOIN _find_attribute_values v1 ON JSON_VALUE(attribute_values,  CONCAT('$.', " . intval($attribute1) . ", '[0]')) = v1.id";
            $GROUPBY1 = "v1.id";
            break;
    }
    switch ($attribute2) {
        case 'typ':
            $SELECT2 = "CONCAT(IFNULL(v2a.value_string, 'Not specified'), ' / ', IFNULL(v2b.value_string, 'Not specified'), ' / ', IFNULL(v2c.value_string, 'Not specified'), ' / ',IFNULL(v2d.value_string, 'Not specified'))";
            $FROM2 = "LEFT JOIN _find_attribute_values v2a ON JSON_VALUE(attribute_values,  CONCAT('$.', 1, '[0]')) = v2a.id LEFT JOIN _find_attribute_values v2b ON JSON_VALUE(attribute_values,  CONCAT('$.', 2, '[0]')) = v2b.id LEFT JOIN _find_attribute_values v2c ON JSON_VALUE(attribute_values,  CONCAT('$.', 3, '[0]')) = v2c.id LEFT JOIN _find_attribute_values v2d ON JSON_VALUE(attribute_values,  CONCAT('$.', 4, '[0]')) = v2d.id";
            $GROUPBY2 = "v2a.id, v2b.id, v2c.id, v2d.id";
            break;
        case 'typ1':
            $SELECT2 = "CONCAT(IFNULL(v2a.value_string, 'Not specified'), ' / ', IFNULL(v2b.value_string, 'Not specified'))";
            $FROM2 = "LEFT JOIN _find_attribute_values v2a ON JSON_VALUE(attribute_values,  CONCAT('$.', 1, '[0]')) = v2a.id LEFT JOIN _find_attribute_values v2b ON JSON_VALUE(attribute_values,  CONCAT('$.', 2, '[0]')) = v2b.id";
            $GROUPBY2 = "v2a.id, v2b.id";
            break;
        case 'typ2':
            $SELECT2 = "CONCAT(IFNULL(v2a.value_string, 'Not specified'), ' / ', IFNULL(v2b.value_string, 'Not specified'))";
            $FROM2 = "LEFT JOIN _find_attribute_values v2a ON JSON_VALUE(attribute_values,  CONCAT('$.', 3, '[0]')) = v2a.id LEFT JOIN _find_attribute_values v2b ON JSON_VALUE(attribute_values,  CONCAT('$.', 4, '[0]')) = v2b.id";
            $GROUPBY2 = "v2a.id, v2b.id";
            break;
        default:
            $SELECT2 = "IFNULL(v2.value_string, 'Not specified')";
            $FROM2 = "LEFT JOIN _find_attribute_values v2 ON JSON_VALUE(attribute_values,  CONCAT('$.', " . intval($attribute2) . ", '[0]')) = v2.id";
            $GROUPBY2 = "v2.id";
            break;
    }
    $SELECT = "SELECT " . $SELECT1 . " name1, " . $SELECT2 . " name2, count(1) count, count(1)/t.cnt*100 percentage ";
    $FROM = "FROM _find " . $FROM1 . " " . $FROM2 . " CROSS JOIN (SELECT COUNT(1) AS cnt FROM _find c WHERE excavation = ?) t ";
    $WHERE = "WHERE excavation = ? GROUP BY " . $GROUPBY1 . ", " . $GROUPBY2 . " ORDER BY count DESC";
    $sql = $SELECT . $FROM . $WHERE;

    if ($stmt = $mysqli->prepare($sql)) {
        $stmt->bind_param('ii', $site, $site);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $resultArray= array();
    while($row = $result->fetch_assoc()) {
        $resultArray[] = $row;
    }
    $mysqli->close();
    response(200, $sql, $resultArray);
}

function getHeatMapData() {
    $mysqli = dbConnection();
    $result;
    $sql = "SELECT floor((square-1)%10) as X2, 9-FLOOR((square-1)/10) as Y2, FLOOR((sector-1)%10) as X1, 9-FLOOR((sector-1)/10) as Y1, SUM(IFNULL(JSON_VALUE(numbers, '$.1.lt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.1.gt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.2.lt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.2.gt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.3.lt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.3.gt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.4.lt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.4.gt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.5.lt50mm'), 0)) + SUM(IFNULL(JSON_VALUE(numbers, '$.5.gt50mm'), 0)) CNT, zone, sector, square FROM _layer WHERE excavation = ? AND `square` BETWEEN  1 AND 100 AND sector BETWEEN  1 AND 100 and zone = ? group by x1, x2, y1, y2";
    if ($stmt = $mysqli->prepare($sql)) {
        $site = $_GET['site'];
        $zone = $_GET['zone'];
        $stmt->bind_param('is', $site, $zone);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $resultArray= array();
    while($row = $result->fetch_assoc()) {
        $resultArray[] = $row;
    }
    $mysqli->close();
    response(200, "OK", $resultArray);
}

function dbConnection() {
    $mysqli = new mysqli('p:localhost', 'user', 'passwd', 'db', NULL, '/var/run/mysqld/mysqld.sock');
    if ($mysqli->connect_errno) {
        response(503,"Service Unavailable",NULL);
        exit;
    }
    return $mysqli;
}

function response($status,$status_message,$data) {
    $response['status']=$status;
    $response['status_message']=$status_message;
    $response['data']=$data;
    $json_response = json_encode($response);
    echo $json_response;
}
?>