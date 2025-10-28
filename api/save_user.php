<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

// $conn disediakan oleh config.php

// Ambil data JSON dari input
$data = json_decode(file_get_contents("php://input"));

if (!$data) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "No JSON data received"]);
    exit();
}

// Ambil data dari JSON
$username = $conn->real_escape_string($data->username ?? '');
$password = $conn->real_escape_string($data->password ?? '');
$profile  = $conn->real_escape_string($data->profile ?? '');
$wa       = $conn->real_escape_string($data->wa ?? '');
$maps     = $conn->real_escape_string($data->maps ?? '');
$tanggal  = $conn->real_escape_string($data->tanggal_dibuat ?? '');

// Proses gambar base64 jika ada
$fotoPath = '';
if (!empty($data->foto)) {
    $imgData = $data->foto;
    $imgData = str_replace('data:image/png;base64,', '', $imgData);
    $imgData = str_replace(' ', '+', $imgData);
    $imgDecoded = base64_decode($imgData);

    if ($imgDecoded !== false) {
        $fileName = 'foto_' . uniqid() . '.png';
        $savePath = __DIR__ . '/uploads/' . $fileName;
        // Pastikan folder uploads sudah ada dan bisa ditulis
        if (!is_dir(__DIR__ . '/uploads')) {
            mkdir(__DIR__ . '/uploads', 0777, true);
        }
        file_put_contents($savePath, $imgDecoded);
        $fotoPath = 'uploads/' . $fileName;
    }
}

// Cek apakah user sudah ada
$checkStmt = $conn->prepare("SELECT id FROM users WHERE username = ?");
$checkStmt->bind_param("s", $username);
$checkStmt->execute();
$result = $checkStmt->get_result();

if ($result->num_rows > 0) {
    // Update user yang sudah ada
    if (!empty($fotoPath)) {
        $sql = "UPDATE users SET password = ?, profile = ?, wa = ?, maps = ?, tanggal_dibuat = ?, foto = ? WHERE username = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("sssssss", $password, $profile, $wa, $maps, $tanggal, $fotoPath, $username);
    } else {
        $sql = "UPDATE users SET password = ?, profile = ?, wa = ?, maps = ?, tanggal_dibuat = ? WHERE username = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ssssss", $password, $profile, $wa, $maps, $tanggal, $username);
    }
} else {
    // Insert user baru
    $sql = "INSERT INTO users (username, password, profile, wa, foto, maps, tanggal_dibuat) VALUES (?, ?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssssss", $username, $password, $profile, $wa, $fotoPath, $maps, $tanggal);
}

if ($stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => $result->num_rows > 0 ? "User updated successfully" : "User added successfully"
    ]);
} else {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $stmt->error
    ]);
}
$stmt->close();
$checkStmt->close();

$conn->close();
?>
