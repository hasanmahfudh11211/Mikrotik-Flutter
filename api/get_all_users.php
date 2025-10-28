<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
error_reporting(0); // Sembunyikan error PHP agar tidak merusak JSON

$response = ["success" => false, "users" => [], "error" => "An unknown error occurred."];

try {
    // Koneksi ke database via config terpusat
    require_once __DIR__ . '/config.php';

    // $conn disediakan oleh config.php

    $odp_id = isset($_GET['odp_id']) ? (int)$_GET['odp_id'] : null;

    $sql = "SELECT 
                u.id,
                u.username, 
                u.password, 
                u.profile, 
                u.wa, 
                u.foto, 
                u.maps,
                DATE_FORMAT(u.tanggal_dibuat, '%Y-%m-%d %H:%i:%s') as tanggal_dibuat,
                u.odp_id, 
                o.name as odp_name
            FROM users u
            LEFT JOIN odp o ON u.odp_id = o.id";

    $params = [];
    $types = "";

    if ($odp_id !== null) {
        $sql .= " WHERE u.odp_id = ?";
        $params[] = $odp_id;
        $types .= "i";
    }

    $sql .= " ORDER BY u.username ASC";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("SQL prepare failed: " . $conn->error);
    }

    if ($odp_id !== null) {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        throw new Exception("SQL execute failed: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $users = [];
    while ($row = $result->fetch_assoc()) {
        if (!empty($row['foto'])) {
            $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $row['foto'] = $scheme . '://' . $_SERVER['HTTP_HOST'] . '/api/' . $row['foto'];
        }
        $users[] = $row;
    } 

    $response["success"] = true;
    $response["users"] = $users;
    unset($response["error"]);

} catch (Exception $e) {
    http_response_code(500);
    $response["error"] = $e->getMessage();
}

if (isset($conn) && $conn instanceof mysqli) { $conn->close(); }
echo json_encode($response);
?>