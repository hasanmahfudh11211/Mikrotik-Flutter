<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

// Ambil data JSON dari input
$data = json_decode(file_get_contents("php://input"));

if (!$data) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "No JSON data received"]);
    exit();
}

// Ambil username dari JSON
$username = $conn->real_escape_string($data->username ?? '');

if (empty($username)) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Username tidak boleh kosong"]);
    exit();
}

// Hapus user dari database
$sql = "DELETE FROM users WHERE username = '$username'";

if ($conn->query($sql) === TRUE) {
    if ($conn->affected_rows > 0) {
        echo json_encode([
            "success" => true,
            "message" => "User berhasil dihapus"
        ]);
    } else {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "error" => "User tidak ditemukan"
        ]);
    }
} else {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $conn->error
    ]);
}

$conn->close();
?>
