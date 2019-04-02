<?php
ini_set('display_errors', 'On');
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
    case 'getHeatMapDataD':
        getHeatMapDataD();
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
    $sql = "SELECT unit name, count(1) count, count(1)/t.cnt*100 percentage FROM _find f JOIN _layer l ON f.layer_id=l.id CROSS JOIN (SELECT COUNT(1) AS cnt FROM _find c WHERE excavation_code = ?) t WHERE f.excavation_code = ? GROUP BY unit ORDER BY cast(unit as unsigned)";
    if ($stmt = $mysqli->prepare($sql)) {
        $site=$_GET['site'];
        $stmt->bind_param('ss', $site, $site);
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
    $sql = "SELECT DISTINCT zone FROM _layer WHERE excavation_code = ?";
    if ($stmt = $mysqli->prepare($sql)) {
        $site=$_GET['site'];
        $stmt->bind_param('s', $site);
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

function getAttributeCounts() {
    $mysqli = dbConnection();
    $attribute = $_GET['attribute'];
    $site = $_GET['site'];
    $result;
    $sql = "SELECT id, value_string FROM _find_attribute_values";
    if ($stmt = $mysqli->prepare($sql)) {
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $code_book= array();
    while($row = $result->fetch_assoc()) {
        $code_book[$row['id']] = $row['value_string'];
    }
    $sql = "SELECT attribute_values FROM _find WHERE excavation_code = ?";
     if ($stmt = $mysqli->prepare($sql)) {
        $stmt->bind_param('s', $site);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $counts= array();
    //$counts['no value'] = 0;
    $rows_with_value = 0;
    while($row = $result->fetch_assoc()) {
        $cur_json = json_decode($row['attribute_values'], true);
        switch ($attribute) {
            case 'typ':
                $value1 = 'Not specified';
                $value2 = 'Not specified';
                $value3 = 'Not specified';
                $value4 = 'Not specified';
                if (array_key_exists(1,$cur_json)) {
                    $value1 = $code_book[$cur_json[1][0]];
                }
                if (array_key_exists(2,$cur_json)) {
                    $value2 = $code_book[$cur_json[2][0]];
                }
                if (array_key_exists(3,$cur_json)) {
                    $value3 = $code_book[$cur_json[3][0]];
                }
                if (array_key_exists(4,$cur_json)) {
                    $value4 = $code_book[$cur_json[4][0]];
                }
                $rows_with_value += 1;
                $full_value = $value1 . '/' . $value2 . '/' . $value3 . '/'. $value4;
                if (array_key_exists($full_value,$counts)) {
                    $counts[$full_value] += 1;
                } else {
                    $counts[$full_value] = 1;
                }
                break;
            case 'typ1':
                $value1 = 'Not specified';
                $value2 = 'Not specified';
                if (array_key_exists(1,$cur_json)) {
                    $value1 = $code_book[$cur_json[1][0]];
                }
                if (array_key_exists(2,$cur_json)) {
                    $value2 = $code_book[$cur_json[2][0]];
                }
                
                $rows_with_value += 1;
                $full_value = $value1 . '/' . $value2;
                if (array_key_exists($full_value,$counts)) {
                    $counts[$full_value] += 1;
                } else {
                    $counts[$full_value] = 1;
                }
                break;
            case 'typ2':
                $value1 = 'Not specified';
                $value2 = 'Not specified';
                if (array_key_exists(3,$cur_json)) {
                    $value1 = $code_book[$cur_json[3][0]];
                }
                if (array_key_exists(4,$cur_json)) {
                    $value2 = $code_book[$cur_json[4][0]];
                }
                
                $rows_with_value += 1;
                $full_value = $value1 . '/' . $value2;
                if (array_key_exists($full_value,$counts)) {
                    $counts[$full_value] += 1;
                } else {
                    $counts[$full_value] = 1;
                }
                break;
            default:
                if (array_key_exists($attribute,$cur_json)) {
                    $value = $code_book[$cur_json[$attribute][0]];
                    if (array_key_exists($value,$counts)) {
                        $counts[$value] += 1;
                    } else {
                        $counts[$value] = 1;
                    }
                    $rows_with_value += 1;
                } else {
                    //$counts['no value'] += 1; 
                }      
        }
    }
    $mysqli->close();
    array_multisort($counts, SORT_DESC);
    $resultArray = array();
    foreach ($counts as $key => $value) {
        $result_row = array();
        $result_row['name'] = $key;
        $result_row['count'] = $value;
        $result_row['percentage'] = $value / $rows_with_value * 100;
        $resultArray[] = $result_row;
    }
    response(200, "OK", $resultArray);
}

function getAttributeCountsPair() {
    $mysqli = dbConnection();
    $attribute1 = $_GET['attribute1'];
    $attribute2 = $_GET['attribute2'];
    $site = $_GET['site'];
    $result;
    $sql = "SELECT id, value_string FROM _find_attribute_values";
    if ($stmt = $mysqli->prepare($sql)) {
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $code_book= array();
    while($row = $result->fetch_assoc()) {
        $code_book[$row['id']] = $row['value_string'];
    }
    $sql = "SELECT attribute_values FROM _find WHERE excavation_code = ?";
    if ($stmt = $mysqli->prepare($sql)) {
        $stmt->bind_param('s', $site);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $counts = array();
    $pairs = array();
    //$counts['no value'] = 0;
    $rows_with_value = 0;
    while($row = $result->fetch_assoc()) {
        $cur_json = json_decode($row['attribute_values'], true);
        $c1 = getCountFromJSON($cur_json, $attribute1, $code_book);
        $c2 = getCountFromJSON($cur_json, $attribute2, $code_book);
        $pair = $c1 . '#' . $c2;
        if (!(array_key_exists($pair, $pairs))) {
            $pairs[$pair] = [$c1, $c2];
        }
        if (array_key_exists($pair,$counts)) {
            $counts[$pair] += 1;
        } else {
            $counts[$pair] = 1;
        }
        $rows_with_value += 1; 
    }
    $mysqli->close();
    array_multisort($counts, SORT_DESC);
    $resultArray = array();
    foreach ($counts as $key => $value) {
        $result_row = array();
        $result_row['name1'] = $pairs[$key][0];
        $result_row['name2'] = $pairs[$key][1];
        $result_row['count'] = $value;
        $result_row['percentage'] = $value / $rows_with_value * 100;
        $resultArray[] = $result_row;
    }
    response(200, "OK", $resultArray);
}

function getCountFromJSON($json, $attribute, $code_book) {
    switch ($attribute) {
        case 'typ':
            $value1 = 'Not specified';
            $value2 = 'Not specified';
            $value3 = 'Not specified';
            $value4 = 'Not specified';
            if (array_key_exists(1,$json)) {
                $value1 = $code_book[$json[1][0]];
            }
            if (array_key_exists(2,$json)) {
                $value2 = $code_book[$json[2][0]];
            }
            if (array_key_exists(3,$json)) {
                $value3 = $code_book[$json[3][0]];
            }
            if (array_key_exists(4,$json)) {
                $value4 = $code_book[$json[4][0]];
            }
            $full_value = $value1 . '/' . $value2 . '/' . $value3 . '/'. $value4;
            return $full_value;
        case 'typ1':
            $value1 = 'Not specified';
            $value2 = 'Not specified';
            if (array_key_exists(1,$json)) {
                $value1 = $code_book[$json[1][0]];
             }
            if (array_key_exists(2,$json)) {
                $value2 = $code_book[$json[2][0]];
            }
            $full_value = $value1 . '/' . $value2 . '/' . $value3 . '/'. $value4;
            return $full_value;
        case 'typ2':
            $value1 = 'Not specified';
            $value2 = 'Not specified';
            if (array_key_exists(3,$json)) {
                $value1 = $code_book[$cur_json[3][0]];
            }
            if (array_key_exists(4,$json)) {
                $value2 = $code_book[$json[4][0]];
            }
            $full_value = $value1 . '/' . $value2 . '/' . $value3 . '/'. $value4;
            return $full_value;
        default:
            if (array_key_exists($attribute,$json)) {
                return $code_book[$json[$attribute][0]];
            }
            return "no value";     
    }
}

function getHeatMapData() {
    $mysqli = dbConnection();
    $result;
    $sql = "SELECT FLOOR(square%10) as X2, 9-FLOOR(square/10) as Y2, 
                   FLOOR(sector%10) as X1, 9-FLOOR(sector/10) as Y1,  
                   GROUP_CONCAT(numbers) numbers, zone, sector, square 
            FROM _layer 
            WHERE excavation_code = ? AND `square` BETWEEN  1 AND 100 AND 
                  sector BETWEEN  1 AND 100 and zone = ? 
            GROUP BY x1, x2, y1, y2, zone, sector, square";
    if ($stmt = $mysqli->prepare($sql)) {
        $site = $_GET['site'];
        $zone = $_GET['zone'];
        $stmt->bind_param('ss', $site, $zone);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $resultArray= array();
    while($row = $result->fetch_assoc()) {
        $row['numbers'] = json_decode('[' . $row['numbers'] . ']');
        $resultArray[] = $row;
    }
    $mysqli->close();
    response(200, "OK", $resultArray);
}

function getHeatMapDataD() {
    $mysqli = dbConnection();
    $result;
    $sql = "SELECT FLOOR(square%10) as X2, 9-FLOOR(square/10) as Y2, 
                   FLOOR(sector%10) as X1, 9-FLOOR(sector/10) as Y1, 
                   GROUP_CONCAT(numbers) numbers, zone, sector, square 
            FROM _layer 
            WHERE excavation_code = ? AND `square` BETWEEN  1 AND 100 AND 
                  sector BETWEEN  1 AND 100 and zone = ? and lastchange BETWEEN ? and ? 
            GROUP BY x1, x2, y1, y2, zone, sector, square";
    if ($stmt = $mysqli->prepare($sql)) {
        $site = $_GET['site'];
        $zone = $_GET['zone'];
        $start = $_GET['start'];
        $end = $_GET['end'];
        $stmt->bind_param('ssss', $site, $zone, $start, $end);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
    }
    $resultArray= array();
    while($row = $result->fetch_assoc()) {
        $row['numbers'] = json_decode('[' . $row['numbers'] . ']');
        $resultArray[] = $row;
    }
    $mysqli->close();
    response(200, "OK", $resultArray);
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
    $response['status']=$status;
    $response['status_message']=$status_message;
    $response['data']=$data;
    $json_response = json_encode($response);
    echo $json_response;
}
?>